require "spec_helper"

task_class = Class.new do
  extend TaskTempest::Task

  configure_task do
    timeout 0.05

    after_success proc {
      if @success
        task_logger.info "success"
      else
        raise "callback oops"
      end
    }

    after_failure proc { |e|
      task_logger.warn "failure #{e.class}"
    }

    after_timeout proc {
      task_logger.info "timeout"
    }
  end

  def process(n)
    case n
    when 0
      @success = true
    when 1
      sleep
    when 2
      raise "oops"
    end
  end

end

logger = Logger.new("/dev/null")

describe TaskTempest::TaskFacade do
  context "when initialized with a task class" do
    context "and #process is called" do
      it "it should honor timeouts" do
        @facade = described_class.new(task_class, [1], :logger => logger)
        mock(@facade.logger).info("timeout")
        @facade.process
        @facade.status.should == "timeout"
      end
      it "it should handle failures" do
        @facade = described_class.new(task_class, [2], :logger => logger)
        mock(@facade.logger).warn("failure RuntimeError")
        mock(@facade.logger).error(/RuntimeError: oops/)
        @facade.process
        @facade.status.should == "failure"
      end
      it "it should handle successes" do
        @facade = described_class.new(task_class, [0], :logger => logger)
        mock(@facade.logger).info("success")
        @facade.process
        @facade.status.should == "success"
      end
      it "it should handle exceptions in callbacks" do
        @facade = described_class.new(task_class, [-1], :logger => logger)
        mock(@facade.logger).error(/RuntimeError: callback oops/)
        @facade.process
        @facade.callback_status.should == "failure"
        @facade.status.should == "success"
      end
    end
  end
end
