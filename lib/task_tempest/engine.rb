require "task_tempest/actualized_configuration"
require "task_tempest/bootstrapper"
require "task_tempest/configuration_dsl"
require "task_tempest/configuration"
require "task_tempest/error_handling"
require "task_tempest/health_checking"
require "task_tempest/reporting"

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
    attr_reader :book           #:nodoc:

    extend Helpers
    include ConfigurationDsl
    include ErrorHandling
    include HealthChecking
    include Reporting
    
    configure_with(Configuration) do
      initialize_class
    end
    
    def self.inherited(mod) #:nodoc:
      mod.instance_variable_set("@configuration", copy_struct(configuration))
      mod.initialize_class
    end
    
    def self.initialize_class #:nodoc:
      @conf = ActualizedConfiguration.new(self, configuration, Configuration::PROCS)
    end
    
    # The configuration as a struct-like object.
    def self.conf
      @conf
    end
    
    # Submit a task to the queue.
    # +task+ must be a kind of TaskTempest::Task.
    def self.submit(task)
      conf.queue.enqueue(task.to_message)
    end
    
    # Same as <tt>TaskTempest::Engine.new.run</tt>
    def self.run
      new.run
    end
    
    # Create a new TaskTempest::Engine instance.  The +before_initialize+ callbacks are run before
    # anything else is done.  Then logging is initialized, then thread pool created, etc.  Finally, the
    # +after_initialize+ callbacks are run.
    def initialize
      conf.before_initialize.each{ |callback| instance_exec(&callback) }
      
      require "task_tempest/recursive_mutex_hack" if conf.recursive_mutex_hack
      
      bootstrapper = Bootstrapper.new conf, :started_callback => method(:task_started),
                                            :finished_callback => method(:task_finished)
      
      @logger      = bootstrapper.logger
      @task_logger = bootstrapper.task_logger
      @storm       = bootstrapper.storm
      @book        = bootstrapper.book
      @dispatcher  = bootstrapper.dispatcher
      
      @last_report_time = Time.now
      @loop_iterations  = 0
      
      @task_classes = Set.new
      @task_classes_lock = Mutex.new
      
      logger.info "main thread: #{Thread.current.inspect}"
      logger.info "dispatcher thread: #{dispatcher.thread.inspect}"
      
      conf.after_initialize.each{ |callback| instance_exec(logger, &callback) }
    end
    
    # Same as +self.class.conf+
    def conf
      self.class.conf
    end
    
    # Begin the run loop which polls the queue indefinitely, dispatching tasks.  Several exceptions can
    # stop the tempest gracefully:  Interrupt, SystemExit, SignalException("SIGTERM").
    def run
      dispatcher.start
      run_loop while not stop?
      shutdown
    end
    
    def run_loop #:nodoc:
      health_check
      report_to_log if should_report?
      task_reporting
      sleep(conf.pulse_delay)
      increment
    rescue *SHUTDOWN_EXCEPTIONS => e
      raise if e.class == SignalException and e.message != "SIGTERM"
      logger.info "#{e.class} #{e.message}".strip + " detected"
      stop!
    end
    
    def stop? #:nodoc:
      !!@stop
    end
    
    # Gracefully shutdown the tempest (i.e. end the run loop).
    def stop!
      @stop = true
    end
    
    def shutdown #:nodoc:
      logger.info "shutting down..."
      begin
        conf.timeout_method.call(conf.shutdown_timeout) do
          dispatcher.stop!
          dispatcher.thread.join
          storm.join
          storm.shutdown
        end
      rescue conf.timeout_exception => e
        logger.info "shutdown timeout exceeded"
      end
      logger.info "shutdown"
    end
    
    def task_started(execution) #:nodoc:
      task = execution.args.first
      logger.info task.format_log("started")
      
      # We need to keep track of all the task classes used so we can do reporting.
      @task_classes_lock.synchronize{ @task_classes << task.class }
    end
    
    def task_finished(execution) #:nodoc:
      task = execution.args.first
      if execution.failure?
        task.logger.fatal format_exception(execution.exception)
        status = "failure"
      elsif execution.timeout?
        task.logger.fatal format_exception(execution.exception)
        status = "timeout"
      else
        status = "success"
      end
      
      if !task.callback(status)
        logger.error task.format_log(Col("exception").red.to_s + " in after_#{status}")
      end
      
      record do |stats|
        case status
        when "failure"
          stats[:failure] << execution.duration
        when "success"
          stats[:success] << execution.duration
        when "timeout"
          stats[:timeout] << execution.duration
        end
        stats[:threads][execution.thread] ||= 0
        stats[:threads][execution.thread] += 1
      end
      
      case status
      when "failure"
        status = Col(status).red
      when "success"
        status = Col(status).green
      when "timeout"
        status = Col(status).yellow
      end
      
      logger.info task.format_log("#{status} #{execution.duration}")
    end
    
    # This is to ease testing.
    LOOP_ITERATIONS_ROLLOVER = 1_000_000
    def increment #:nodoc:
      if @loop_iterations == LOOP_ITERATIONS_ROLLOVER
        @loop_iterations = 0
      else
        @loop_iterations += 1
      end
    end
    
  end
end