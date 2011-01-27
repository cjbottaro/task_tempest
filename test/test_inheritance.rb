require 'helper'

class TestInheritance < Test::Unit::TestCase
  
  def test_engine
    
    tempest_class.configure do
      threads 15
      report :every => 2
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
    assert_equal tempest_class.conf.report_interval, derived.conf.report_interval
    assert_equal tempest_class.conf.log_file, derived.conf.log_file
  end
  
  def test_task
    
    task_class.configure do
      timeout 1
      report :every => 2
    end
    
    # Oofa, in 1.8 the inherited callback happens *after* the class body has been evaluated.
    # To make the test work, we have to force it happen before the call to configure.
    
    derived = Class.new(task_class)
    derived.configure do
      timeout 2
    end
    
    assert_equal 1, task_class.conf.timeout
    assert_equal 2, derived.conf.timeout
    assert_equal task_class.conf.report_interval, derived.conf.report_interval
  end
  
end