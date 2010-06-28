module TaskTempest
  class Dispatcher
    attr_reader :logger
    
    def initialize(options)
      options.each{ |k, v| instance_variable_set("@#{k}", v) }
      start
    end
    
    def start
      @thread = Thread.new{ run } if dead?
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
      task.execution = @storm.execute(task){ task.run }
      logger.info task.format_log("started")
    end
    
    def shutdown
      @thread and @thread.kill
      @thread.join
    end
    
  end
end