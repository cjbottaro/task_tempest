module TaskTempest #:nodoc:
  module Task
    
    # Configuring a Task is done much the same way as configuring a TaskTempest::Engine, with a DSL.
    #   class CalculatePi
    #     extend TaskTempest::Task
    #     configure_task do
    #       timeout 5
    #       after_timeout proc {
    #         task_logger.error "I took too long!"
    #       }
    #     end
    #     ...
    #   end
    module Configuration
      
      # Maximum amount of time a task should be a allowed to run before it is abored.
      def timeout(seconds = nil)
        seconds
      end

      # Specify which method on the task class to invoke to create a task instance.
      # If pass_args is true, then the task arguments will be passed to the method.
      def initialize_method(name = :new, pass_args = false)
        [name.to_sym, pass_args]
      end

      # Specify which method to invoke to process the task.
      def process_method(name = :process)
        name.to_sym
      end

      # Specify a logger instead of using the default task logger.
      def logger(logger = nil)
        logger
      end
      
      # Define a callback to be called after a task finishes successfully.
      #   proc{ ... }
      def after_success(callback = nil)
        @after_success ||= []
        @after_success << callback if callback
        @after_success
      end
      
      # Define a callback to be called after a task fails (i.e. uncaught exception).
      #   proc{ |exception| ... }
      def after_failure(callback = nil)
        @after_failure ||= []
        @after_failure << callback if callback
        @after_failure
      end
      
      # Define a callback to be called after a task times out.  +exception+ is the timeout exception.
      #   proc{ ... }
      def after_timeout(callback = nil)
        @after_timeout ||= []
        @after_timeout << callback if callback
        @after_timeout
      end
      
    end
  end
end
