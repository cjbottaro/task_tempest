require "digest"
require "logger"

require "task_tempest/task_logger"
require "task_tempest/require"

module TaskTempest
  class Task
    attr_reader :id, :args, :execution
    
    def initialize(*args)
      @id = generate_id
      @args = args
    end
    
    def override(options = {})
      @id = options[:id] if options[:id]
      @logger = TaskLogger.new(options[:logger], self) if options[:logger]
    end
    
    def spawn(storm)
      @execution = storm.execute{ run }
    end
    
    def run
      Kernel.record_requires!{ start(*args) }
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
    
    def format_log(message, duration = false)
      s = "[#{id} #{self.class}] #{message}"
      s += " #{execution.duration}" if duration
      s
    end
    
  private
    
    def generate_id
      Digest::SHA1.hexdigest(Time.now.to_s + rand.to_s)[0,5]
    end
    
  end
end