require "task_tempest/active_support"
require "task_tempest/engine"
require "task_tempest/task"

module TaskTempest
  
  LogFormatter = Proc.new do |severity, time, progname, message|
    message = message.call if message.respond_to?(:call)
    time = time.strftime("%Y/%m/%d %H:%M:%S")
    sprintf("%s [%s] %s\n", time, severity, message)
  end
  
end