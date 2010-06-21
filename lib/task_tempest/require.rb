require "set"

module Kernel
  alias_method :original_require, :require
  
  def require(file)
    without_ext = file.sub /(\.rb$)|(\.bundle$)/, ""
    files = %w[.rb .bundle].collect{ |ext| without_ext + ext }
    already_required = !($".to_set & files.to_set).empty?
    required_files = Thread.current[:required_files]
    required_files << file if required_files and not already_required
    original_require(file)
  end
  
  def self.record_requires!
    if Thread.current[:required_files] == nil
      Thread.current[:required_files] = []
      yield
      required_files = Thread.current[:required_files]
      Thread.current[:required_files] = nil
      required_files
    else # Reentrant case.
      yield
      Thread.current[:required_files]
    end
  end
end