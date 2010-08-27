class Evaler < TaskTempest::Task
  timeout 2
  
  def start(code)
    eval(code)
  end
  
end