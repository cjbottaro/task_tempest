require "logger"
require "thread_storm"

require "task_tempest/active_support"
require "task_tempest/book"
require "task_tempest/dispatcher"

module TaskTempest #:nodoc:
  class Bootstrapper #:nodoc:
    attr_reader :conf
    
    extend Memoizer
    
    def initialize(conf, options = {})
      @conf = conf
      @options = options
    end
    
    def logger
      if conf.log_file.kind_of?(String)
        Logger.new(conf.log_file).tap do |logger|
          logger.formatter = conf.log_format
          logger.level = conf.log_level
          logger.info "logging initialized"
        end
      else
        conf.log_file
      end
    end
    memoize :logger
    
    def task_logger
      if conf.task_log_file.kind_of?(String)
        Logger.new(conf.task_log_file).tap do |task_logger|
          task_logger.formatter = conf.task_log_format
          task_logger.level = conf.task_log_level
          logger.info "task logging initialized"
        end
      else
        conf.task_log_file
      end
    end
    memoize :task_logger
    
    def storm
      options = { :size => conf.threads,
                  :reraise => false,
                  :execute_blocks => true,
                  :timeout_method => conf.timeout_method,
                  :started_callback => @options[:started_callback],
                  :finished_callback => @options[:finished_callback] }
      ThreadStorm.new(options).tap{ logger.info "thread pool initialized" }
    end
    memoize :storm
    
    def dispatcher
      options = { :logger        => logger,
                  :task_logger   => task_logger,
                  :poll_interval => conf.queue_poll_interval,
                  :delayed       => true }
      Dispatcher.new(storm, conf.queue, options).tap{ logger.info "dispatcher initialized" }
    end
    memoize :dispatcher
    
    def book
      Book.new do
        { :failure => [],
          :success => [],
          :timeout => [],
          :threads => storm.threads.inject({}){ |memo, thread| memo[thread] = 0; memo } }
      end.tap{ logger.info "reporting initialized" }
    end
    memoize :book
    
  end
end