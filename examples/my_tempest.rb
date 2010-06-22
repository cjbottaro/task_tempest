require "rubygems"
require "task_tempest"
require "memcache"
require "system_timer"

require "tasks/greeter"

class MemcachedQueue
  
  def initialize(name)
    @name = name
    @cache = MemCache.new "localhost:11211"
  end
  
  def push(item)
    queue = @cache.fetch(@name){ [] }
    queue.push(item)
    @cache.set(@name, queue)
  end
  
  def pop
    queue = @cache.fetch(@name){ [] }
    item = queue.pop
    @cache.set(@name, queue)
    item
  end
  
end

# To run this example, open two shells and navagate to the examples directory (i.e. the
# the directory containing this file).  In the first shell type:
#   ruby my_tempest.rb run
# In the second shell, invoke irb and type the following commands:
#   require "my_tempest"
#   MyTempest.submit(Greeter.new("Christopher", "Hello"))
#   MyTempest.submit([nil, "Greeter", "Justin", "What up"])
# Check the the first shell (and the logs dir) for output.
# Note this example requires the SystemTimer, daemons and memcache-client gems.
class MyTempest < TaskTempest::Engine
  
  # This dictates what the logs will be named.
  process_name "my_tempest"
  
  # How many threads.
  threads 5
  
  # Where to write the log files.
  log_dir "log"
  
  # Where to look for task classes.  Will require each .rb file in this directory.
  task_dir "tasks"
  
  # Time in seconds between each bookkeeping event.
  bookkeeping_interval 15
  
  # Don't display log messages below this level.
  log_level Logger::INFO
  
  # Maximum time in seconds a task is allowed to take before it is aborted.
  task_timeout 5
  
  # What timeout method to use.  Timeout.timeout is unreliable.
  timeout_method SystemTimer.method(:timeout_after)
  
  # Define the queue.
  queue do |logger|
    MemcachedQueue.new("my_tempest_queue")
  end
  
  # Define how to enqueue messages.  This is used by MyTempest.submit.
  # message is a tuple [task_id, task_class_name, *task_arguments].
  # *args are passed through from MyTempest.submit.
  enqueue do |queue, message, logger, *args|
    logger.debug "enqueue #{message.inspect}"
    queue.push(message)
  end
  
  # Define how to dequeue messages.  It must return either
  # nil or a tuple: [task_id, task_class_name, *task_arguments]
  dequeue do |queue, logger|
    if (message = queue.pop)
      logger.debug "dequeue #{message.inspect}"
      message
    else
      nil
    end
  end
  
  # Callback that happens after #init_logging, but before #bootstrap.
  before_initialize do |logger|
  end
  
  # Callback that happens after #bootstrap.
  after_initialize do |logger|
  end
  
  # Callback for an exception that happens in TaskTempest::Engine.
  on_internal_exception do |e, logger|
    puts "(I) #{e.class}: #{e.message}"
  end
  
  # Callback that happens when an exception occurs in a task.
  on_task_exception do |task, e, logger|
    puts "(T:#{task_id}) #{e.class}: #{e.message}"
  end
  
  # Callback that happens when a task exceeds the task_timeout setting.
  on_task_timeout do |task, logger|
    puts "(T:#{task.id}) timed out"
  end
  
  # Callback that happens when a task calls Kernel.require.
  on_require do |task, files, logger|
    puts ("(T:#{task.id}) required files")
  end
  
  # Callback that happens when bookkeeping is done.
  on_bookkeeping do |book, logger|
    if book[:files][:total_count] > 100
      puts "you have a lot of open files!"
    end
  end
  
end

if $0 == __FILE__
  require "daemons"
  Daemons.run_proc(MyTempest.settings.process_name, :log_output => true) do
    MyTempest.new.run
  end
end