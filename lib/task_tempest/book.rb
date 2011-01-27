require "monitor"

module TaskTempest #:nodoc:
  class Book #:nodoc:
    
    def initialize(&block)
      @lock = Monitor.new
      @init = block
      reset
    end
    
    def reset
      @lock.synchronize{ @book.tap{ @book = @init.call } }
    end
    
    def record
      @lock.synchronize{ yield(@book) }
    end
    
    # Not used anywhere since we stay threadsafe by duping the stats and giving that to the user.
    def report
      @lock.synchronize{ yield(@book).tap{ reset } }
    end
    
  end
end