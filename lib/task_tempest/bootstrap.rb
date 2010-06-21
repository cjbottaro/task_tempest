module TaskTempest
  module Bootstrap
    
    def self.included(mod)
      mod.send(:extend, ClassMethods)
      mod.send(:include, InstanceMethods)
    end
    
    module ClassMethods
    end
    
    module InstanceMethods
      
    private
      
      def bootstrap
        init_logging
        with_error_handling(:halt_on_error) do
          init_load_path
          init_thread_pool
          before_initialize
          init_tasks
          init_queue
          after_initialize
          init_require
        end
      end
      
      def init_logging
        @logger = Logger.new("#{settings.log_dir}/#{settings.process_name}.log")
        @logger.formatter = LogFormatter
        @logger.level = settings.log_level
        logger.info "starting up"

        @task_logger = Logger.new("#{settings.log_dir}/#{settings.process_name}.task.log")
        @task_logger.formatter = LogFormatter
        @task_logger.level = settings.log_level
      end
      
      def init_load_path
        $LOAD_PATH.delete(".")
        $LOAD_PATH.delete(settings.root_dir)
        $LOAD_PATH.push(settings.root_dir)
      end
      
      def init_tasks
        logger.info "initializing tasks"
        Dir.glob("#{settings.task_dir}/*").each do |file_path|
          logger.info file_path
          require file_path
        end
      end

      def init_queue
        logger.info "initializing queue"
        @queue = settings.queue.call(logger)
      end

      def init_thread_pool
        logger.info "initializing thread pool"
        @storm = ThreadStorm.new :size => settings.threads,
                                 :reraise => false,
                                 :timeout_method => settings.timeout_method,
                                 :timeout => settings.task_timeout
      end
      
      def before_initialize
        logger.info "calling before_initialize"
        settings.before_initialize.call(logger)
      end
      
      def after_initialize
        logger.info "calling after_initialize"
        settings.after_initialize.call(logger)
      end
      
      def init_require
        require "task_tempest/require"
      end
      
    end
      
  end
end