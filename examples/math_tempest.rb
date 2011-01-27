require "task_tempest"

class MemoryQueue < Array
  alias_method :dequeue, :pop
  alias_method :enqueue, :unshift
end

class MathTempest < TaskTempest::Engine
  configure do
    threads 2
    queue MemoryQueue.new
    report :every => 10
  end
end

class Adder < TaskTempest::Task
  def start(a, b)
    c = a + b
    logger.info "#{a} + #{b} = #{c}"
  end
end

class Averager < TaskTempest::Task
  def start(*args)
    raise ArgumentError, "divide by zero" if args.length == 0
    sum = args.inject(0){ |memo, n| memo += n; memo }.to_f
    avg = sum / args.length
    logger.info "avg(%s) = %s" % [args.join(", "), avg]
  end
end

class Fibonacci < TaskTempest::Task
  configure{ timeout 1 }
  def start(n)
    a = Array.new(n)
    a.each_with_index do |_, i|
      if i == 0
        a[i] = 0
      elsif i == 1
        a[i] = 1
      else
        a[i] = a[i-1] + a[i-2]
      end
    end
    fib = a[-1] + a[-2]
    logger.info "fib(#{n}) has %s digits" % fib.to_s.length
  end
end

1000.times do
  case rand(3)
  when 0
    task = Adder.new(rand(10), rand(10))
  when 1
    task = Averager.new( *(rand(10).times.collect{ rand(10) }) )
  when 2
    task = Fibonacci.new(rand(100_000))
  end
  MathTempest.submit(task)
end

MathTempest.run