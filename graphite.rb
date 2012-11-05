require 'socket'

class Graphite
  def self.publish(data)
    new(data).publish
  end

  attr_accessor :data

  def initialize(data={})
    @data = data
  end

  def publish
    @data.each do |key, value|
      send_data(key, value)
    end
  end

  def send_data(key, value, time=nil)
    time ||= Time.now
    socket.send "#{key} #{value} #{time.to_i}\n", 0, 'ec2-23-20-30-71.compute-1.amazonaws.com', 2003
  end

  private

  def socket
    @socket ||= UDPSocket.new
  end
end
