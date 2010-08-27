module Kernel
  
  class << self
    attr_accessor :require_callback
  end
  
  def require_with_callback(file)
    require_without_callback(file).tap do |required|
      Kernel.require_callback.call(file) if required and Kernel.require_callback
    end
  end
  
  alias_method :require_without_callback, :require
  alias_method :require, :require_with_callback
  
end