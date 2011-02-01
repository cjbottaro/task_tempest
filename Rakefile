require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "task_tempest"
    gem.summary = %Q{Framework for creating threaded asychronous job processors.}
    gem.description = %Q{Just another background job processor for Ruby.}
    gem.email = "cjbottaro@alumni.cs.utexas.edu"
    gem.homepage = "http://github.com/cjbottaro/task_tempest"
    gem.authors = ["Christopher J. Bottaro"]
    gem.add_dependency 'col', "~> 1.0"
    gem.add_dependency 'configuration_dsl', "~> 0.1"
    gem.add_dependency 'thread_storm', "~> 0.7"
    # gem.add_development_dependency "thoughtbot-shoulda", ">= 0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

require 'rcov/rcovtask'
Rcov::RcovTask.new do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "task_tempest #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

namespace :example do
  
  desc "Run the example."
  task :run do
    `ruby example/my_tempest.rb run`
  end
  
  desc "Fill the example queue."
  task :fill do
    require "example/my_tempest"
    while true
      r = rand
      sleep(r)
      MyTempest.submit([nil, "FibCalc", 25 + rand(8)])
    end
  end
  
end
