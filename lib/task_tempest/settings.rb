require "logger"
require "timeout"

module TaskTempest
  module Settings
    
    DEFAULTS = {
      # Basic settings
      :threads => 10,
      :log_level => Logger::INFO,
      :queue => nil,
      :bookkeeping_interval => 10*60, # 10 minutes
      :log_name => nil,
      
      # Delay settings
      :no_message_sleep => 1,
      :pulse_delay => 0.25,
      
      # Timeout settings
      :timeout_method => Timeout.method(:timeout),
      :task_timeout => nil,
      :shutdown_timeout => 5, # 5 seconds
      
      # Directory settings
      :root_dir => File.expand_path(Dir.pwd),
      :log_dir => File.expand_path(Dir.pwd),
      :task_dir => File.expand_path(Dir.pwd),
      
      # Callback settings
      :before_initialize => Proc.new{ |logger| },
      :after_initialize => Proc.new{ |logger| },
      :on_internal_exception => Proc.new{ |e, logger| },
      :on_task_exception => Proc.new{ |e, logger| },
      :on_require => Proc.new{ |files, logger| },
      :on_bookkeeping => Proc.new{ |book, logger| },
      :on_task_timeout => Proc.new{ |task, logger| }
    }
    
    def self.included(mod)
      mod.metaclass.class_eval{ attr_accessor :settings }
      mod.settings = Struct.new(*DEFAULTS.keys).new(*DEFAULTS.values)
      mod.send(:include, InstanceMethods)
      mod.send(:extend, ClassMethods)
    end
    
    module InstanceMethods
      
      def settings
        self.class.settings
      end
      
    end
    
    module ClassMethods
      
      def log_level(value)
        settings.log_level = value
      end
      
      def threads(value)
        settings.threads = value
      end
      
      def log_name(value)
        settings.log_name = value
      end
      
      def no_message_sleep(value)
        settings.no_message_sleep = value
      end
      
      def pulse_delay(value)
        settings.pulse_delay = value
      end
      
      def root_dir(path)
        settings.root_dir = File.expand_path(path)
      end
      
      def log_dir(value)
        settings.log_dir = File.expand_path(value)
      end
      
      def task_dir(value)
        settings.task_dir = File.expand_path(value)
      end
      
      def timeout_method(value)
        settings.timeout_method = value
      end
      
      def dequeue_timeout(seconds)
        settings.dequeue_timeout = value.to_f
      end
      
      def task_timeout(value)
        settings.task_timeout = value.to_f
      end
      
      def shutdown_timeout(value)
        settings.shutdown_timeout = value.to_f
      end
      
      def queue(queue = nil, &block)
        if block_given?
          settings.queue = block
        else
          settings.queue = queue
        end
      end
      
      def bookkeeping_interval(value)
        settings.bookkeeping_interval = value
      end
      
      def before_initialize(&block)
        settings.before_initialize = block
      end
      
      def after_initialize(&block)
        settings.after_initialize = block
      end
      
      def on_internal_exception(&block)
        settings.on_internal_exception = block
      end
      
      def on_task_exception(&block)
        settings.on_task_exception = block
      end
      
      def on_task_timeout(&block)
        settings.on_task_timeout = block
      end
      
      def on_require(&block)
        settings.on_require = block
      end
      
      def on_bookkeeping(&block)
        settings.on_bookkeeping = block
      end
      
    end
  end
end