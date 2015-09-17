require "eventmachine"
require "warden/client"
require "warden/client/v1"
require "warden/protocol/buffer"
require "em/warden/client/error"
require "em/warden/client/event_emitter"

module EventMachine
  module Warden
    module Client
    end
  end
end

class EventMachine::Warden::Client::Connection < ::EM::Connection
  include EM::Warden::Client::EventEmitter

  IDLE_TIMEOUT = 30

  class CommandResult
    def initialize(value)
      @value = value
    end

    def get
      if @value.kind_of?(StandardError)
        raise @value
      else
        @value
      end
    end
  end

  def cancel_idle_timer
    puts "!!cancel_idle_timer: connection_id: #{@connection_id}"
    @idle_timer.cancel if @idle_timer
  end

  def setup_idle_timer
    cancel_idle_timer

    puts "!!setup_idle_timer: connection_id: #{@connection_id}"
    @idle_timer = EM::Timer.new(@idle_timeout) { idle_timeout! }
  end

  def idle_timeout=(idle_timeout)
    @idle_timeout = idle_timeout

    setup_idle_timer
  end

  def idle_timeout!
    puts "!!idle_timeout: connection_id: #{@connection_id}"
    close_connection
  end

  def post_init
    @requests  = []
    @connected = false
    @buffer    = ::Warden::Protocol::Buffer.new

    @idle_timer   = nil
    @idle_timeout = IDLE_TIMEOUT

    @connection_id = Time.now.to_f

    on(:connected) do
      puts "!!connected: connection_id: #{@connection_id}"
      @connected = true
    end

    on(:disconnected) do
      puts "!!disconnected[1]: connection_id: #{@connection_id}"
      @connected = false
    end

    on(:disconnected) do
      puts "!!disconnected[2]: connection_id: #{@connection_id}"
      # Execute callback for pending requests
      response = EventMachine::Warden::Client::ConnectionError.new("Disconnected")
      while !@requests.empty?
        _, blk = @requests.shift
        if blk
          blk.call(CommandResult.new(response))
        end
      end
    end
  end

  def connected?
    @connected
  end

  def connection_completed
    puts "!!connection_completed: connection_id: #{@connection_id}"
    emit(:connected)
  end

  def unbind
    puts "!!unbind: connection_id: #{@connection_id}"
    emit(:disconnected)
  end

  def call(*args, &blk)
    if args.first.kind_of?(::Warden::Protocol::BaseRequest)
      request = args.first
    else
      # Use array when single array is passed
      if args.length == 1 && args.first.is_a?(::Array)
        args = args.first
      end

      # Create request from array
      request = ::Warden::Client::V1.request_from_v1(args.dup)
      @v1mode = true
    end

    payload = ::Warden::Protocol::Buffer.request_to_wire(request)
    @requests << [request, blk]

    cancel_idle_timer

    send_data(payload)
  end

  def method_missing(method, *args, &blk)
    call(*([method] + args), &blk)
  end

  def receive_data(data = nil)
    @buffer << data if data
    @buffer.each_response do |response|
      # Transform response if needed
      if response.is_a?(Warden::Protocol::ErrorResponse)
        response = EventMachine::Warden::Client::Error.new(response.message)
      else
        if @v1mode
          response = Warden::Client::V1.response_to_v1(response)
        end
      end

      request, blk = @requests.shift
      if blk
        blk.call(CommandResult.new(response))
      end

      setup_idle_timer if @requests.empty?
    end
  end
end
