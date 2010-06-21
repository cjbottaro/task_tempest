module TaskTempest
  module Callbacks
    
    def on_bookkeeping(book)
      settings.on_bookkeeping.call(book, logger) if settings.on_bookkeeping
    end
    
    def on_require(task, files)
      return if files.empty?
      logger.warn task.format_log "Kernel.require called on #{files.inspect}"
      settings.on_require.call(task, files, logger)
    end
    
    def on_internal_exception(e)
      settings.on_internal_exception.call(e, logger)
    rescue Exception => e
      logger.error format_exception(e) rescue nil
    end
    
    def on_task_exception(task, e)
      settings.on_task_exception.call(task, e, logger)
    end
    
    def on_task_timeout(task)
      settings.on_task_timeout.call(task, logger)
    end
    
  end
end