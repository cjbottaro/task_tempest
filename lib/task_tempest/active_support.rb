class Array
  def separate(&block)
    passed, failed = [], []
    each do |item|
      if block.call(item)
        passed << item
      else
        failed << item
      end
    end
    [passed, failed]
  end unless method_defined?(:separate)
  
  def sum(&block)
    if block_given?
      inject(0){ |memo, item| memo += yield(item); memo }
    else
      total = inject(0){ |memo, item| memo += item; memo }
    end
  end
  
  def avg(&block)
    sum(&block).to_f / length
  end
end

class Float
  unless method_defined?(:round_with_precision)
    def round_with_precision(precision = nil)
      precision.nil? ? round_without_precision : (self * (10 ** precision)).round / (10 ** precision).to_f
    end
    alias_method :round_without_precision, :round
    alias_method :round, :round_with_precision
  end
end

class Object
  def metaclass
    class << self; self; end
  end unless method_defined?(:metaclass)
  
  def tap
    yield self
    self
  end unless method_defined?(:tap)
end