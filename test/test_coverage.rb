require "helper"

class TestCoverage < Test::Unit::TestCase
  
  ###########
  # task.rb #
  ##########
  
  def test_task
    
    assert_raises(RuntimeError){ task_class.new.start }
    
    task_class.class_eval do
      def start(n, m); n + m; end
    end
    
    task = task_class.new(5, 6)
    assert_equal 11, task.run
    
    id, class_name, *args = task.to_message
    assert_not_nil id
    assert_not_nil class_name
    assert_equal [5, 6], args
  end
  
  ################
  # reporting.rb #
  ################
  
  def test_reporting
    tempest = tempest_class.new
    tempest.report do |book|
      assert_equal [], book[:success]
      assert_equal [], book[:timeout]
      assert_equal [], book[:failure]
    end
  end
  
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
  
  ##############
  # helpers.rb #
  ##############
  
  def test_copy_struct
    klass = Class.new{ include TaskTempest::Helpers }
    assert_nil klass.new.copy_struct(nil)
  end
  
end