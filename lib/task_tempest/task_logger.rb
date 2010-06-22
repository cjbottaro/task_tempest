module TaskTempest
  class TaskLogger
    
    def initialize(logger, task)
      @logger = logger
      @task = task
    end
    
    %w[debug info warn error fatal].each do |level|
      class_eval <<-STR
        def #{level}(msg)
          @logger.#{level} @task.format_log(msg)
        end
      STR
    end
    
  end
end