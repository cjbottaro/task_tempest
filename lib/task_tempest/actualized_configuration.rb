require "pathname"

require "configuration_dsl"

require "task_tempest/queue"

module TaskTempest #:nodoc:
  class ActualizedConfiguration < ConfigurationDsl::Actualizer #:nodoc:
    
    def log_file
      @log_file ||= begin
        log_file = actualize(configuration.log_file)
        log_file = "#{root}/#{log_file}" if log_file.kind_of?(String) and Pathname.new(log_file).relative?
        log_file
      end
    end
    
    def task_log_file
      @task_log_file ||= begin
        log_file = actualize(configuration.task_log_file)
        log_file = "#{root}/#{log_file}" if log_file.kind_of?(String) and Pathname.new(log_file).relative?
        log_file
      end
    end
    
    def queue
      @queue ||= Queue.new(actualize(configuration.queue))
    end
    
  end
end