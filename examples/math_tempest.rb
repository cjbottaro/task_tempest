require "task_tempest"

class MemoryQueue < Array
  alias_method :dequeue, :pop
  alias_method :enqueue, :unshift
end

class MathTempest < TaskTempest::Engine
  configure do
    threads 2
    queue MemoryQueue.new
  end
end

class Adder
  extend TaskTempest::Task
  def process(a, b)
    c = a + b
    task_logger.info "#{a} + #{b} = #{c}"
  end
end

class Averager
  extend TaskTempest::Task
  def process(*args)
    raise ArgumentError, "divide by zero" if args.length == 0
    sum = args.inject(0){ |memo, n| memo += n; memo }.to_f
    avg = sum / args.length
    task_logger.info "avg(%s) = %s" % [args.join(", "), avg]
  end
end

class Fibonacci
  extend TaskTempest::Task
  configure_task{ timeout 1 }
  def process(n)
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
    task_logger.info "fib(#{n}) has %s digits" % fib.to_s.length
  end
end

1000.times do
  case rand(3)
  when 0
    task = MathTempest.submit(Adder, rand(10), rand(10))
  when 1
    task = MathTempest.submit(Averager, *(rand(10).times.collect{ rand(10) }))
  when 2
    task = MathTempest.submit(Fibonacci, rand(100_000))
  end
end

MathTempest.run
