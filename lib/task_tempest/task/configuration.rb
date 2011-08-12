module TaskTempest #:nodoc:
  module Task
    
    # Configuring a Task is done much the same way as configuring a TaskTempest::Engine, with a DSL.
    #   class CalculatePi < TaskTempest::Task
    #     configure do
    #       timeout 5
    #       report_stats do
    #         { :timeouts => 0 }
    #       end
    #       after_timeout do |task, exception|
    #         task.logger.error "I took too long and got this: #{exception} !"
    #         task.record{ |stats| stats[:timeouts] += 1 }
    #       end
    #       report :every => 120 do |stats, logger|
    #         logger.warn "#{stats[:timeouts]} CalculatePi tasks have timed out in the past 120 seconds."
    #       end
    #     end
    #     ...
    #   end
    module Configuration
      
      # Maximum amount of time a task should be a allowed to run before it is abored.
      def timeout(seconds = nil)
        seconds
      end

      def process_method(name = :process)
        name.to_sym
      end

      def logger(logger = nil)
        logger
      end
      
      # Define a callback to be called after a task finishes successfully.
      def after_success(callback = nil)
        @after_success ||= []
        @after_success << callback if callback
        @after_success
      end
      
      # Define a callback to be called after a task fails (i.e. uncaught exception).
      def after_failure(callback = nil)
        @after_failure ||= []
        @after_failure << callback if callback
        @after_failure
      end
      
      # Define a callback to be called after a task times out.  +exception+ is the timeout exception.
      def after_timeout(callback = nil)
        @after_timeout ||= []
        @after_timeout << callback if callback
        @after_timeout
      end
      
    end
  end
end
