require "digest"
require "logger"

require "task_tempest/task_logger"
require "task_tempest/require"

module TaskTempest
  class Task
    attr_reader :id, :args
    attr_accessor :execution
    
    def self.settings
      @settings ||= {}
    end
      
    def self.timeout(value)
      settings[:timeout] = value
    end
    
    def initialize(*args)
      @id = generate_id
      @args = args
    end
    
    def init(options = {})
      @id = options[:id] if options[:id]
      @logger = TaskLogger.new(options[:logger], self) if options[:logger]
      self
    end
    
    def run
      # FIXME This doesn't really work with timeouts because
      # the lines after start() may or may not be called.
      Thread.current[:required_files] = []
      start(*args)
      required_files = Thread.current[:required_files]
      Thread.current[:required_files] = nil
      required_files
    end
    
    def start(*args)
      raise "not implemented"
    end
    
    def logger
      @logger ||= TaskLogger.new(Logger.new(STDOUT), self)
    end
    
    def to_message
      [id, self.class.name, *args]
    end
    
    def format_log(message, show_duration = false)
      s = "{#{id}} <#{self.class}> #{message}"
      s += " #{execution.duration.round(3)}" if show_duration and execution.finished?
      s
    end
    
  private
    
    def generate_id
      Digest::SHA1.hexdigest(Time.now.to_s + rand.to_s)[0,5]
    end
    
  end
end