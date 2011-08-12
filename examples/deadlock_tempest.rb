require "task_tempest"

class MemoryQueue < Array
  alias_method :dequeue, :pop
  alias_method :enqueue, :unshift
end

class DeadlockTask
  extend TaskTempest::Task
  
  configure_task do
    timeout 1
  end
  
  @lock = Monitor.new
  class << self
    def synchronize(&block)
      @lock.synchronize(&block)
    end
  end
  
  def self.process
    synchronize{ sleep }
  end
  
end

class DeadlockTempest < TaskTempest::Engine
  
  configure do
    threads 5
    queue MemoryQueue.new
    shutdown_timeout 0.5
    
    # If you are using Ruby 1.9, you can see the Mutex + Timeout bug by
    # uncommenting the following line and tailing the task log.
    # recursive_mutex_hack false
  end
  
end

1000.times do
  DeadlockTempest.submit(DeadlockTask)
end

DeadlockTempest.run
