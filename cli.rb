
class CLI

  def initialize
    @commands = {}
    @help = {}
    @error = nil
    @thread = nil
  end
  
  attr_accessor :commands, :help, :error

  def defn name, help_msg, &block
    @commands[name] = block
    @help[name] = help_msg
  end

  def main_loop
    print '- '
    STDIN.each_line do |line|
      command, args = line.split
      if command=@commands[command]
        command.call *args
      else
        puts 'error'
        @commands[@error].call
      end
      print '- '
    end
  end

  def run
    @thread = Thread.new &(self.method(:main_loop))
  end

  def join
    @thread.join
  end

  def kill
    @thread.kill
  end

end

def my_CLI
  cli = CLI.new

  cli.defn 'debug',
    "debug [all]\tInspect log. If 'all' is given, prints the whole log first." \
  do |all=nil, *_|
    begin
      seek = \
        case all
        when nil
          IO::SEEK_END
        when 'all'
          IO::SEEK_SET
        else
          puts 'error'
          help 'debug'
          return
        end
      log = File.open(if_arg('--log', is_file(:file?)), 'r')
      log.seek(0, seek)
      
      loop do
        Kernel.select([log, STDIN])[0].each do |f|
          print f.gets
          return if f == STDIN
        end
      end
    rescue
      puts 'unable to inspect log file'
    end
  end

  cli.defn 'quit',
    "quit\tExit in an orderly manner." \
  do |*_|
    puts 'quitting'
    $SERVER.stop
    cli.kill
    exit 0
  end

  cli.defn 'restart',
    "restart\tRestart the server." \
  do |*_|
    puts 'restarting'
    exec $0, *ARGV
  end

  cli.defn 'help',
    "help [<command>]\tGeneral help. If <command> is supplied, gives specific help." \
  do |command=nil, *_|
    if command
      if msg=cli.help[command]
        puts msg
      else
        puts 'unknown command'
      end
    else
      puts 'available commands:'
      puts cli.help.keys
    end
  end

  cli.error = 'help'

  cli
end




