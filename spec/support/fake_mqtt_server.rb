#!/usr/bin/env ruby
#
# This is a 'fake' MQTT server to help with testing client implementations
#
# See https://github.com/njh/ruby-mqtt/blob/master/spec/fake_server.rb
#
# It behaves in the following ways:
#   * Responses to CONNECT with a successful CONACK
#   * Responses to PUBLISH by echoing the packet back
#   * Responses to SUBSCRIBE with SUBACK and a PUBLISH to the topic
#   * Responses to PINGREQ with PINGRESP
#   * Responses to DISCONNECT by closing the socket
#
# It has the following restrictions
#   * Doesn't deal with timeouts
#   * Only handles a single connection at a time
#

$:.unshift File.dirname(__FILE__)+'/../lib'

require 'logger'
require 'socket'
require 'mqtt'


class MQTT::FakeServer
  attr_reader :address, :port
  attr_reader :last_publish
  attr_reader :thread
  attr_reader :pings_received
  attr_accessor :just_one
  attr_accessor :logger

  # Create a new fake MQTT server
  #
  # If no port is given, bind to a random port number
  # If no bind address is given, bind to localhost
  def initialize(bind_address='127.0.0.1')
    @address = bind_address
  end

  # Get the logger used by the server
  def logger
    @logger ||= Logger.new(STDOUT)
  end

  # Start the thread and open the socket that will process client connections
  def start
    @socket ||= TCPServer.new(@address, 0)
    @address = @socket.addr[3]
    @port = @socket.addr[1]
    @thread ||= Thread.new do
      logger.info "Started a fake MQTT server on #{@address}:#{@port}"
      @times = 0
      loop do
        @times += 1
        # Wait for a client to connect
        client = @socket.accept
        @pings_received = 0
        handle_client(client)
        break if just_one
      end
    end
  end

  # Stop the thread and close the socket
  def stop
    logger.info "Stopping fake MQTT server"
    @thread.kill if @thread and @thread.alive?
    @thread = nil

    @socket.close unless @socket.nil?
    @socket = nil
  end

  # Start the server thread and wait for it to finish (possibly never)
  def run
    start
    begin
      @thread.join
    rescue Interrupt
      stop
    end
  end


  protected

  # Given a client socket, process MQTT packets from the client
  def handle_client(client)
    loop do
      packet = MQTT::Packet.read(client)
      logger.debug packet.inspect

      case packet
        when MQTT::Packet::Connect
          client.write MQTT::Packet::Connack.new(:return_code => 0)
        when MQTT::Packet::Publish
          client.write packet
          @last_publish = packet
        when MQTT::Packet::Subscribe
          client.write MQTT::Packet::Suback.new(
            :message_id => packet.message_id,
            :granted_qos => 0
          )
          topic = packet.topics[0][0]
          case @times
          when 1, ->x { x >= 3 }
            # Deliver retained messages
            client.write MQTT::Packet::Publish.new(
              :topic => topic,
              :payload => "did you know about #{topic}",
              :retain => true
            )
            client.write MQTT::Packet::Publish.new(
              :topic => topic,
              :payload => "hello #{topic}",
              :retain => true
            )
          when 2
            # Deliver a still retained message
            client.write MQTT::Packet::Publish.new(
              :topic => topic,
              :payload => "hello #{topic}",
              :retain => true
            )
            # Deliver a fresh message
            client.write MQTT::Packet::Publish.new(
              :topic => topic,
              :payload => "did you know about #{topic}",
              :retain => false
            )
          end

        when MQTT::Packet::Pingreq
          client.write MQTT::Packet::Pingresp.new
          @pings_received += 1
        when MQTT::Packet::Disconnect
          client.close
        break
      end
    end

    rescue MQTT::ProtocolException => e
      logger.warn "Protocol error, closing connection: #{e}"
      client.close
  end

end

if __FILE__ == $0
  server = MQTT::FakeServer.new(MQTT::DEFAULT_PORT)
  server.logger.level = Logger::DEBUG
  server.run
end
