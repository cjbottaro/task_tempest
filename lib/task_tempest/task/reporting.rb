require "task_tempest/book"

module TaskTempest #:nodoc:
  class Task
    module Reporting #:nodoc:all
      
      def self.included(mod)
        mod.send(:extend,  ClassMethods)
        mod.send(:include, InstanceMethods)
      end
      
      module ClassMethods
        
        def should_report?
          Time.now - @last_report_time >= conf.report_interval and conf.report_callback
        end
        
        def report_to_log(logger, task_logger)
          stats = book.reset
          begin
            instance_exec(stats, logger, &conf.report_callback)
          rescue StandardError => e
            logger.error "{-----} <#{self}> report %s" % Col("failure").red.to_s
            task_logger.error "{-----} <#{self}> " + format_exception(e)
          ensure
            @last_report_time = Time.now
          end
        end
        
        def record(&block)
          book.record(&block)
        end
        
      end
      
      module InstanceMethods
      end
      
    end
  end
end