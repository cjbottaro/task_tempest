require "configuration_dsl"
require "task_tempest/task/configuration"

module TaskTempest
  module Task

    def self.extended(mod)
      mod.extend(ConfigurationDsl)
      mod.configure_with(Configuration, :method => :configure_task, :storage => :task_configuration)
    end

    def task_logger
      task_configuration.logger
    end

  end
end
