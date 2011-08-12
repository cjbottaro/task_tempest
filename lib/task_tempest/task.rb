require "configuration_dsl"
require "task_tempest/task/configuration"

module TaskTempest
  module Task

    def self.extended(mod)
      mod.extend(ConfigurationDsl)
      mod.configure_with(Configuration, :method => :configure_task, :storage => :task_configuration)
      mod.send(:include, InstanceMethods)
    end

    module InstanceMethods

      def task_logger
        @task_logger
      end

    end

  end
end
