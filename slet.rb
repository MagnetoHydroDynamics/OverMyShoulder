require 'time'
require 'pathname'
require 'pp'
require './view.rb'

class ServerLet
  def initialize url, data
    @metadata = data
    path = data[0]
    @ext = (path.directory? ? '/' : path.extname)
    @default = $CONFIG['default'][@ext]

    @views = data[2]
    $CONFIG['filetypes'][@ext].each_key { |vw| @views[vw] = nil }

    @views['dl'] = nil
    @views['nav'] = nil

    @views.each_key do |vw|
      @views[vw] = $VIEWS[vw].new(data[0], url, @views)
    end
  end

  def call env
    query = env['QUERY_STRING']
    query = @views.key?(query) ? query : @default

    code = 200
    
    theview = @views[query]
    fifo = nil 

    if theview.class.fifo? && theview.time.nil?
      fifo = "fifo#{@metadata[1]}.swp"
      dir = $CONFIG['fifo-dir']
      
      fifo = fifo.succ while (dir + fifo).exists?
    end
    
    if theview.time && theview.time < @metadata[0].ctime
      theview.clear
    end

    res = theview.build fifo
    theview.clear unless theview.class.cache?

    if env['REQUEST_METHOD'] == 'HEAD'
      res[0] = 204
      res[2] = []
      if t=env['HTTP_IF_MODIFIED_SINCE']
        res[0] = 304 if theview.time < Time.httpdate(t)
      end
    end

    res
  end
end
