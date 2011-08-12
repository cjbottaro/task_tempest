require "task_tempest"

class MemoryQueue < Array
  alias_method :dequeue, :pop
  alias_method :enqueue, :unshift
end

class FiberTask
  extend TaskTempest::Task
  
  configure_task do
    timeout 1
    after_success proc {
      raise "ARRRGGGGGG!" if rand < 0.5
    }
    after_failure proc {
      @failures ||= 0
      @failures += 1
      task_logger.warn "#{@failures} failures and counting" if @failures % 10 == 0
    }
  end

  def self.process(n)
    new.start(n)
  end

  def conf
    self.class.task_configuration
  end
  
  def logger
    self.class.task_logger
  end

  def start(n)
    if n < 0.33
      FiberStorm.sleep(n)
      logger.info "I slept for #{n} seconds!"
    elsif n < 0.66
      FiberStorm.sleep(n)
      raise "oops"
    else
      FiberStorm.sleep(n + conf.timeout)
    end
  end
  
end

class FiberTempest < TaskTempest::Engine
  
  configure do
    fibers 5
    queue MemoryQueue.new
    shutdown_timeout 0.5
  end
  
end

5000.times do
  FiberTempest.submit(FiberTask, rand)
end

FiberTempest.run
