require "pathname"
require "set"

require "task_tempest/queue"

module TaskTempest
  
  class Configuration
    attr_reader :configuration, :object
    
    def initialize(configuration, object, options = {})
      @configuration = configuration
      @object = object
      
      # We have to normalize members because of Ruby version differences.
      members = configuration.members.collect{ |member| member.to_sym }
      
      if options[:literal]
        @literal = options[:literal]
      else
        @literal = members.to_set - options[:evaled].to_set
      end
    end
    
    def actualize_all
      
      hash = configuration.members.inject({}) do |memo, member|
        # We can't use #send here because it will try to call private methods.
        # This is a problem when trying to actualize the :timeout configuration
        # for tasks.  Also, instance_eval("#{member}") will try to call private
        # methods.  Hence why it is the way it is.
        memo[member.to_sym] = instance_eval("self.#{member}")
        memo
      end
      
      Struct.new(*hash.keys).new(*hash.values)
    end
    
    def log_file
      @log_file ||= begin
        log_file = actualize(configuration.log_file)
        log_file = "#{root}/#{log_file}" if log_file.kind_of?(String) and Pathname.new(log_file).relative?
        log_file
      end
    end
    
    def task_log_file
      @task_log_file ||= begin
        log_file = actualize(configuration.task_log_file)
        log_file = "#{root}/#{log_file}" if log_file.kind_of?(String) and Pathname.new(log_file).relative?
        log_file
      end
    end
    
    def queue
      @queue ||= TaskTempest::Queue.new(actualize(configuration.queue))
    end
    
  private
  
    def method_missing(name, *args, &block)
      
      # In 1.8 Struct#members returns an array of strings.
      # In 1.9, it returns an array of symbols.
      members = configuration.members.collect{ |member| member.to_sym }
      
      if members.include?(name)
        value_for(name)
      else
        super
      end
    end

    def value_for(name)
      ivar_name = "@#{name}"
      if instance_variable_defined?(ivar_name)
        instance_variable_get(ivar_name)
      elsif @literal.include?(name)
        value = configuration.send(name)
        instance_variable_set(ivar_name, value)
      else
        value = actualize(configuration.send(name))
        instance_variable_set(ivar_name, value)
      end
    end

    def actualize(value)
      if value.kind_of?(Proc)
        @object.instance_eval(&value)
      else
        value
      end
    end
    
  end
  
end