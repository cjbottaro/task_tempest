module TaskTempest #:nodoc:
  module ErrorHandling #:nodoc:all
    
    def format_exception(e)
      "#{e.class}: #{e.message}\n" + e.backtrace.join("\n")
    end
    
  end
end
