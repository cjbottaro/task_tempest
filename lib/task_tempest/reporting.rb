require "task_tempest/reporter"

module TaskTempest #:nodoc:
  module Reporting #:nodoc:
    
    def should_report?
      Time.now - @last_report_time >= conf.report_interval
    end
    
    def report_to_log
      raw = book.reset # Raw stats.
      reporter = Reporter.new(raw, :last_report_time => @last_report_time)
      stats = {
        :memory     => reporter.memory,
        :files      => reporter.files,
        :threads    => reporter.threads,
        :throughput => reporter.throughput,
        :durations  => reporter.durations,
        :tasks      => reporter.tasks,
        :queue_size => (conf.queue.size rescue nil)
      }
      logger.info "{-----} <#{self.class}> stats " + stats.inspect
      
      # Do the reporting callback if any.
      if conf.report_callback
        logger.debug "executing report callback"
        begin
          instance_exec(stats, &conf.report_callback)
        rescue StandardError => e
          logger.error "{-----} <#{self.class}> report %s\n" % Col("failure").red.to_s + format_exception(e)
        end
      end
      
      @last_report_time = Time.now
    end
    
    def task_reporting
      @task_classes.each do |task_class|
        task_class.report_to_log(logger, task_logger) if task_class.should_report?
      end
    end
    
    def record(&block)
      book.record(&block)
    end
    
    def report(&block)
      book.report(&block)
    end
    
  end
end