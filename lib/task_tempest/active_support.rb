class Object #:nodoc:
  
  unless method_defined?(:singleton_class)
    def singleton_class
      class << self; self; end
    end
  end
  
end

module TaskTempest
  module Memoizer
    
    def memoize(method_name)
      
      class_eval do
        define_method(:call_memoized_method) do |method_name, *args|
          @memoized_methods ||= {}
          hash = Digest::MD5.hexdigest(args.collect{ |arg| arg.hash }.join)
          key = "#{method_name}_#{hash}"
          if @memoized_methods.has_key?(key)
            @memoized_methods[key]
          else
            @memoized_methods[key] = send("#{method_name}_without_memoization", *args)
          end
        end unless method_defined?(:call_memoized_method)
      end
      
      class_eval <<-code
        def #{method_name}_with_memoization(*args)
          call_memoized_method(:#{method_name}, *args)
        end
        alias_method :#{method_name}_without_memoization, :#{method_name}
        alias_method :#{method_name}, :#{method_name}_with_memoization
      code
    end
    
  end
end