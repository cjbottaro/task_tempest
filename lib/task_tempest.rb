require "col"
require "timeout"

# This is just a namespace.  You probably want to look at the README.rdoc or TaskTempest::Engine.
module TaskTempest
  class Error < RuntimeError #:nodoc:
  end
  LOG_FORMAT = Proc.new do |severity, time, progname, message| #:nodoc:
    message = message.call if message.respond_to?(:call)
    time = time.strftime("%Y/%m/%d %H:%M:%S")
    severity = "%-7s" % "[#{severity}]"
    sprintf("%s %s %s\n", time, severity, message)
  end #:nodoc:
end

require "task_tempest/engine"
require "task_tempest/task"
