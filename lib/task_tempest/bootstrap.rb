require "thread_storm"
require "task_tempest/bookkeeper"
require "task_tempest/dispatcher"

module TaskTempest
  module Bootstrap
    
    def logger
      @logger ||= begin
        log_name = settings.log_name || self.class.name
        path = "#{settings.log_dir}/#{log_name}.log"
        Logger.new(path).tap do |logger|
          logger.formatter = LogFormatter
          logger.level = settings.log_level
        end
      end
    end
    
    def task_logger
      @task_logger ||= begin
        log_name = settings.log_name || self.class.name
        path = "#{settings.log_dir}/#{log_name}.task.log"
        Logger.new(path).tap do |logger|
          logger.formatter = LogFormatter
          logger.level = settings.log_level
        end
      end
    end
    
    def queue
      @queue ||= begin
        case settings.queue
        when Proc
          settings.queue.call(logger)
        else
          settings.queue
        end
      end
    end
    
    def storm
      @storm ||= begin
        ThreadStorm.new :size => settings.threads,
                        :reraise => false,
                        :execute_blocks => true,
                        :timeout_method => settings.timeout_method,
                        :timeout => settings.task_timeout
      end
    end
    
    def dispatcher
      @dispatcher ||= begin
        Dispatcher.new :logger => logger,
                       :task_logger => task_logger,
                       :queue_factory => Proc.new{ settings.queue.call(logger) },
                       :storm => storm,
                       :no_message_sleep => settings.no_message_sleep
      end
    end
    
    def bookkeeper
      @bookkeeper ||= begin
        Bookkeeper.new :storm => storm,
                       :queue_factory => Proc.new{ settings.queue.call(logger) },
                       :interval => settings.bookkeeping_interval,
                       :logger => logger
      end
    end
    
    def bootstrap(error_action)
      init_logging
      with_error_handling(error_action) do
        before_initialize
        init_require
        init_tasks
        init_thread_pool
        init_queue
        init_bookkeeper
        init_task_logging
        init_dispatcher
        after_initialize
      end
    end
    
    def init_logging
      @logger and return
      logger
      logger.info "logger initialized"
    end
    
    def init_task_logging
      @task_logger and return
      task_logger
      logger.info "task logger initialized"
    end
    
    def init_thread_pool
      @storm and return
      logger.info "initializing thread pool"
      storm
    end
    
    def init_tasks
      @init_tasks ||= begin
        logger.info "initializing tasks"
        Dir.glob("#{settings.task_dir}/*.rb").each do |file_path|
          logger.debug file_path
          require file_path
        end
        true
      end
    end
    
    def init_queue
      @queue and return
      logger.info "initializing queue"
      queue
    end
    
    def init_require
      require "task_tempest/require"
    end
    
    def init_bookkeeper
      @bookkeeper and return
      logger.info "initializing bookkeeper"
      bookkeeper
    end
    
    def init_dispatcher
      @dispatcher and return
      logger.info "initializing dispatcher"
      dispatcher
    end
    
    def before_initialize
      @before_initialize ||= begin
        logger.info "before_initialize called"
        settings.before_initialize.call(logger)
        true
      end
    end
    
    def after_initialize
      @after_initialize ||= begin
        settings.after_initialize.call(logger)
        logger.info "after_initialize called"
        true
      end
    end
      
  end
end