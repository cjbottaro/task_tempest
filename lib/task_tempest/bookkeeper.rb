module TaskTempest
  class Bookkeeper
    attr_reader :logger
    
    def initialize(options)
      options.each{ |k, v| instance_variable_set("@#{k}", v) }
    end
    
    def report(executions)
      @timer      ||= Time.now
      @executions ||= []
      @executions += executions
      
      if Time.now - @timer > @interval
        logger.info "[STATS] " + book.inspect
        @executions.clear
        @timer = Time.now
      end
    end
    
    def book
      book = {}
      ObjectSpace.garbage_collect
      
      # Task success/error counts.
      book[:tasks] = {}
      book[:tasks][:total_count] = @executions.length
      book[:tasks][:error_count] = @executions.inject(0){ |memo, e| memo += 1 if e.exception; memo }
      book[:tasks][:error_percentage] = begin
        if book[:tasks][:total_count] > 0
          book[:tasks][:error_count].to_f / book[:tasks][:total_count] * 100.0
        else
          0.0
        end
      end
      book[:tasks][:per_thread] = tasks_per_thread(@storm.threads, @executions).values
      book[:tasks][:avg_duration] = @executions.inject(0){ |memo, e| memo += e.duration; memo }.to_f / @executions.length
      
      # Thread (worker) info.
      book[:threads] = {}
      book[:threads][:busy] = @storm.busy_workers.length
      book[:threads][:idle] = @storm.size - book[:threads][:busy]
      book[:threads][:saturation] = book[:threads][:busy] / @storm.size.to_f * 100
      
      # Memory, Object, GC info.
      book[:memory] = {}
      book[:memory][:live_objects] = ObjectSpace.live_objects rescue nil
      book[:memory][:resident] = get_memory(:resident)
      book[:memory][:virtual] = get_memory(:virtual)
      
      # Open file counts.
      book[:files] = {}
      book[:files][:total_count] = get_files(:total)
      book[:files][:tcp_count] = get_files(:tcp)
      
      # Queue info.
      book[:queue] = {}
      book[:queue][:size] = @queue.size if @queue.respond_to?(:size)
      book[:queue][:backlog] = @storm.executions.inject(0){ |memo, e| memo += 1 unless e.started?; memo }
      
      book
    end
    
    # executions passed in are *finished*.
    def tasks_per_thread(threads, executions)
      counts_by_thread = threads.inject({}) do |memo, thread|
        memo[thread] = 0
        memo
      end
      executions.each do |e|
        counts_by_thread[e.thread] += 1
      end
      counts_by_thread
    end
    
    def get_memory(which)
      @memory ||= `ps -o rss= -o vsz= -p #{Process.pid}`.split.collect{ |s| s.strip } rescue [nil, nil]
      case which
      when :resident
        @memory[0].to_i
      when :virtual
        @memory[1].to_i
      end
    end
    
    def get_files(which)
      @files ||= begin
        output = `lsof -p #{Process.pid}` rescue ""
        output.split("\n")
      end
      case which
      when :total
        @files.length
      when :tcp
        @files.inject(0){ |memo, line| memo += 1 if line.downcase =~ /tcp/; memo }
      end
    end
    
  end
end