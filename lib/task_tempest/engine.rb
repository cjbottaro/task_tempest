require "benchmark"
require "thread_storm"

require "task_tempest/bootstrap"
require "task_tempest/callbacks"
require "task_tempest/error_handling"
require "task_tempest/settings"

module TaskTempest
  class Engine
    
    include Bootstrap
    include Callbacks
    include ErrorHandling
    include Settings
    
    def self.inherited(derived)
      derived.settings = settings.dup
    end
    
    def self.submit_message(message, *args)
      new.queue.enqueue(message, *args)
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
    
    def self.run
      new.run
    end
    
    def run
      bootstrap(:halt)
      with_shutdown_handling{ heartbeat while true }
    end
    
  private
    
    def heartbeat
      time = Benchmark.realtime do
        with_error_handling{ finish_tasks }
        with_error_handling{ health_check }
        with_error_handling{ bookkeeping }
      end
      logger.debug "heartbeat complete in #{time} seconds"
      sleep(settings.pulse_delay)
    end
    
    def finish_tasks
      @executions = storm.clear_executions(:finished?).each do |execution|
        task = execution.args.first
        if (e = execution.exception)
          logger.info task.format_log("failed", true)
          task.logger.fatal format_exception(e)
          on_task_exception(task, e)
        elsif execution.timed_out?
          logger.info task.format_log("timed out", true)
          on_task_timeout(task)
        else
          logger.info task.format_log("finished", true)
          on_require(task, execution.value)
        end
      end
    end
    
    def health_check
      if dispatcher.dead?
        with_error_handling{ dispatcher.exception }
        logger.error "dispatcher thread died, restarting"
        dispatcher.restart
      end
    end
    
    def bookkeeping
      bookkeeper.report(@executions)
    end
    
    def clean_shutdown
      logger.info "shutting down..."
      begin
        timeout(settings.shutdown_timeout) do
          dispatcher.shutdown
          storm.join
          storm.shutdown
        end
      rescue Timeout::Error => e
        logger.warn "shutdown timeout exceeded"
      end
      finish_tasks
      logger.info "shutdown"
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