require "thread"

require "task_tempest/error_handling"

module TaskTempest
  class Producer
    attr_reader :logger
    
    DEFAULTS = {
      :delay => 1,
      :buffer_size => 1
    }
    
    def initialize(queue, logger, options = {})
      options = DEFAULTS.merge(options)
      @queue = queue
      @logger = logger
      @delay = options[:delay]
      @buffer = SizedQueue.new(options[:buffer_size])
      Thread.new{ run }
    end
    
    def consume
      if @buffer.size > 0
        @buffer.pop
      else
        nil
      end
    end
  
  private
  
    def run
      run_loop while true
    end
    
    def run_loop
      (dequeue and buffer) or delay
    end
    
    def dequeue
      @message = @queue.dequeue
    rescue Exception => e
      @message = e
      nil
    end
    
    def buffer
      @buffer.push(@message)
    end
    
    def delay
      logger.debug "producer sleeping (queue empty) for #{@delay.inspect}"
      sleep(@delay)
    end
    
  end
end