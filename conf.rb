
require 'docopt'

OPTS = <<-OPTS
Usage:
    #{NAME} [options]

Options:
    -?, --help                  show this message and exit
    --version                   show version and exit
    -cFILE, --config=FILE       configuration file [default: conf.yaml]
    -lFILE, --log=FILE          log file [default: log.log]
    -iADDR, --ip=ADDR           ip address [default: 127.0.0.1]
    -pPORT, --port=PORT         tcp port [default: 8080]
    --default                   write default settings
OPTS

def parser_ARGV
  begin
    $ARGP = Docopt::docopt(OPTS, help: false)
  rescue Docopt::Exit => e 
    error e.message, code: 2
  end
end

def dispatch_CLO
  if_arg '--version', true do
    error NAME, ' ', VERSION.join('.'), code: 2
  end

  if_arg '--help', true do
    $stderr.print OPTS
    exit 2
  end

  if_arg '--default', true do
    begin
      File.open('conf.yaml', 'w') do |file|
        IO.copy_stream(DATA, file)
      end
    rescue
      error "Could not write default file"
    end
  end
end

def load_config
  error 'Bad config file.' unless\
    $CONFILE = if_arg('--config', is_file(:file?, :readable?), &open_file('r', &:read))

  error 'Bad log file.' unless\
    $LOGFILE = if_arg('--log', is_file(file?: :writable?), &open_file('a'))

  $LOGFILE.sync = true

  $CONFIG = YAML.load $CONFILE rescue error "Bad config file."

  $CONFIG['IP'] = if_arg('--ip') || $CONFIG['IP']
  $CONFIG['PORT'] = if_arg('--port', /\A\d+\z/, &:to_i) || $CONFIG['PORT']

  error 'Bad port.' unless\
    (0 ... 2**16) === $CONFIG['PORT']

  error 'Bad IP.' unless\
    $CONFIG['IP'] =~ /\A(\d{1,3}).(\d{1,3}).(\d{1,3}).(\d{1,3})\z/ and\
    [$1,$2,$3,$4].all? { |i| (0 ... 256) === i.to_i }
end
