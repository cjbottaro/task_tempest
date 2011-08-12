require 'helper'

class TestCallbacks < Test::Unit::TestCase
  
  def test_no_callbacks
    assert_nothing_raised{ tempest_class.new }
  end
  
  def test_single_callbacks
    tempest_class.configure do
      before_initialize proc{ @counter  = 0 }
      after_initialize  proc{ @counter += 1 }
    end
    assert_equal 1, tempest_class.new.instance_variable_get("@counter")
  end
  
  def test_multiple_callbacks
    tempest_class.configure do
      before_initialize proc{ @counter  = 0 }
      before_initialize proc{ @counter += 1 }
      after_initialize  proc{ @counter += 1 }
      after_initialize  proc{ @counter += 1 }
    end
    
    assert_equal 3, tempest_class.new.instance_variable_get("@counter")
  end
  
  def test_task_status_callbacks
    
    task_class.configure_task do
      timeout 0.1
      after_success proc{ @status = "success" }
      after_timeout proc{ @status = "timeout" }
      after_failure proc{ @status = "failure" }
    end
    
    task_class.class_eval do
      
      def process(n)
        case n
        when 1
          nil
        when 2
          sleep(1)
        when 3
          raise RuntimeError, "oops"
        end
      end
      
    end
    
    tempest = tempest_class.new
    
    task = tempest.dispatcher.prepare [nil, task_class, 1]
    task.process
    assert_equal "success", task_class.instance_variable_get("@status")
    assert ! task.callback_status
    
    task = tempest.dispatcher.prepare [nil, task_class, 2]
    task.process
    assert_equal "timeout", task_class.instance_variable_get("@status")
    assert ! task.callback_status
    
    task = tempest.dispatcher.prepare [nil, task_class, 3]
    task.process
    assert_equal "failure", task_class.instance_variable_get("@status")
    assert ! task.callback_status
  end
  
  def test_task_status_callback_exception
    
    task_class.configure_task do
      after_success proc { |task| some_bogus_method }
    end
    
    task_class.class_eval do
      def process; end
    end
    
    tempest = tempest_class.new
    
    task = tempest.dispatcher.prepare [nil, task_class]
    stub.proxy(task.logger).error
    
    task.process
    
    assert_received(task.logger){ |logger| logger.error(/NameError.+`some_bogus_method'/) }
  end
  
end
