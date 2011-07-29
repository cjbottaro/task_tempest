require "task_tempest/error_handling"
require "task_tempest/helpers"

module TaskTempest #:nodoc:
  class Reporter #:nodoc:
    attr_reader :raw, :options
    
    include Helpers
    
    KB = 1024
    MB = KB**2
    
    def initialize(raw, options = {})
      @raw = raw # Raw stats.
      @options = { :last_report_time => Time.now }.merge(options)
    end
    
    def memory
      memory = { :resident => "n/a", :virtual => "n/a" }
      
      output = `ps -o rss= -o vsz= -p #{Process.pid}` rescue ""
      return memory if output.empty?
      
      resident, virtual = output.split.collect{ |s| s.strip.to_i * KB }
      
      resident /= MB
      resident = "#{resident}M"
      
      virtual /= MB
      virtual = "#{virtual}M"
      
      memory.tap do |memory|
        memory[:resident] = resident
        memory[:virtual] = virtual
      end
    end
    
    def files
      files = { :total => "n/a", :tcp => "n/a" }
      
      output = `lsof -p #{Process.pid}`
      return files if output.empty?
      
      lines = output.split("\n")
      total = lines.length
      tcp = lines.inject(0){ |memo, line| memo += 1 if line.downcase =~ /tcp/; memo }
      
      files.tap do |files|
        files[:total] = total
        files[:tcp] = tcp
      end
    end
    
    def threads
      "%d/%d/%s" % [raw[:primatives].values.min, raw[:primatives].values.max, round(avg(raw[:primatives].values))]
    end
    
    def throughput
      elapsed = Time.now - options[:last_report_time]
      success = round(raw[:success].length.to_f / elapsed * 60)
      failure = round(raw[:failure].length.to_f / elapsed * 60)
      timeout = round(raw[:timeout].length.to_f / elapsed * 60)
      [ "#{success}/m", "#{failure}/m", "#{timeout}/m" ]
    end
    
    def tasks
      [ raw[:success].length, raw[:failure].length, raw[:timeout].length ]
    end
    
    def durations
      success = "%s/%s/%s" % [round(raw[:success].min || 0), round(raw[:success].max || 0), round(avg(raw[:success]))]
      failure = "%s/%s/%s" % [round(raw[:failure].min || 0), round(raw[:failure].max || 0), round(avg(raw[:failure]))]
      timeout = "%s/%s/%s" % [round(raw[:timeout].min || 0), round(raw[:timeout].max || 0), round(avg(raw[:timeout]))]
      [success, failure, timeout]
    end
    
  end
end
