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
        logger.info "[STATS] " + make_book.inspect
        @executions.clear
        @timer = Time.now
      end
    end
    
    def make_book
      
      # Do some setup.
      ObjectSpace.garbage_collect
      queue = @queue_factory.call
      book = {}
      
      # Reset memoized objects.
      @memory = nil
      @files = nil
      
      # Task success/error counts.
      book[:tasks] = {}
      book[:tasks][:counts] = task_counts
      book[:tasks][:per_thread] = tasks_per_thread
      book[:tasks][:durations] = task_durations
      book[:tasks][:throughput] = task_throughput
      
      # Thread (worker) info.
      book[:threads] = {}
      book[:threads][:busy] = @storm.executions.inject(0){ |memo, e| memo += 1 if e.started?; memo }
      book[:threads][:idle] = @storm.options[:size] - book[:threads][:busy]
      book[:threads][:saturation] = (book[:threads][:busy] / @storm.options[:size].to_f * 100).round(2)
      
      # Memory, Object, GC info.
      book[:memory] = {}
      book[:memory][:live_objects] = ObjectSpace.live_objects rescue "n/a"
      book[:memory][:resident] = format_memory(get_memory(:resident))
      book[:memory][:virtual] = format_memory(get_memory(:virtual))
      
      # Open file counts.
      book[:files] = {}
      book[:files][:total_count] = get_files(:total)
      book[:files][:tcp_count] = get_files(:tcp)
      
      # Queue info.
      book[:queue] = {}
      book[:queue][:size] = queue.size if queue.respond_to?(:size)
      book[:queue][:backlog] = @storm.executions.inject(0){ |memo, e| memo += 1 if e.queued?; memo }
      
      book
    end
    
    def task_counts
      tot = @executions.length
      err = @executions.sum{ |e| e.exception ? 1 : 0 }
      pct = begin
        if tot > 0
          (err.to_f / tot)
        else
          0.0
        end
      end
      { :tot => tot, :err => err, :pct => pct.round(3) }
    end
    
    def task_throughput
      duration = Time.now - @timer
      per_sec = @executions.length.to_f / duration
      per_min = (per_sec * 60).round(2)
      "#{per_min}/m"
    end
    
    def tasks_per_thread
      counts_by_thread = @storm.threads.inject({}) do |memo, thread|
        memo[thread] = 0
        memo
      end
      @executions.each{ |e| counts_by_thread[e.thread] += 1 }
      counts = counts_by_thread.values
      { :min => counts.min, :max => counts.max, :avg => counts.avg.round(2) }
    end
    
    def task_durations
      durations = @executions.collect{ |execution| execution.duration }
      if durations.length > 0
        { :min => durations.min.round(3), :max => durations.max.round(3), :avg => durations.avg.round(3) }
      else
        "n/a"
      end
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
    
    KB = 1024
    MB = KB**2
    def format_memory(memory)
      if memory > MB
        (memory / MB).to_s + "M"
      else
        (memory / KB).to_s + "K"
      end
    end
    
  end
end