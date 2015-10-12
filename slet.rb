
class ServerLet
  def initialize path, data
    @path = path
    @metadata = data
  end

  def call env
    full_path = env['SCRIPT_NAME'] + env['PATH_INFO']
    
    case env['REQUEST_METHOD']
    when 'GET'
      render
    when 'HEAD'
      pp env
      [200, {}, []]
    end
  end

  def filepath; @metadata[0] end
  def id; @metadata[1] end

  def render
    if directory?
      /\A#{@path}/o
      $PATHS.keys.keep_if { |p| /\A#{@path}/
      [200, {'Content-Type' => 'text/plain'}, []]
    else
      [200, {'Content-Type' => 'text/plain'}, [File.open(filepath, 'r', &:read)]]
    end
  end
end
