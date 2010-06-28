class Evaler < TaskTempest::Task
  
  def start(code)
    eval(code)
  end
  
end