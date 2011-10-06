#!/usr/bin/env ruby -wKU
#
#  seesaw.rb
#  Seesaw, a simple shell-friendly HTTP reverse proxy / load balancer
#
#  https://github.com/mars/seesaw
#
#  Created by Mars on 2010-08-20.
#  Copyright (c) 2010 Mars Hall. All rights reserved.
#  Permission granted under the MIT license.
#

require 'optparse'
require 'rubygems'
require 'active_support'
require 'eventmachine'

class Seesaw < EM::Connection
  cattr_accessor :port, :ip_address, :destination_port, :destination_count
  attr_reader :port
  
  def receive_data(data)
    @port = self.class.next_destination
    STDOUT.puts "...bind to :#{@port}"
    EM.connect(@@ip_address, @port, ProxyConnection, self, data)
  end
  
  module ProxyConnection
    def initialize(client, request)
      @client, @request = client, request
    end

    def post_init
      EM::enable_proxy(self, @client)
    end

    def connection_completed
      send_data @request
    end

    def proxy_target_unbound
      close_connection
    end

    def unbind
      STDOUT.puts "...unbind from :#{@client.port}"
      @client.close_connection_after_writing
    end
  end
  
  def self.start
    init_defaults
    @connect_count = 0
    EM.kqueue
    EM.run do
      @server = EM.start_server(@@ip_address, @@port, self)
      at_exit do
        STDOUT.puts "#{Time.now} Gettin' off the Seesaw."
      end
      STDOUT.puts "#{Time.now} Seesawing: incoming #{@@ip_address}:#{@@port}; outgoing :#{@@destination_port} x #{@@destination_count}"
    end
  end
  
  def self.init_defaults
    @@ip_address ||= '0.0.0.0'
    raise(ArgumentError, "-p/--port is required") unless @@port
    raise(ArgumentError, "-d/--dport is required") unless @@destination_port
    raise(ArgumentError, "-n/--number is required") unless @@destination_count
  end
  
  def self.next_destination
    @connect_count += 1
    @@destination_port + (@connect_count % @@destination_count)
  end
end


if $0 == __FILE__
  opts = OptionParser.new
  opts.on("-i","--ip ADDRESS", "Network address on which to listen. Defaults to 0.0.0.0.", String) do |i|
    Seesaw.ip_address = i
  end
  opts.on("-p","--port NUMBER", "Network port on which to listen.", Integer) do |p|
    Seesaw.port = p
  end
  opts.on("-d","--dport NUMBER", "Destination network port; first in the sequential pool.", Integer) do |p|
    Seesaw.destination_port = p
  end
  opts.on("-n","--number NUMBER", "Number of destination network ports.", Integer) do |n|
    Seesaw.destination_count = n
  end
  opts.on_tail("-h", "--help", "Show this usage statement.") do |h|
    STDOUT.puts opts
    exit
  end
  
  begin
    opts.parse(ARGV)
  rescue
    message = "#{$!.class}: #{$!.message}\n#{$!.backtrace * "\n"}"
    STDERR.puts message + "\n\n#{opts}"
    exit
  end
  
  begin
    Seesaw.start
  rescue
    message = "#{$!.class}: #{$!.message}\n#{$!.backtrace * "\n"}"
    STDERR.puts message
  end
end

