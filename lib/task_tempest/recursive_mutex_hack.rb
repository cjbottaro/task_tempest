require "thread"

class Mutex #:nodoc:
  def lock_with_hack
    lock_without_hack
  rescue ThreadError => e
    if e.message != "deadlock; recursive locking"
      raise
    else
      unlock
      lock_without_hack
    end
  end
  alias_method :lock_without_hack, :lock
  alias_method :lock, :lock_with_hack
end