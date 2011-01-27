module TaskTempest
  module Synchronizer #:nodoc:
    
    I = '([_a-zA-Z0-9]+)'
    P = '([\!\?]?)'
    
    def synchronize(*method_names)
      method_names.each do |method_name|
        class_eval <<-code
          def #{base_name}_with_synchronization#{punc}(*args)
          end
        code
        base_name, punc = method_name.match(/#{I}#{P}/)[1..-1]
        
      end
    end
    
  end
end