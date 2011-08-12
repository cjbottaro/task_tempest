module TaskTempest
  module Memoizer #:nodoc:
    
    def memoize(method_name)
      original_name = "__memoize__#{method_name}"
      class_eval do
        alias_method original_name, method_name
        define_method(method_name) do |*args|
          @__memoize__ ||= {}
          key = "%s/%s" % [method_name, args.collect{ |arg| arg.hash }.join]
          if @__memoize__.has_key?(key)
            @__memoize__[key]
          else
            @__memoize__[key] = send(original_name, *args)
          end
        end
      end
    end
    
  end
end
