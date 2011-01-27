require "set"

module TaskTempest #:nodoc:
  module ConfigurationDsl #:nodoc:all
    
    def self.included(mod)
      mod.send(:extend,  ClassMethods)
      mod.send(:include, InstanceMethods)
    end
    
    class Dsl
      attr_reader :configuration
      def initialize(configuration)
        @configuration = configuration
      end
    end
    
    class Actualizer
      attr_reader :configuration

      def initialize(object, configuration, exemptions = [])
        @object = object
        @configuration = configuration
        @exemptions = exemptions.to_set
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
        elsif @exemptions.include?(name)
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
    
    module ClassMethods
      
      def configure_with(configuration_module, &block)
        @configuration_module = configuration_module
        after_configure(&block) if block_given?
      end
      
      # Superclass delegating reader.
      def configuration_module
        if @configuration_module
          @configuration_module
        elsif superclass.respond_to?(:configuration_module)
          superclass.configuration_module
        else
          nil
        end
      end
      
      def after_configure(&block)
        if block_given?
          @after_configure = block
        elsif @after_configure
          @after_configure
        elsif superclass.respond_to?(:after_configure)
          superclass.after_configure
        else
          nil
        end
      end
      
      def configure(&block)
        dsl = Dsl.new(configuration)
        dsl.send(:extend, configuration_module)
        dsl.instance_eval(&block)
        
        # callback.call will run in the scope of where it was defined
        # (i.e. the superclass), thus we call instance_eval instead.
        callback = after_configure and instance_eval(&callback)
      end
      
      def configuration
        @configuration ||= begin
          defaults = configuration_module.const_get(:DEFAULTS) || {}
          Struct.new(*defaults.keys).new(*defaults.values)
        end
      end
      
    end
    
    module InstanceMethods
      
      def configuration
        self.class.configuration
      end
      
    end
    
  end
end