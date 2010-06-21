module TaskTempest
  module ErrorHandling
    
    SHUTDOWN_EXCEPTIONS = [
      Interrupt,
      SystemExit,
      SignalException
    ]
    
    def with_error_handling(halt_on_error = false)
      yield
    rescue *SHUTDOWN_EXCEPTIONS => e
      raise
    rescue Exception => e
      on_internal_exception(e)
      if halt_on_error
        logger.fatal format_exception(e)
        exit(-1)
      else
        logger.error format_exception(e)
      end
    end
    
    def with_shutdown_handling
      yield
    rescue *SHUTDOWN_EXCEPTIONS => e
      if e.class == SignalException
        handle_shutdown_signal(e) or raise
      else
        clean_shutdown
      end
    end
    
    def handle_shutdown_signal(e)
      case e.message
      when "SIGTERM"
        logger.info "SIGTERM detected"
        dirty_shutdown
      when "SIGUSR2"
        logger.info "SIGUSR2 detected"
        clean_shutdown
      else
        false
      end
    end
    
    def format_exception(e)
      "#{e.class} #{e.message}\n" + e.backtrace.join("\n")
    end
    
  end
end