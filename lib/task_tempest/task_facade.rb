require "digest"
require "logger"
require "task_tempest/logger_facade"

module TaskTempest
  class TaskFacade
    attr_reader :id, :task_class, :task, :args, :options, :config, :status, :callback_status, :logger

    DEFAULT_OPTIONS = {
      :id                => nil,
      :timeout_method    => Timeout.method(:timeout),
      :timeout_exception => Timeout::Error,
      :logger            => Logger.new(STDOUT)
    }

    def initialize(task_class, args, options = {})
      @task_class = task_class
      @options    = DEFAULT_OPTIONS.merge(options)
      @id         = @options[:id] || Digest::SHA1.hexdigest(Time.now.to_s + rand.to_s)[0,5]
      @args       = args
      @config     = task_class.task_configuration
      @status     = "unknown"
      @logger     = LoggerFacade.new(id, task_class, options[:logger])

      method, pass_args = config.initialize_method
      if pass_args
        @task = task_class.send(method, *args)
      else
        @task = task_class.send(method)
      end

      @task.instance_variable_set(:@task_logger, config.logger || logger)
    end

    def timeout_method
      @options[:timeout_method]
    end

    def timeout_exception
      @options[:timeout_exception]
    end

    def self.message(task_class, *args)
      [nil, task_class.name, *args]
    end

    def process
      with_timeout{ task.send(config.process_method, *args) }
    rescue timeout_exception
      handle_timeout
    rescue StandardError => e
      handle_failure(e)
    else
      handle_success
    end

    def with_timeout(&block)
      if config.timeout
        timeout_method.call(config.timeout, &block)
      else
        block.call
      end
    end

    def handle_timeout
      @status = "timeout"
      run_callbacks(config.after_timeout)
    end

    def handle_failure(e)
      @status = "failure"
      run_callbacks(config.after_failure, e)
      log_exception(e)
    end

    def handle_success
      run_callbacks(config.after_success)
      @status = "success"
    end

    def run_callbacks(callbacks, *args)
      [callbacks].flatten.each{ |callback| task_class.instance_exec(*args, &callback) }
    rescue StandardError => e
      @callback_status = "failure"
      log_exception(e)
    end

    def log_exception(e)
      message = "%s: %s\n%s" % [e.class, e.message, e.backtrace.join("\n")] 
      logger.error(message)
    end

    def format_log_message(message)
      "{%s} <%s> %s" % [id, task_class, message]
    end

  end
end
