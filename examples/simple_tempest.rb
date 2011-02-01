require "task_tempest"

class MemoryQueue < Array
  alias_method :dequeue, :pop
  alias_method :enqueue, :unshift
end

class SimpleTask < TaskTempest::Task
  
  configure do
    timeout 1
    report_stats do
      { :success => 0,
        :failure => 0,
        :timeout => 0 }
    end
    report :every => 5 do |stats, logger|
      logger.info "[STATS] " + stats.inspect
    end
    after_success do |task|
      task.record{ |stats| stats[:success] += 1 }
    end
    after_failure do |task, e|
      task.record{ |stats| stats[:failure] += 1 }
    end
    after_timeout do |task, e|
      task.record{ |stats| stats[:timeout] += 1 }
    end
  end
  
  def start(n)
    if n < 0.33
      sleep(n)
      logger.info "I slept for #{n} seconds!"
    elsif n < 0.66
      sleep(n)
      raise "oops"
    else
      sleep(n + conf.timeout)
    end
  end
  
end

class SimpleTempest < TaskTempest::Engine
  
  configure do
    threads 5
    queue MemoryQueue.new
    report :every => 10
    shutdown_timeout 0.5
  end
  
end

5000.times do
  task = SimpleTask.new(rand)
  SimpleTempest.submit(task)
end

SimpleTempest.run
