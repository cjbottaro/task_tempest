require "helper"

class TestCoverage < Test::Unit::TestCase
  
  def test_run
    tempest = tempest_class.new
    
    # Mock sleep so the tests go faster.
    stub(tempest).sleep(tempest.conf.pulse_delay)
    stub(tempest.dispatcher).sleep(tempest.conf.queue_poll_interval)
    
    # Have to run on a thread so we can asynchronously call stop!
    thread = Thread.new{ tempest.run }
    
    # Make sure we complete as least one run loop.
    sleep(0.01) while tempest.instance_variable_get("@loop_iterations") == 0
    
    # Stop the tempest.
    tempest.stop!
    
    assert_nothing_raised{ thread.join }
  end
  
  def test_shutdown_exceptions
    tempest = tempest_class.new
    mock(tempest).health_check{ raise SystemExit, "shutdown" }
    tempest.run_loop
    assert tempest.stop?
    
    mock(tempest).health_check{ raise SignalException, "USR1" }
    assert_raises(SignalException){ tempest.run_loop }
  end
  
  def test_check_dispatcher_health
    error_class = Class.new(RuntimeError)
    tempest = tempest_class.new
    mock(tempest.dispatcher).consume{ raise error_class, "dequeue failed" }
    tempest.dispatcher.start
    while %w[sleep run].include?(tempest.dispatcher.thread.status)
      puts tempest.dispatcher.thread.status
      sleep(0.01)
    end
    
    assert_raises(error_class){ tempest.health_check }
    
  end
  
  def test_check_execution_health
    error_class = Class.new(RuntimeError)
    task_class.class_eval do
      def start; nil; end
    end
    tempest = tempest_class.new
    
    mock(tempest).record{ raise error_class, "oops" }
    
    task = tempest.dispatcher.task [nil, task_class]
    task.execution.options[:finished_callback] = tempest.method(:task_finished)
    tempest.storm.executions << task.execution
    
    task.execution.execute
    assert task.execution.callback_exception?
    assert_raises(error_class){ tempest.health_check }
  end

end