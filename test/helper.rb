require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'test/unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'task_tempest'
require "rr"
require "timecop"

class Test::Unit::TestCase
  include RR::Adapters::TestUnit
  
  attr_reader :tempest_class, :task_class
  
  def setup
    @tempest_class = Class.new(TaskTempest::Engine)
    @tempest_class.configure do
      log_file{ Logger.new("/dev/null") }
      task_log_file{ Logger.new("/dev/null") }
      queue do
        block_returns(Class.new(Array) do
          alias_method :enqueue, :unshift
          alias_method :dequeue, :pop
        end.new)
      end
    end
    
    @task_class = Class.new.tap{ |c| c.extend(TaskTempest::Task) }
  end
  
end


