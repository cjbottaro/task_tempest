require "configuration_dsl"

require "task_tempest/bootstrapper"
require "task_tempest/engine/configuration"
require "task_tempest/error_handling"
require "task_tempest/health_checking"
require "task_tempest/queue"
require "task_tempest/task_facade"

module TaskTempest #:nodoc:
  
  # The Engine is where the run loop happens that does the dispatching of the tasks.  It is also
  # responsible for submitting tasks to the queue.
  #   class MathHurricane < TaskTempest::Engine
  #     configure do
  #       ...
  #     end
  #   end
  #   
  #   task = Adder.new(1, 2)
  #   MathHurricane.submit(task)
  #   MathHurricane.run
  # 
  # See Configuration for what to put in the +configure+ block.
  class Engine

    attr_reader :logger         #:nodoc:
    attr_reader :task_logger    #:nodoc:
    attr_reader :storm          #:nodoc:
    attr_reader :dispatcher     #:nodoc:

    extend ConfigurationDsl
    include ErrorHandling
    include HealthChecking
    
    configure_with(Configuration)
    configure do
      name{ self.name }
      root{ Dir.pwd }
      timeout_method do
        if fibered?
          FiberStorm.method(:timeout)
        else
          ThreadStorm.method(:timeout)
        end
      end
      timeout_exception do
        if fibered?
          FiberStorm::TimeoutError
        else
          Timeout::Error
        end
      end

      log_file do
        "#{conf.name}.log"
      end

      log_format TaskTempest::LOG_FORMAT

      task_log_file do
        "#{conf.name}.task.log"
      end

      task_log_format TaskTempest::LOG_FORMAT
    end
    
    # The configuration as a struct-like object.
    def self.conf
      configuration
    end

    # Returns true if running in fibered mode.
    def self.fibered?
      !!conf.fibers
    end

    def self.queue
      @queue ||= Queue.new(conf.queue)
    end
    
    # Submit a task to the queue.
    # +task+ must be a kind of TaskTempest::Task.
    def self.submit(task_class, *args)
      queue.enqueue(TaskFacade.message(task_class, *args))
    end
    
    # Same as <tt>TaskTempest::Engine.new.run</tt>
    def self.run
      new.tap{ |me| me.run }
    end

    def self.log_file
      if Pathname.new(conf.log_file).relative?
        conf.root + "/" + conf.log_file
      else
        conf.log_file
      end
    end

    def self.task_log_file
      if Pathname.new(conf.task_log_file).relative?
        conf.root + "/" + conf.task_log_file
      else
        conf.task_log_file
      end
    end
    
    # Create a new TaskTempest::Engine instance.  The +before_initialize+ callbacks are run before
    # anything else is done.  Then logging is initialized, then thread pool created, etc.  Finally, the
    # +after_initialize+ callbacks are run.
    def initialize
      conf.before_initialize.each{ |callback| instance_exec(&callback) }
      
      if fibered?
        require "fiber_storm"
      else
        require "thread_storm"
      end
      require "task_tempest/recursive_mutex_hack" if conf.recursive_mutex_hack
      
      bootstrapper = Bootstrapper.new conf, queue, :started_callback => method(:task_started),
                                                   :finished_callback => method(:task_finished)
      
      @logger      = bootstrapper.logger
      @task_logger = bootstrapper.task_logger
      @storm       = bootstrapper.storm
      @dispatcher  = bootstrapper.dispatcher
      
      @last_report_time = Time.now
      @loop_iterations  = 0
      
      logger.info "main thread: #{Thread.current.inspect}"
      logger.info "dispatcher #{primitive_name}: #{dispatcher.primitive.inspect}"
      
      conf.after_initialize.each{ |callback| instance_exec(logger, &callback) }
    end
    
    # Same as +self.class.conf+
    def conf
      self.class.conf
    end

    # Returns true if we're running in fibered mode.
    def fibered?
      !!conf.fibers
    end

    # Returns true if we're running in threaded mode.
    def threaded?
      !fibered?
    end

    # How many threads or fibers are in the pool.
    def pool_size
      fibered? ? conf.fibers : conf.threads
    end

    # Returns a string denoting the concurrency primitive type.
    def primitive_name #:nodoc:
      fibered? ? "fiber" : "thread"
    end

    def queue
      self.class.queue
    end
    
    # Begin the run loop which polls the queue indefinitely, dispatching tasks.
    # There are several ways to stop the run loop: calling #stop! or sending by
    # the following signals: INT, TERM.
    def run
      # Install signal handlers.
      Signal.trap("INT") { logger.info "SIGINT detected";  stop! }
      Signal.trap("TERM"){ logger.info "SIGTERM detected"; stop! }

      run_wrap do
        dispatcher.start
        run_loop while not stop?
        shutdown
      end
    end

    # Wrap the run body in EM.run+fiber if needed.
    def run_wrap #:nodoc:
      if fibered?
        EM.run do
          logger.info "EventMachine reactor started"
          Fiber.new do
            yield
            EM.stop
          end.resume
        end
      else
        yield
      end
    end
    
    def run_loop #:nodoc:
      health_check
      sleep(conf.pulse_delay)
    rescue StandardError => e
      logger.fatal(format_exception(e))
      raise
    ensure
      increment
    end
    
    def stop? #:nodoc:
      !!@stop
    end
    
    # Gracefully shutdown the tempest (i.e. end the run loop).
    def stop!
      @stop = true
    end

    def dead? #:nodoc:
      !!@dead
    end

    def die! #:nodoc:
      @dead = true
      Process.kill("KILL", Process.pid) # Seriously...
    end
    
    def shutdown #:nodoc:
      logger.info "shutting down..."
      conf.timeout_method.call(conf.shutdown_timeout) do
        dispatcher.stop!
        dispatcher.join
        storm.join
        storm.shutdown if storm.respond_to?(:shutdown)
      end
      logger.info "shutdown"
    rescue conf.timeout_exception => e
      logger.info "shutdown timeout exceeded"
      die!
    end
    
    def task_started(execution) #:nodoc:
      task = execution.args.first
      logger.info task.format_log_message("started")
    end
    
    def task_finished(execution) #:nodoc:
      task = execution.args.first

      case task.status
      when "failure"
        status = Col(task.status).red
      when "success"
        status = Col(task.status).green
      when "timeout"
        status = Col(task.status).yellow
      else
        status = Col(task.status).magenta
      end

      # If we're dead, then override status as aborted.
      status = Col("aborted").magenta if dead?
      
      logger.info task.format_log_message("#{status} #{execution.duration}")

      # Let them know if a callback failed.
      if task.callback_status
        status = Col("failure").cyan
        logger.warn task.format_log_message("#{status} in callback")
      end
    end
    
    # This is to ease testing.
    LOOP_ITERATIONS_ROLLOVER = 1_000_000 #:nodoc:
    def increment #:nodoc:
      if @loop_iterations == LOOP_ITERATIONS_ROLLOVER
        @loop_iterations = 0
      else
        @loop_iterations += 1
      end
    end

    # Sleep that is aware of what mode we're running.
    def sleep(n)
      if fibered?
        FiberStorm.sleep(n)
      else
        Kernel.sleep(n)
      end
    end
    
  end
end
