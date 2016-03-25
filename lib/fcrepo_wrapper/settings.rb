require 'delegate'
module FcrepoWrapper
  # Configuraton that comes from static and dynamic sources.
  class Settings < Delegator
    def __getobj__
      @static_config # return object we are delegating to, required
    end

    alias static_config __getobj__

    def __setobj__(obj)
      @static_config = obj
    end

    def initialize(static_config)
      super
      @static_config = static_config
    end

    ##
    # Get the port this fcrepo instance is running at
    def port
      @port ||= static_config.port
      @port ||= random_open_port.to_s
    end

    private

      def random_open_port
        socket = Socket.new(:INET, :STREAM, 0)
        begin
          socket.bind(Addrinfo.tcp('127.0.0.1', 0))
          socket.local_address.ip_port
        ensure
          socket.close
        end
      end
  end
end

