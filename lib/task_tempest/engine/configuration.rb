module TaskTempest #:nodoc:
  
  class Engine
  
    # Configuration options are specified via a DSL.
    #   class MyTempest < TaskTempest::Engine
    #     configure do
    #       name "MyTempest"
    #       threads 10
    #       ...
    #     end
    #   end
    # Some configuration options take a block that is lazily evaluated (in the scope of the tempest class)
    # to determine the value of the option.
    #   class MyTempest < TaskTempest::Engine
    #     configure do
    #       name{ self.name }
    #       root{ Rails.root }
    #       before_initialize do
    #         require "config/environment" # load Rails
    #       end
    #     end
    #   end
    # Some configuration options take a block that _is_ the value of the option.
    #   class MyTempest < TaskTempest::Engine
    #     configure do
    #       log_Format do |severity, time, progname, message|
    #         time = time.strftime("%Y/%m/%d %H:%M:%S")
    #         sprintf("%s [%s] %s\n", time, severity, message)
    #       end
    #     end
    #   end
    module Configuration
    
      ###########
      # General #
      ###########
    
      # The name of the tempest.
      # Initially set to the tempest class name.
      def name(name)
        name.to_s
      end
    
      # The root directory, used to set the log file path if relative log files are given.
      # Initially set to Dir.pwd.
      def root(path)
        path
      end
    
      # How many worker threads to spawn. Effectively how many tasks can be run concurrently.
      def threads(count = 10)
        count
      end

      # How many worker fibers to spawn.  If this value is set, then fibers will be used
      # instead of threads and we're going to run in the EventMachine reactor.
      def fibers(count = nil)
        count
      end
    
      ############
      # Timeouts #
      ############
    
      # What timeout method to use (must be a Proc).
      # If not set, TaskTempest will try to pick something sane depending on what mode you're running in.
      # You normally don't need to mess with this.
      def timeout_method(method)
        method
      end
    
      # What timeout exception to use with the timeout method.
      # If a custom timeout_method uses a custom timeout exception, it needs to be specified here.
      # If not set, TaskTempest will try to pick something sane depending on what mode you're running in.
      # You normally don't need to mess with this.
      def timeout_exception(klass)
        klass
      end
    
      # How long to wait for running tasks to finish before shutting down.
      def shutdown_timeout(seconds = nil)
        seconds
      end
    
      ###########
      # Logging #
      ###########
    
      # Main log file path.
      # If a relative path is given, then it is appended to +root+.
      # If not specified, then TaskTempest will choose a name based on the tempest name.
      def log_file(path)
        path
      end
    
      # A Proc that determines what log messages should look like in the main log.
      # If not set, TaskTempest will use something sane.
      def log_format(formatter)
        formatter
      end
    
      # Main log level (see Logger in Ruby's standard library).
      def log_level(level = Logger::INFO)
        level
      end
    
      # Task log file path.
      # If a relative path is given, then it is appended to +root+.
      # If not set, TaskTempest will choose something based on the tempest's name.
      def task_log_file(path)
        path
      end
    
      # A Proc that determines what log messages should look like in the task log.
      # If not set, then something sane will be used.
      def task_log_format(formatter)
        formatter
      end
    
      # Task log level (see Logger in Ruby's standard libarary).
      def task_log_level(level = Logger::INFO)
        level
      end
    
      #########
      # Queue #
      #########
    
      # Specify the queue instance to use.
      def queue(queue)
        queue
      end
    
      # How long to sleep for if no messages are in the queue.
      def queue_poll_interval(seconds = 1)
        seconds
      end
    
      #############
      # Callbacks #
      #############
    
      # Add a callback to be called before the tempest has been initialized (bootstrapped).
      # The callback will be called with no arguments:
      #   proc{ ... }
      def before_initialize(callback = nil)
        @before_initialize_array ||= []
        @before_initialize_array << callback if callback
        @before_initialize_array
      end
    
      # Add a callback to be called after the tempest has been initialized (bootstrapped).
      # The callback will be given the logger:
      #   proc{ |logger| ... }
      def after_initialize(callback = nil)
        @after_initialize_array ||= []
        @after_initialize_array << callback if callback
        @after_initialize_array
      end

      # Add a callback to be called after a task has started.
      # The callback will be given the logger and the started task:
      #   proc{ |logger, task| ... }
      def after_task_started(callback = nil)
        @after_task_started ||= []
        @after_task_started << callback if callback
        @after_task_started
      end

      # Add a callback to be called after a task has finished.
      # The callback will be given the logger and the finished task:
      #   proc{ |logger, task| ... }
      def after_task_finished(callback = nil)
        @after_task_finished ||= []
        @after_task_finished << callback if callback
        @after_task_finished
      end
    
      ############
      # Internal #
      ############
    
      def pulse_delay(seconds = 0.25) #:nodoc:
        seconds
      end
    
      # There is a bug in Ruby 1.9 involving Mutex and Timeout.  This setting works around the
      # bug by making Mutex recursively lockable.
      #
      # For more information, see {this blog post}[http://blog.stochasticbytes.com/2011/01/rubys-threaderror-deadlock-recursive-locking-bug/].
      def recursive_mutex_hack(enabled = true)
        enabled
      end
    
    end
    
  end
end
