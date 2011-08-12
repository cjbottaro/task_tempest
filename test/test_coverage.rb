require "helper"

class TestCoverage < Test::Unit::TestCase
  
  ###########################
  # recursive_mutex_hack.rb #
  ###########################
  
  def test_recursive_mutex_hack
    require "task_tempest/recursive_mutex_hack"
    
    mutex = Mutex.new
    mock(mutex).lock_without_hack do |m, _|
      raise ThreadError, "deadlock; recursive locking" unless m.instance_variable_get("@unlocked")
    end.times(2)
    mock(mutex).unlock do |m, _|
      m.instance_variable_set("@unlocked", true)
    end
    assert_nothing_raised{ mutex.lock }
    
    mutex = Mutex.new
    mock(mutex).lock_without_hack do |m, _|
      raise ThreadError, "something"
    end
    assert_raises(ThreadError){ mutex.lock }
    
  end
  
  ############
  # queue.rb #
  ############
  
  def test_queue
    queue_klass = Class.new(Array) do
      alias_method :enqueue, :unshift
      alias_method :dequeue, :pop
    end
    queue = TaskTempest::Queue.new(queue_klass.new)
    assert_equal 0, queue.size
    queue.enqueue("hi")
    assert_equal 1, queue.size
    assert_equal "hi", queue.dequeue
    assert_equal 0, queue.size
  end
  
  ####################
  # configuration.rb #
  ####################
  
  def test_configuration
    require "timeout"
    tempest_class.configure do
      name "MyTaskTempest"
      root "/Users/cjbottaro/my_task_tempest"
      timeout_method Timeout.method(:timeout)
      timeout_exception Class.new(Timeout::Error)
      shutdown_timeout 10
      log_format{ |*args| nil }
      log_level Logger::DEBUG
      task_log_format{ |*args| nil }
      task_log_level Logger::DEBUG
      queue_poll_interval 1
      pulse_delay 0.5
      recursive_mutex_hack true
    end
  end
  
  #############
  # engine.rb #
  #############
  
  def test_engine_run
    
    # This is weird.  If you move this test into test_engine.rb, then Rcov gets confused and doesn't
    # count a bunch of lines in engine.rb.
    
    tempest = tempest_class.new
    mock(tempest).run
    mock(tempest_class).new{ tempest }
    tempest_class.run
  end
  
  def test_increment_rollover
    tempest = tempest_class.new
    tempest.instance_variable_set(:@loop_iterations, TaskTempest::Engine::LOOP_ITERATIONS_ROLLOVER)
    tempest.increment
    assert_equal 0, tempest.instance_variable_get(:@loop_iterations)
  end
  
  #################
  # dispatcher.rb #
  #################
  
  def test_dispatcher_prepare
    require "thread_storm"
    dispatcher = TaskTempest::Dispatcher.new(ThreadStorm.new, Array.new)
    message = ["1a2b3c", "SomeClass", 3, 7]
    mock(TaskTempest::Task).const_get("SomeClass"){ task_class }
    task = dispatcher.prepare(message)
    assert_equal task_class, task.task_class
    assert_equal "1a2b3c", task.id
    assert_equal [3, 7], task.args
  end
  
end
