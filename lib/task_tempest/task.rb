require "digest"
require "logger"

require "task_tempest/configuration_dsl"
require "task_tempest/error_handling"
require "task_tempest/helpers"
require "task_tempest/task/configuration"
require "task_tempest/task/reporting"

module TaskTempest #:nodoc:
  
  # A task represents a unit of work to be done by TaskTempest.
  #   class Adder < TaskTempest::Task
  #     configure do
  #       ...
  #     end
  #     def start(a, b)
  #       c = a + b
  #       logger.info "#{a} + #{b} = #{c}"
  #     end
  #   end
  # See Task::Configuration for what to put in the +configure+ block.
  # 
  # You can easily test your task in a console (the task's logger will log to STDOUT when run outside of a tempest).
  #   adder = Adder.new(1, 2)
  #   adder.run
  class Task
    
    # The task's unique id (as seen in the logs).
    attr_reader :id
    
    # The arguments passed in to #new.
    attr_reader :args
    
    attr_accessor :execution #:nodoc:
    
    extend ErrorHandling
    extend Helpers
    include ConfigurationDsl
    include Reporting
    include ErrorHandling
    
    configure_with(Configuration) do
      initialize_class
    end
    
    def self.inherited(mod) #:nodoc:
      mod.instance_variable_set("@configuration", copy_struct(configuration))
      mod.initialize_class
    end
    
    def self.initialize_class
      @conf = ConfigurationDsl::Actualizer.new(self, configuration, Task::Configuration::PROCS)
      @book = Book.new(&conf.report_stats)
      @last_report_time = Time.now
    end
    
    # The task's configuration as a struct-like object.
    def self.conf
      @conf
    end
    
    def self.book #:nodoc:
      @book
    end
    
    def self.instantiate(id, logger, *args) #:nodoc:
      new(*args).tap do |task|
        task.instance_eval do
          @logger = logger
          @id = id if id
        end
      end
    end
    
    # Create a new task with the given arguments.
    def initialize(*args)
      @id = generate_id
      @args = args
    end
    
    # Alias for +self.class.conf+
    def conf
      self.class.conf
    end
    
    # Run the task (i.e. call #start with the args passed into #new).
    def run
      start(*args)
    end
    
    # Override this method to define what this task should do.
    def start(*args)
      raise "not implemented"
    end
    
    def to_message #:nodoc:
      [id, self.class.name, *args]
    end
    
    def format_log(message) #:nodoc:
      "{#{id}} <#{self.class}> #{message}"
    end
    
    # Returns the Logger object.
    def logger
      @logger ||= Logger.new(STDOUT)
      self
    end
    
    %w[debug info warn error fatal].each do |level|
      class_eval <<-STR
        def #{level}(message)
          @logger.#{level} format_log(message)
        end
      STR
    end
    
    def callback(which) #:nodoc:
      case which.to_sym
      when :success
        conf.after_success.call(self)
      when :failure
        conf.after_failure.call(self, execution.exception)
      when :timeout
        conf.after_timeout.call(self, execution.exception)
      end
    rescue StandardError => e
      logger.error format_exception(e)
      false
    else
      true
    end
    
    # call-seq:
    #   record{ |stats| ... }
    #
    # Synchronizes access to the stats defined by Task::Configuration.report_stats.
    def record(&block)
      self.class.record(&block)
    end
    
  private
    
    def generate_id
      Digest::SHA1.hexdigest(Time.now.to_s + rand.to_s)[0,5]
    end
    
  end
end