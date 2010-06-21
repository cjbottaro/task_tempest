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