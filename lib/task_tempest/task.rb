require "configuration_dsl"
require "task_tempest/task/configuration"

module TaskTempest

  # Extend this module in a class to make the class a task.  It will define +configure_task+ on the class
  # and +task_logger+ on instances of the class.
  #   class MyTask
  #     extend TaskTempest::Task
  #
  #     configure_task do
  #       after_failure proc { |e|
  #         task_logger.error "Oops, I did bad: #{e}"
  #       }
  #     end
  #     
  #     def process(*args)
  #       task_logger.info "I'm processing #{args.inspect}"
  #       ...
  #     end
  #   end
  module Task

    def self.extended(mod) #:nodoc:
      mod.extend(ConfigurationDsl)
      mod.configure_with(Configuration, :method => :configure_task, :storage => :task_configuration)
      mod.send(:include, InstanceMethods)
    end

    module InstanceMethods #:nodoc:

      def task_logger
        @task_logger
      end

    end

  end
end
