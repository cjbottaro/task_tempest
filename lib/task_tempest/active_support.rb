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
  
  def avg(&block)
    sum(&block).to_f / length
  end
end

module Enumerable
  def sum(identity = 0, &block)
    return identity unless size > 0

    if block_given?
      map(&block).sum
    else
      inject { |sum, element| sum + element }
    end
  end unless method_defined?(:sum)
end

class Float
  def round_with_task_tempest(precision = nil)
    precision.nil? ? round_without_task_tempest : (self * (10 ** precision)).round / (10 ** precision).to_f
  end
  alias_method :round_without_task_tempest, :round
  alias_method :round, :round_with_task_tempest
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