require "helper"
require "thread_storm"

class TestDispatcher < Test::Unit::TestCase
  attr_reader :dispatcher
  
  def setup
    super
    storm = ThreadStorm.new
    queue = Class.new(Array) do
      alias_method :dequeue, :pop
      alias_method :enqueue, :unshift
    end.new
    logger = Logger.new("/dev/null")
    @dispatcher = TaskTempest::Dispatcher.new(storm, queue, :logger => logger, :task_logger => logger)
  end
  
  def test_does_not_automatically_start
    assert ! dispatcher.started?
  end
  
  def test_start_stop
    assert_equal false, dispatcher.stop?
    dispatcher.stop!
    mock(dispatcher).consume.never
    dispatcher.run
  end
  
  def test_consume
    # Test no message.
    mock(dispatcher).sleep(dispatcher.options[:poll_interval])
    dispatcher.consume
    assert_nil dispatcher.message
    
    # Test message.
    dispatcher.queue.enqueue("test")
    mock(dispatcher).sleep.never
    dispatcher.consume
    assert_equal "test", dispatcher.message
  end
  
  def test_prepare
    dispatcher.instance_variable_set("@message", [nil, task_class, 1, 2, 3])
    task = dispatcher.prepare
    assert_equal task_class, task.task_class
    assert_equal [1, 2, 3], task.args
  end
  
  def test_dispatch
    dispatcher.instance_variable_set("@message", [nil, task_class, "fd18a"])
    mock(dispatcher.storm).execute(anything)
    dispatcher.dispatch
  end
  
end
