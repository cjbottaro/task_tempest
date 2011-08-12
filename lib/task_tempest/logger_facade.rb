module TaskTempest
  class LoggerFacade
    def initialize(id, mod, logger)
      @id     = id
      @name   = mod.name
      @logger = logger
    end

    def log(level, message)
      @logger.send(level, "{%s} <%s> %s" % [@id, @name, message])
    end

    %w[debug info warn error fatal].each do |method|
      class_eval <<-CODE
        def #{method}(message)
          log(:#{method}, message)
        end
      CODE
    end

  end
end
