require 'time'
require 'pathname'

SERVER_TYPE = `uname -npor`.chomp!

def default_h headers: {}, len: 0
  headers['Content-Type'] ||= 'text/html; encoding=utf-8'
  headers['Date'] ||= Time.now.httpdate
  headers['Server'] ||= SERVER_TYPE
  headers['Content-Length'] ||= len.to_s
  headers
end

def response res
  default_h headers: res[1], len: compute_length(res[2])
  res
end

def compute_length body
  case body
  when Array
    body.map(&:length).reduce(0,&:+)
  when String
    body.length
  end
end

class Middle
  def initialize app
    @app = app
  end

  def call env
    env['rack.errors'] = $LOGFILE
    case env['REQUEST_METHOD']
    when 'HEAD', 'GET'
      full_path = env['SCRIPT_NAME'] + env['PATH_INFO']
      if $PATHS[full_path]
        response(@app.call env)
      else
        self.class._404 full_path
      end
    else
      response [405, {'Allowed' => 'GET, HEAD'}, []]
    end
  rescue Exception => e
    self.class._500 e
  end

  def self._404 path
    response [404, {},
      [HTM.sdoc.Html! { |doc|
        doc.Head {
          doc.Title { "Not Found" }
        }.Body {
          doc.
          H1 { "404 Not Found" }.
          Pre { path }
        }
      }.done
    ]]
  end

  def self._500 exception
    response [500, {}, [
      HTM.sdoc.Html! { |doc|
        doc.
        Head {
          doc.Title { "Internal Error" }.
          Meta_(:'http-equiv' => 'content-type', :'content' => 'text/html; encoding=utf-8')
        }.
        Body {
          doc.
          H1 { "500 Internal Error" }.
          Pre { HTM[exception.class.to_s, ": ", exception.message, "\n    ", exception.backtrace.join("\n    ")] }
        }
      }.done
    ]]
  end
end

def init_PATHS
  $PATHS = {'/' => [Pathname.new($CONFIG['file-dir']), 0]}
  $PATHID = 1
  $PATHS.each do |p, v|
    $BUILDER.map p do
      run ServerLet.new(p, v)
    end
  end
end

def diff_directories dir='/'
  glob = ($CONFIG['filetypes'].key?('/') ? '**/*' : '**')

  diff = {}
  $PATHS.each_key { |p| diff[p] = nil }
  diff.delete('/')

  fdir = Pathname.new($CONFIG['file-dir'])
  dir = fdir + dir

  extra = dir.directory? ? [dir.to_s] : []

  $CONFIG['filetypes'].each_key do |ext|
    Dir[dir + (glob + ext)].concat(extra).each do |p|
      rp = '/' + (p = Pathname.new(p)).relative_path_from(fdir).to_s

      if ext == '/'
        rp = File.join(rp, '/')
      end

      if diff.key?(rp)
        diff.delete rp
      else
        diff[rp] = [p, $PATHID]
        $PATHID += 1
      end
    end
  end
    
  puts diff.keys

  return diff
end

def update_directories dir='/'
  diff = diff_directories dir
  map = $BUILDER.instance_variable_get(:@map)
  diff.each do |p, v|
    if v
      $PATHS[p] = v
      $BUILDER.map p do
        run ServerLet.new(p, v)
      end
    else
      map.delete p if map
      $PATHS.delete p
    end
  end
end

def build_server
  $BUILDER = Rack::Builder.new
  $BUILDER.use Middle
  $BUILDER.use Rack::CommonLogger
end
