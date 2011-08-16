require "task_tempest"

class MemoryQueue < Array
  alias_method :dequeue, :pop
  alias_method :enqueue, :unshift
end

class SimpleTask
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
  
  def conf
    self.class.task_configuration
  end

  def logger
    task_logger
  end

  def process(n)
    if n < 0.33
      Kernel.sleep(n)
      logger.info "I slept for #{n} seconds!"
    elsif n < 0.66
      Kernel.sleep(n)
      raise "oops"
    else
      Kernel.sleep(n + conf.timeout)
    end
  end
  
end

class SimpleTempest < TaskTempest::Engine
  
  configure do
    threads 5
    queue MemoryQueue.new
    shutdown_timeout 0.5
  end
  
end

5000.times do
  SimpleTempest.submit(SimpleTask, rand)
end

SimpleTempest.run
