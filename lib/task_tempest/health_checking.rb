module TaskTempest #:nodoc:
  module HealthChecking #:nodoc:
    
    def health_check
      check_dispatcher_health
      check_execution_health
    end
    
    def check_dispatcher_health
      dispatcher.join if dispatcher.died?
    rescue StandardError => e
      logger.fatal format_exception(e)
      raise
    end
    
    def check_execution_health
      storm.clear_executions(:finished?).each do |execution|
        raise execution.callback_exception.values.first if execution.callback_exception?
      end
    end
    
  end
end
