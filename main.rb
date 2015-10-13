#!/usr/bin/ruby2.0

NAME = 'collab'

VERSION = [0, 0, 1]

require 'docopt'
require 'yaml'
require 'thin'
require 'time'
require 'pp'
require 'mono_logger'
require 'pathname'

require './util.rb'
require './opt.rb'
require './html.rb'
require './cli.rb'
require './slet.rb'
require './server.rb'

parse_ARGV
dispatch_CLO
load_config

build_server

Thin::Logging.logger = MonoLogger.new $LOGFILE
Thin::Logging.debug = true
Thin::Logging.trace = false

$SERVER = Thin::Server.new($CONFIG['IP'], $CONFIG['PORT'], $BUILDER, signals: false)

trap :INT do
  $SERVER.stop
  exit 0
end

trap :TERM do
  $SERVER.stop!
  exit 0
end

init_PATHS
# update_directories

make_CLI.run
$SERVER.start

__END__
---
IP: 127.0.0.1

PORT: 8080

file-dir: './files/'

fifo-dir: './fifo/'

css-dir: './css/'

js-dir: './js/'

views:
  dir: 'dir.css'
  mark: 'mark.css'
  code: 'code.css'
  nav: 'nav.css'
  img: 'img.css'
  ? dl
  ? txt
  ? html

default:
  '.mkdn': mark
  '.rb': code
  '.txt': code
  '.js': code
  '.css': code
  '.html': html
  '/': dir

filetypes:
  '.mkdn':
    ? mark
    ? code
    ? txt
  '.rb':
    ? code
    ? txt
  '.txt':
    ? code
    ? txt
  '.js':
    ? code
    ? txt
  '.css':
    ? code
    ? txt
  '.html':
    ? html
    ? txt
  '/': 
    ? dir
...
