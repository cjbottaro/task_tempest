module TaskTempest #:nodoc:
  class Task
    
    # Configuring a Task is done much the same way as configuring a TaskTempest::Engine, with a DSL.
    #   class CalculatePi < TaskTempest::Task
    #     configure do
    #       timeout 5
    #       report_stats do
    #         { :timeouts => 0 }
    #       end
    #       after_timeout do |task, exception|
    #         task.logger.error "I took too long and got this: #{exception} !"
    #         task.record{ |stats| stats[:timeouts] += 1 }
    #       end
    #       report :every => 120 do |stats, logger|
    #         logger.warn "#{stats[:timeouts]} CalculatePi tasks have timed out in the past 120 seconds."
    #       end
    #     end
    #     ...
    #   end
    module Configuration
      
      DEFAULTS = {
        :timeout => nil, # No timeout.
        
        # Reporting.
        :report_stats => Proc.new{ Hash.new{ |h, k| h[k] = Hash.new(&h.default_proc) } },
        :report_interval => 60,
        :report_callback => nil,
        
        # Callbacks.
        :after_success => Proc.new{ |task| nil },
        :after_failure => Proc.new{ |task, e| nil },
        :after_timeout => Proc.new{ |task, e| nil }
      } #:nodoc:
      
      # These are options whose values should *not* lazily evaluated.
      PROCS = [
        :report_stats,
        :report_callback,
        :after_success,
        :after_failure,
        :after_timeout
      ] #:nodoc:
      
      # Maximum amount of time a task should be a allowed to run before it is abored.
      # Defaults to nil (no timeout), but I highly recommend you change that.
      def timeout(seconds)
        configuration.timeout = seconds
      end
      
      # call-seq:
      #   report_stats{ ... }
      # 
      # The block should return the initial value of the stats object that will be given to
      # Task#record and the task's report callback.
      def report_stats(&block)
        configuration.report_stats = block
      end
      
      # call-seq:
      #   report(:every => n){ |stats, logger| ... }
      # 
      # Define a reporting callback and how often it should be called.  The callback will be
      # given the stats object (as defined by #report_stats) and the main logger (not the
      # task logger).  The callback will be called every +n+ seconds.  Note the callback is
      # evaluated in the scope of the task class.
      def report(options = {}, &block)
        configuration.report_interval = options[:every] || DEFAULTS[:report_interval]
        configuration.report_callback = block_given? ? block : DEFAULTS[:report_callback]
      end
      
      # call-seq:
      #   after_success{ |task| ... }
      # 
      # Define a callback to be called after a task finishes successfully.
      def after_success(&block)
        configuration.after_success = block
      end
      
      # call-seq:
      #   after_failure{ |task, exception| ... }
      # 
      # Define a callback to be called after a task fails (i.e. uncaught exception).
      def after_failure(&block)
        configuration.after_failure = block
      end
      
      # call-seq:
      #   after_timeout{ |task, exception| ... }
      # 
      # Define a callback to be called after a task times out.  +exception+ is the timeout exception.
      def after_timeout(&block)
        configuration.after_timeout = block
      end
      
    end
  end
end