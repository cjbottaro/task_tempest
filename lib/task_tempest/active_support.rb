class Object #:nodoc:
  def singleton_class
    class << self; self; end
  end unless method_defined?(:singleton_class)
  
  def tap
    yield self
    self
  end unless method_defined?(:tap)
end