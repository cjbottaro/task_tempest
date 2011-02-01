require 'helper'

class TestBootstrapper < Test::Unit::TestCase
  
  def test_log_files
    system("rm *.log") unless Dir.glob("*.log").empty?
    
    tempest_class.configure do
      log_file "test.log"
      task_log_file "test.task.log"
    end
    
    assert_equal "#{tempest_class.conf.root}/test.log", tempest_class.conf.log_file
    assert_equal "#{tempest_class.conf.root}/test.task.log", tempest_class.conf.task_log_file
    
    bootstrapper = TaskTempest::Bootstrapper.new(tempest_class.conf)
    assert bootstrapper.logger.kind_of?(Logger)
    assert bootstrapper.task_logger.kind_of?(Logger)
    
    system("rm *.log")
  end
  
end