require "helper"

class TestEngine < Test::Unit::TestCase
  
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
  
  def test_shutdown_timeout
    tempest_class.configure{ shutdown_timeout 0.01 }
    tempest = tempest_class.new
    mock(dispatcher = Object.new).stop!{ sleep }
    stub(tempest).dispatcher{ dispatcher }
    mock(Process).kill("KILL", anything)
    stub.proxy(tempest.logger).info
    tempest.shutdown
    assert_received(tempest.logger){ |logger| logger.info(/exceeded/) }
  end
  
  def test_check_dispatcher_health
    error_class = Class.new(RuntimeError)
    tempest = tempest_class.new
    mock(tempest.dispatcher).consume{ raise error_class, "dequeue failed" }
    tempest.dispatcher.start
    while %w[sleep run].include?(tempest.dispatcher.primitive.status)
      sleep(0.01)
    end
    
    assert_raises(error_class){ tempest.health_check }
    
  end
  
  def test_check_execution_health

    # Create tempest class.
    tempest_class.configure do
      threads 5
    end

    # Create tempest.
    tempest = tempest_class.new

    # Add 3 finished executions to the storm.
    3.times do
      execution = tempest.storm.new_execution
      mock(execution).finished?{ true }
      tempest.storm.executions << execution
    end

    # Add 7 not finished executions to the storm.
    7.times do
      execution = tempest.storm.new_execution
      mock(execution).finished?{ false }
      tempest.storm.executions << execution
    end

    # Set up some mocks and expectations.
    mock(tempest.logger).warn("pool executions larger than pool size")

    # Assertion before.
    assert_equal 10, tempest.storm.executions.length

    # Action.
    tempest.check_execution_health

    # Assertion after.
    assert_equal 7, tempest.storm.executions.length

  end
  
  def test_submit
    message = TaskTempest::TaskFacade.message(task_class)
    mock(tempest_class.queue).enqueue(message)
    tempest_class.submit(task_class)
  end
  
end
