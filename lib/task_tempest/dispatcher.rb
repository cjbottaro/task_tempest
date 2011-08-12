require "logger"

module TaskTempest #:nodoc:
  class Dispatcher #:nodoc:
    
    attr_reader :storm, :queue, :options, :message, :task, :logger
    
    DEFAULT_OPTIONS = {
      :logger            => Logger.new(STDOUT),
      :task_logger       => Logger.new(STDOUT),
      :poll_interval     => 1,
      :timeout_method    => nil,
      :timeout_exception => nil,
      :start             => false
    }
    
    def initialize(storm, queue, options = {})
      @storm   = storm
      @queue   = queue
      @options = DEFAULT_OPTIONS.merge(options)

      @logger  = @options[:logger]
      @started = false

      if threaded?
        @thread = Thread.new{ Thread.stop; @started = true; run }.tap{ Thread.pass }
      else
        @fiber = Fiber.new{ @started = true; run }
      end
      
      start if @options[:start]
    end

    def fibered?
      defined?(FiberStorm) and @storm.instance_of?(FiberStorm)
    end
    
    def threaded?
      defined?(ThreadStorm) and @storm.instance_of?(ThreadStorm)
    end

    def primitive
      @thread or @fiber
    end

    def started?
      @started
    end
    
    def died?
      if threaded?
        @thread.status.nil?
      else
        not @fiber.alive?
      end
    end
    
    def start
      if threaded?
        @thread.run while not started?
      else
        @fiber.resume while not started?
      end
    end

    def join
      if threaded?
        @thread.join
      else
        while @fiber.alive?
          fiber = Fiber.current
          EM.next_tick{ fiber.resume }
          Fiber.yield
        end
      end
    end
    
    def stop?
      !!@stop
    end
    
    def stop!
      @stop = true
    end
    
    def run
      run_loop while not stop?
    end
    
    def run_loop
      @message  = nil
      @task     = nil
      consume and prepare and dispatch
    end
    
    def consume
      logger.debug "calling dequeue"
      @message = queue.dequeue.tap do |message|
        if not message
          logger.debug "queue empty, sleeping for #{options[:poll_interval]} seconds"
          sleep(options[:poll_interval])
        else
          logger.debug "message received"
        end
      end
    end
    
    def prepare(message = nil)
      task_id, task_class_name, *task_args = message || self.message

      if task_class_name.kind_of?(Class)
        task_class = task_class_name # For testing.
      else
        begin
          task_class = TaskTempest::Task.const_get(task_class_name)
        rescue NameError => e
          logger.error "task class not found: #{task_class_name}"
          return
        end
      end
      
      @task = TaskFacade.new(task_class, task_args, :id                 => task_id,
                                                    :logger             => options[:task_logger],
                                                    :timeout_method     => options[:timeout_method],
                                                    :timeout_exception  => options[:timeout_exception])
    end
    
    def dispatch(task = nil)
      task ||= self.task
      storm.execute(task){ task.process }
      logger.debug "dispatched"
    end

  private

    def sleep(duration)
      if threaded?
        Kernel.sleep(duration)
      else
        FiberStorm.sleep(duration)
      end
    end
    
  end
end
