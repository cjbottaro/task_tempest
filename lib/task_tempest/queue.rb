module TaskTempest #:nodoc:
  
  # We can't rely on the queue being passed in by the user to be thread safe, which is needed
  # because the main thread accesses the queue during reporting at the same time the dispatcher
  # thread is dequeuing.  This class wraps the user passed queue with locks and what not.
  class Queue #:nodoc:
    
    def initialize(queue)
      @lock = Mutex.new
      @queue = queue
    end
    
    def dequeue
      @lock.synchronize{ @queue.dequeue }
    end
    
    def enqueue(*args)
      @lock.synchronize{ @queue.enqueue(*args) }
    end
    
    def size
      @lock.synchronize{ @queue.size }
    end
    
  end
end