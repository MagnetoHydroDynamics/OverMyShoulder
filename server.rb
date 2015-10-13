require 'time'
require 'pathname'

SERVER_TYPE = `uname -npor`.chomp!

def default_h headers: {}, len: 0
end


class Middle
  def initialize app
    @app = app
  end

  def self.response res
    res[1]['Content-Type'] ||= 'text/html; encoding=utf-8'
    res[1]['Date'] ||= Time.now.httpdate
    res[1]['Server'] ||= SERVER_TYPE
    res[1]['Content-Length'] ||= res[2].map(&:bytesize).reduce(0, &:+)
    res[1]['Content-Length'] = res[1]['Content-Length'].to_s

    res[2] ||= ['something went wrong']
    return res
  end

  def call env
    env['rack.errors'] = $LOGFILE
    case env['REQUEST_METHOD']
    when 'HEAD', 'GET'
      full_path = env['SCRIPT_NAME'] + env['PATH_INFO']
      if $PATHS[full_path]
        return self.class.response(@app.call env)
      else
        return self.class._404 full_path
      end
    else
      return self.class.response [405, {'Allowed' => 'GET, HEAD'}, []]
    end
  rescue Exception => e
    return self.class._500 e
  end

  def self._404 path
    self.response [404, {},
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
    self.response [500, {}, [
      HTM.sdoc.Html! { |doc|
        doc.
        Head {
          doc.Title { "Internal Error" }.
          Meta_(:'http-equiv' => 'content-type', :'content' => 'text/html; encoding=utf-8')
        }.
        Body {
          doc.
          H1 { "500 Internal Error" }.
          Pre { [exception.class.to_s, ": ", exception.message, "\n    ", exception.backtrace.join("\n    ")] }
        }
      }.done
    ]]
  end
end

def path_metadata p
  [p, $PATHID ||= 0, {}]
ensure
  $PATHID += 1
end

def init_PATHS
  $PATHS = {'/' => path_metadata($CONFIG['file-dir'])}
  $PATHS.each do |p, v|
    $BUILDER.map p do
      run ServerLet.new(p, v)
    end
  end
end

def clean_old minutes=5
  t = Time.now - minutes*60

  $PATHS.each_value do |v|
    v[2].each_value do |vw|
      vw.clear if vw.time < t
    end
  end
end

def diff_directories dir='/'
  dir.slice!(0) if dir[0] == '/'
  
  diff = {}
  $PATHS.each_key { |p| diff[p] = nil }
  diff.delete('/')
  
  fdir = $CONFIG['file-dir']
  dir = fdir + dir
  
  dir.children.each do |p|
    next unless $CONFIG['filetypes'].key? (p.directory? ? '/' : p.extname)
    next if p.fnmatch('.*')

    rp = '/' + p.relative_path_from(fdir).to_s
    rp = rp + '/' if p.directory?

    if diff.key? rp
      diff.delete rp
    else
        diff[rp] = path_metadata(p)
        $PATHID += 1
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
  $BUILDER.run ->_{raise "this should never happen"}
end
