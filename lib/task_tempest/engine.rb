require "thread_storm"

require "task_tempest/bookkeeper"
require "task_tempest/bootstrap"
require "task_tempest/callbacks"
require "task_tempest/error_handling"
require "task_tempest/settings"

module TaskTempest
  class Engine
    attr_reader :logger, :task_logger, :queue, :storm, :message, :tasks
    
    include Bootstrap
    include Callbacks
    include ErrorHandling
    include Settings
    
    def self.inherited(derived)
      derived.settings = settings.dup
    end
    
    def self.submit_message(message, *args)
      logger = Logger.new(STDOUT)
      queue  = settings.queue.call(logger)
      settings.enqueue.call(queue, message, logger, *args)
    end
    
    def self.submit_task(task, *args)
      submit_message(task.to_message, *args)
    end
    
    def self.submit(task_or_message, *args)
      if task_or_message.kind_of?(TaskTempest::Task)
        submit_task(task_or_message, *args)
      else
        submit_message(task_or_message, *args)
      end
    end
    
    def initialize
      @tasks = []
      @bookkeeping_timer = Time.now
    end
    
    def run
      bootstrap
      logger.info "starting run loop"
      with_shutdown_handling{ heartbeat while true }
    end
    
  private
    
    def heartbeat
      with_error_handling{ receive_message }
      with_error_handling{ dispatch_message }
      with_error_handling{ finish_tasks }
      with_error_handling{ bookkeeping }
    end
    
    def receive_message
      logger.debug "receiving message"
      
      if message
        logger.debug "already have message"
        return
      end
      
      # Why do we do it this way?  Because of badly behaved dequeue
      # definitions.  For example, right_aws rescues any exception
      # when making a request to Amazon.  Thus if we try to shutdown
      # our tempest, right_aws could potentially swallow that exception.
      
      @receive_storm ||= ThreadStorm.new :size => 1,
                                         :timeout_method => settings.timeout_method,
                                         :timeout => settings.dequeue_timeout
      
      execution = @receive_storm.execute{ settings.dequeue.call(queue, logger) }
      with_error_handling do
        @message = execution.value
        logger.warn "dequeue timed out" if execution.timed_out?
      end
      @receive_storm.clear_executions # Prevent memory leak.
        
      if message.nil?
        logger.debug "no available messages, sleeping for #{settings.no_message_sleep}"
        sleep(settings.no_message_sleep)
      end
    end
    
    def dispatch_message
      if storm.busy_workers.length == storm.size
        logger.debug "no available threads, sleeping for #{settings.no_thread_sleep}"
        sleep(settings.no_thread_sleep)
      elsif message
        dispatch_task
      end
    end
    
    def dispatch_task
      id, name, *args = message
      task = TaskTempest::Task.const_get(name).new(*args)
      task.override :id => id, :logger => task_logger
      task.spawn(storm)
      tasks << task
      logger.info task.format_log("started", true)
      task.logger.info "arguments #{args.inspect}"
    rescue Exception => e
      raise
    ensure
      @message = nil # Ensure we pop a new message off the queue on next loop iteration.
    end
    
    def finish_tasks
      finished, @tasks = tasks.separate{ |task| task.execution.finished? }
      finished.each{ |task| handle_finished_task(task) }
    end
    
    def handle_finished_task(task)
      if (e = task.execution.exception)
        logger.info task.format_log("failed", true)
        task.logger.fatal format_exception(e)
        on_task_exception(task, e)
      elsif task.execution.timed_out?
        logger.info task.format_log("timed out", true)
        on_task_timeout(task)
      else
        logger.info task.format_log("finished", true)
        on_require(task, task.execution.value)
      end
    end
    
    def bookkeeping
      # Return unless it's time to do bookkeeping.
      if Time.now - @bookkeeping_timer > settings.bookkeeping_interval
        @bookkeeping_timer = Time.now # Reset the timer.
      else
        return
      end
      
      keeper = Bookkeeper.new(storm)
      logger.info "[BOOKKEEPING] " + keeper.book.inspect
      on_bookkeeping(keeper.book)
    end
    
    def clean_shutdown
      logger.info "shutting down"
      begin
        timeout(settings.shutdown_timeout) do
          storm.join
          storm.shutdown
        end
      rescue Timeout::Error => e
        logger.warn "shutdown timeout exceeded"
      end
      finish_tasks
      exit(0)
    end
    
    def dirty_shutdown
      exit(-1)
    end
    
    def timeout(timeout, &block)
      settings.timeout_method.call(timeout, &block)
    end
    
  end
end