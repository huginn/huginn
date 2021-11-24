require 'net/protocol'

class Net::Protocol
  module ForceSNI
    def ssl_socket_connect(*)
      @sock.hostname = @host if @sock.respond_to? :hostname=
      super
    end
  end
  prepend ForceSNI
end
