module TaskTempest #:nodoc:
  
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
    
    DEFAULTS = {
      
      # General
      :name => Proc.new{ self.name },
      :root => Proc.new{ Dir.pwd },
      :threads => 10,
      
      # Timeouts.
      :timeout_method => ThreadStorm::DEFAULTS[:timeout_method],
      :timeout_exception => ThreadStorm::DEFAULTS[:timeout_exception],
      :shutdown_timeout => nil,
      
      # Logging.
      :log_file => Proc.new{ "#{conf.name}.log" },
      :log_format => TaskTempest::LOG_FORMAT,
      :log_level => Logger::INFO,
      :task_log_file => Proc.new{ "#{conf.name}.task.log" },
      :task_log_format => TaskTempest::LOG_FORMAT,
      :task_log_level => Logger::INFO,
      
      # Queue
      :queue                => Proc.new{ nil },
      :queue_poll_interval  => 1,
      
      # Callbacks.
      :before_initialize => [],
      :after_initialize => [],
      :after_exception => [],
      
      # Reporting.
      :report_interval => 10*60, # 10 mins.
      :report_callback => nil,
      
      # Internal.
      :pulse_delay => 0.25,
      :recursive_mutex_hack => true
    } #:nodoc:
    
    PROCS = [
      :timeout_method,
      :log_format,
      :task_log_format,
      :before_initialize,
      :after_initialize,
      :after_exception,
      :report_callback
    ] #:nodoc:
    
    ###########
    # General #
    ###########
    
    # The name of the tempest, used to set the log file names if none are given.
    # Defaults to the name the tempest class.
    # Accepts a block for lazy evaluation.
    def name(name = nil, &block)
      configuration.name = name || block
    end
    
    # The root directory, used to set the log file path if relative log files are given.
    # Defaults to Dir.pwd.
    # Accepts a block for lazy evaulation.
    def root(path = nil, &block)
      configuration.root_dir = path || block
    end
    
    # How many worker threads to spawn. Effectively how many tasks can be run concurrently.
    # Defaults to 10.
    # Accepts a block for lazy evaluation.
    def threads(count = nil, &block)
      configuration.threads = count || block
    end
    
    ############
    # Timeouts #
    ############
    
    # What timeout method to use.
    # Defaults to Timeout.method(:timeout).
    # If a block is used to define the timeout method, its signature must match Timeout.timeout.
    # You normally don't need to mess with this.
    def timeout_method(method = nil, &block)
      configuration.timeout_method = method || block
    end
    
    # What timeout exception to use with the timeout method.
    # Defaults to Timeout::Error.
    # If a custom timeout_method uses a custom timeout exception, it needs to be specified here.
    # You normally don't need to mess with this.
    def timeout_exception(klass = nil, &block)
      configuration.timeout_exception = klass || block
    end
    
    # How long to wait for running tasks to finish before shutting down.
    # Defaults to nil (no timeout).
    # Accepts a block for lazy evaluation.
    def shutdown_timeout(seconds = nil, &block)
      configuration.shutdown_timeout = seconds || block
    end
    
    ###########
    # Logging #
    ###########
    
    # Main log file path.
    # Defaults to TempestClass.log in the current working directory.
    # If a relative path is given, then it is appended to +root+.
    # Accepts a block for lazy evaluation.
    def log_file(path = nil, &block)
      configuration.log_file = path || block
    end
    
    # call-seq:
    #   log_format{ |severity, time, progname, message| ... }
    #
    # Specify what log messages should look like in the main log.
    # Defaults to something sane.
    def log_format(&formatter)
      configuration.log_format = formatter
    end
    
    # Main log level (see Logger in Ruby's standard libarary).
    # Defaults to Logger::INFO.
    # Accepts a block for lazy evaluation.
    def log_level(level = nil, &block)
      configuration.log_level = level || block
    end
    
    # Task log file path.
    # Defaults to TempestClass.task.log in the current working directory.
    # If a relative path is given, then it is appended to +root+.
    # Accepts a block for lazy evaluation.
    def task_log_file(path = nil, &block)
      configuration.task_log_file = path || block
    end
    
    # call-seq:
    #   log_format{ |severity, time, progname, message| ... }
    #
    # Specify what log messages should look like in the task log.
    # Defaults to something sane.
    def task_log_format(&formatter)
      configuration.task_log_format = formatter
    end
    
    # Task log level (see Logger in Ruby's standard libarary).
    # Defaults to Logger::INFO.
    # Accepts a block for lazy evaluation.
    def task_log_level(level = nil, &block)
      configuration.task_log_level = level || block
    end
    
    #########
    # Queue #
    #########
    
    # Specify the queue instance to use.
    # Defaults to nothing.
    # Accepts a block for lazy evaluation.
    def queue(queue = nil, &block)
      configuration.queue = queue || block
    end
    
    # How long to sleep for if no messages are in the queue.
    # Defaults to 1.
    # Accepts a block for lazy evaluation.
    def queue_poll_interval(seconds = nil, &block)
      configuration.queue_poll_interval = seconds || block
    end
    
    #############
    # Callbacks #
    #############
    
    # call-seq:
    #   before_initialize{ ... }
    #
    # Define a block to be called before the tempest has bootstrapped.
    # Multiple blocks can be defined by calling this more than once.
    def before_initialize(&block)
      configuration.before_initialize << block
    end
    
    # call-seq:
    #   after_initialize{ |logger| ... }
    #
    # Define a block to be called after the tempest has bootstrapped but before it starts processing tasks.
    # Multiple blocks can be defined by calling this more than once.
    def after_initialize(&block)
      configuration.after_initialize << block
    end
    
    # call-seq:
    #   after_exception{ |e, logger| ... }
    #
    # Define a block to be called after an unexpected exception has been caught.
    # Multiple blocks can be defined by calling this more than once.
    def after_exception(&block)
      configuration.after_exception << block
    end
    
    #############
    # Reporting #
    #############
    
    # call-seq:
    #   report{ |stats, logger| ... }
    #   report(:every => n)
    #   report(:every => n){ |stats, logger| ... }
    #
    # Define a reporting callback and how often it should run.
    # The callback will be given a stats hash containing information about the running tempest.
    # The stats hash is logged to the main log every +n+ seconds, regardless if any callback is defined
    # (that is why you can call this method without a block).
    # +n+ defaults to 5*60 (5 mintues).
    def report(options = {}, &block)
      configuration.report_interval = options[:every] || DEFAULTS[:report_interval]
      configuration.report_callback = block_given? ? block : DEFAULTS[:report_callback]
    end
    
    ############
    # Internal #
    ############
    
    def pulse_delay(seconds = nil, &block) #:nodoc:
      configuration.pulse_delay = seconds || block
    end
    
    # There is a bug in Ruby 1.9 involving Mutex and Timeout.  This setting works around the
    # bug by making Mutex recursively lockable.
    # Defaults to true (hack enabled).
    # Accepts a block for lazy evaluation.
    #
    # For more information, see {this blog post}[http://blog.stochasticbytes.com/2011/01/rubys-threaderror-deadlock-recursive-locking-bug/].
    def recursive_mutex_hack(enabled = true, &block)
      configuration.recursive_mutex_hack = block_given? ? block : enabled
    end
    
  end
end