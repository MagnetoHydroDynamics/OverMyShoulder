#!/usr/bin/ruby2.0

NAME = 'collab'

VERSION = [0, 0, 1]

require 'docopt'
require 'yaml'
require 'thin'
require 'time'
require 'pp'

require './util.rb'
require './conf.rb'
require './html.rb'
require './cli.rb'
require './slet.rb'

parse_ARGV
dispatch_CLO
load_config

build_server

SERVER = Thin::Server.new($CONFIG['IP'], $CONFIG['PORT'], $BUILDER, signals: false)

SERVER.silent = true
COMMAND_LINE = my_CLI

trap :INT do
  SERVER.stop
  COMMAND_LINE.kill
  exit 0
end

trap :TERM do
  SERVER.stop!
  exit 0
end

COMMAND_LINE.run
SERVER.start

__END__
---
IP: 127.0.0.1
PORT: 8080
dirs:
  'test' : foo
root: foo
...
