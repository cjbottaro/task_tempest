require "logger"

module TaskTempest #:nodoc:
  class Dispatcher #:nodoc:
    
    attr_reader :storm, :queue, :options, :thread, :message, :logger
    
    DEFAULTS = {
      :logger         => Logger.new(STDOUT),
      :task_logger    => Logger.new(STDOUT),
      :poll_interval  => 1,
      :start          => false
    }
    
    def initialize(storm, queue, options = {})
      @options = DEFAULTS.merge(options)
      @storm   = storm
      @queue   = queue
      @logger  = @options[:logger]
      
      start if @options[:start]
    end
    
    def died?
      @thread and @thread.status.nil?
    end
    
    def start
      @thread = Thread.new{ run }
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
      consume and dispatch
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
    
    def dispatch
      storm.execute(task.execution)
      logger.debug "dispatched"
    end
    
    def task(message = nil)
      task_id, task_class_name, *task_args = message || self.message
      if task_class_name.kind_of?(Class)
        task_class = task_class_name # For testing.
      else
        task_class = TaskTempest::Task.const_get(task_class_name)
      end
      task = task_class.instantiate(task_id, options[:task_logger], *task_args)
      
      task.execution = storm.new_execution(task){ task.run }
      task.execution.options[:timeout] = task_class.conf.timeout
      task
    end
    
  end
end