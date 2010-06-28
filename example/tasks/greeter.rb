class Greeter < TaskTempest::Task
  
  def start(person, greeting)
    logger.info "#{person} has been greeted"
    puts "#{greeting}, #{person}!"
  end
  
end