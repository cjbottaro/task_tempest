module TaskTempest #:nodoc:
  module ErrorHandling #:nodoc:all
    
    SHUTDOWN_EXCEPTIONS = [
      Interrupt,
      SystemExit,
      SignalException
    ]
        
    def format_exception(e)
      "#{e.class}: #{e.message}\n" + e.backtrace.join("\n")
    end
    
  end
end