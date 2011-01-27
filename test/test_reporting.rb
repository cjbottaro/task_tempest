require "helper"

class TestReporting < Test::Unit::TestCase
  
  def test_engine_should_report
    
    tempest_class.configure do
      report :every => 10
    end
    
    Timecop.freeze do
      tempest = tempest_class.new
      assert ! tempest.should_report?
      Timecop.freeze(5){ assert ! tempest.should_report? }
      Timecop.freeze(11){ assert tempest.should_report? }
    end
    
  end
  
  def test_engine_report_callback
    
    # If there is no report callback defined, then report_to_log should do nothing.
    tempest = tempest_class.new
    mock(tempest.logger).debug(/executing report callback/).never
    tempest.report_to_log
    
    # If there is a callback defined, then obviously it should be called.
    tempest_class.configure do
      report{ @report_callback_called = true }
    end
    tempest = tempest_class.new
    mock(tempest.logger).debug(/executing report callback/)
    assert ! tempest.instance_variable_get("@report_callback_called")
    tempest.report_to_log
    assert tempest.instance_variable_get("@report_callback_called")
    
  end
  
  def test_engine_report_callback_failed
    tempest_class.configure do
      report{ bogus_method_called }
    end
    tempest = tempest_class.new
    mock(tempest.logger).error(/#{tempest_class}.+report.+failure.+\nNameError.+bogus_method_called/)
    tempest.report_to_log
  end
  
  def test_engine_task_reporting
    
    task_class.configure do
      report :every => 10 do "do something" end
    end
    
    tempest = tempest_class.new
    tempest.instance_variable_get("@task_classes") << task_class
    
    mock(task_class).report_to_log(tempest.logger, tempest.task_logger)
    
    Timecop.freeze(15) do
      assert task_class.should_report?
      tempest.task_reporting
    end
    
  end
  
  def test_task_should_report?
    
    task_class.configure do
      report :every => 10
    end
    
    Timecop.freeze do
      assert ! task_class.should_report?
      Timecop.freeze(5){ assert ! task_class.should_report? }
      Timecop.freeze(11){ assert ! task_class.should_report? }
    end
    
    task_class.configure do
      report :every => 10 do "do something" end
    end
    
    Timecop.freeze(0) do
      assert ! task_class.should_report?
      Timecop.freeze(5){ assert ! task_class.should_report? }
      Timecop.freeze(11){ assert task_class.should_report? }
    end
    
  end
  
  def test_task_report_callback
    task_class.configure do
      report{ @report_callback_called = true }
    end
    assert ! task_class.instance_variable_get("@report_callback_called")
    task_class.report_to_log(Logger.new("/dev/null"), Logger.new("/dev/null"))
    assert task_class.instance_variable_get("@report_callback_called")
  end
  
  def test_task_report_callback_failed
    logger = Logger.new("/dev/null")
    task_logger = Logger.new("/dev/null")
    
    task_class.configure do
      report{ bogus_method_called }
    end
    
    mock(logger).error(/#{task_class}.+report.+failure/)
    mock(task_logger).error(/#{task_class}.+NameError.+bogus_method_called/)
    task_class.report_to_log(logger, task_logger)
  end
  
  def test_task_book
    
    # Test that the task book gets reset after each report.
    
    task_class.configure do
      timeout 0.01
      report_stats do
        { :success => 0,
          :timeout => 0,
          :failure => 0 }
      end
      report do |stats, logger|
        @success = stats[:success]
        @timeout = stats[:timeout]
        @failure = stats[:failure]
      end
      after_success{ |task|    task.record{ |stats| stats[:success] += 1 } }
      after_timeout{ |task, e| task.record{ |stats| stats[:timeout] += 2 } }
      after_failure{ |task, e| task.record{ |stats| stats[:failure] += 3 } }
    end
    
    task_class.class_eval do
      def start(n)
        case n
        when 1
          "success"
        when 2
          sleep
        when 3
          raise "failure"
        end
      end
    end
    
    tempest = tempest_class.new
    
    1.upto(3) do |i|
      task = tempest.dispatcher.task [nil, task_class, i]
      task.execution.execute
    end
    
    assert_equal 1, task_class.book.instance_eval{ @book[:success] }
    assert_equal 2, task_class.book.instance_eval{ @book[:timeout] }
    assert_equal 3, task_class.book.instance_eval{ @book[:failure] }
    
    logger = Logger.new("/dev/null")
    task_logger = Logger.new("/dev/null")
    
    task_class.report_to_log(logger, task_logger)
    
    assert_equal 1, task_class.instance_variable_get("@success")
    assert_equal 2, task_class.instance_variable_get("@timeout")
    assert_equal 3, task_class.instance_variable_get("@failure")
    
    task_class.report_to_log(logger, task_logger)
    
    assert_equal 0, task_class.instance_variable_get("@success")
    assert_equal 0, task_class.instance_variable_get("@timeout")
    assert_equal 0, task_class.instance_variable_get("@failure")
  end
  
end