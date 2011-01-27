require 'helper'

class TestCallbacks < Test::Unit::TestCase
  
  def test_no_callbacks
    assert_nothing_raised{ tempest_class.new }
  end
  
  def test_single_callbacks
    tempest_class.configure do
      before_initialize{ @counter  = 0 }
      after_initialize{  @counter += 1 }
    end
    assert_equal 1, tempest_class.new.instance_variable_get("@counter")
  end
  
  def test_multiple_callbacks
    tempest_class.configure do
      before_initialize{ @counter  = 0 }
      before_initialize{ @counter += 1 }
      after_initialize{  @counter += 1 }
      after_initialize{  @counter += 1 }
    end
    
    assert_equal 3, tempest_class.new.instance_variable_get("@counter")
  end
  
  def test_task_status_callbacks
    
    task_class.configure do
      timeout 0.1
      after_success{ |task| task.class.instance_eval{ @status = "success" } }
      after_timeout{ |task, e| task.class.instance_eval{ @status = "timeout" } }
      after_failure{ |task, e| task.class.instance_eval{ @status = "failure" } }
    end
    
    task_class.class_eval do
      
      def start(n)
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
    
    task = tempest.dispatcher.task [nil, task_class, 1]
    task.execution.execute
    assert_equal "success", task_class.instance_variable_get("@status")
    assert ! task.execution.callback_exception?
    
    task = tempest.dispatcher.task [nil, task_class, 2]
    task.execution.execute
    assert_equal "timeout", task_class.instance_variable_get("@status")
    assert ! task.execution.callback_exception?
    
    task = tempest.dispatcher.task [nil, task_class, 3]
    task.execution.execute
    assert_equal "failure", task_class.instance_variable_get("@status")
    assert ! task.execution.callback_exception?
  end
  
  def test_task_status_callback_exception
    
    task_class.configure do
      after_success{ |task| some_bogus_method }
    end
    
    task_class.class_eval do
      def start; end
    end
    
    tempest = tempest_class.new
    stub.proxy(tempest.logger).error
    
    task = tempest.dispatcher.task [nil, task_class]
    stub.proxy(task.logger).error
    
    task.execution.execute
    
    assert_received(tempest.logger){ |logger| logger.error(/exception.+in after_success/) }
    assert_received(task.logger){ |logger| logger.error(/NameError.+`some_bogus_method'/) }
  end
  
end