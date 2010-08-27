module TaskTempest
  class Dispatcher
    attr_reader :logger
    
    def initialize(options)
      options.each{ |k, v| instance_variable_set("@#{k}", v) }
      start
    end
    
    def start
      if dead?
        @queue = @queue_factory.call
        @thread = Thread.new{ run }
      end
    end
    
    alias_method :restart, :start
    
    def alive?
      @thread and @thread.alive?
    end
    
    def dead?
      not alive?
    end
    
    def exception
      dead? and @thread.value
    end
    
    def run
      run_loop while true
    end
    
    def run_loop
      consume and dispatch
    end
    
    def consume
      @message = @queue.dequeue
      if @message
        true
      else
        logger.debug "queue empty, sleeping for #{@no_message_sleep}"
        sleep(@no_message_sleep)
        false
      end
    end
    
    def dispatch
      task_id, task_class_name, *task_args = @message
      task_class = TaskTempest::Task.const_get(task_class_name)
      task = task_class.new(*task_args).init(:id => task_id, :logger => @task_logger)
      
      # There is a nasty race condition here.  The execution can run and finish and
      # Engine#finish_tasks called before the below task.execution assignment happens.
      # Thus we'll crash when we try to call Task#format log from Engine#finish_tasks.
      # task.execution = @storm.execute(task){ task.run }
      
      # ThreadStorm 0.6.0 provides a way to make sure that race condition commented
      # above doesn't happen.  How nice of the ThreadStorm author.
      task.execution = ThreadStorm::Execution.new(task){ task.run }
      task.execution.options[:timeout] = task_class.settings[:timeout] if task_class.settings.has_key?(:timeout)
      @storm.execute(task.execution)
      
      logger.info task.format_log("started")
    end
    
    def shutdown
      @thread and @thread.kill
      @thread.join
    end
    
  end
end