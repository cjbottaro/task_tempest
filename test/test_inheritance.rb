require 'helper'

class TestInheritance < Test::Unit::TestCase
  
  def test_engine
    
    tempest_class.configure do
      threads 15
      log_file{ "log/#{conf.name}.log"}
    end
    
    # Oofa, in 1.8 the inherited callback happens *after* the class body has been evaluated.
    # To make the test work, we have to force it happen before the call to configure.
    
    derived = Class.new(tempest_class)
    derived.configure do
      threads 10
    end
    
    assert_equal 15, tempest_class.conf.threads
    assert_equal 10, derived.conf.threads
    assert_equal tempest_class.conf.log_file, derived.conf.log_file
  end
  
  def test_task
    
    task_class.configure_task do
      timeout 1
    end
    
    # Oofa, in 1.8 the inherited callback happens *after* the class body has been evaluated.
    # To make the test work, we have to force it happen before the call to configure.
    
    derived = Class.new(task_class)
    derived.configure_task do
      timeout 2
    end
    
    assert_equal 1, task_class.task_configuration.timeout
    assert_equal 2, derived.task_configuration.timeout
  end
  
end
