require 'time'

SERVER_TYPE = `uname -npor`.chomp!

$BUILDER = Rack::Builder.new
$BUILDER.use Rack::CommonLogger $LOGFILE

class SERVLET
  def initialize name, info
    @name = name
    @info = info
    (@@all ||= []) << self
  end

  def def_headers headers: {}, len: 0
    headers['Content-Type'] ||= 'text/html; encoding=utf-8'
    headers['Date'] ||= Time.now.httpdate
    headers['Server'] ||= SERVER_TYPE
    headers['Content-Length'] ||= len
  end

  def compute_length body
    body.map(&:length).reduce(0,&:+)
  end

  attr_reader :name, :info

  def call env
    case env['REQUEST_METHOD']
    when 'GET'
      code = self.render env, headers={}, body=[]
      def_headers(headers: headers, len: compute_length(body))
      [code, headers, body]
    when 'HEAD'
      code = self.meta env, headers={}
      def_headers(headers: headers)
      [code, headers, []]
    else
      [405, {'Allowed' => 'GET, HEAD'}, []]
    end
  rescue Exception => e
    _500 e
  end

  def render env, headers, body
    doc = HTM.doc
    doc.Html { doc.Head { doc.Title { doc.s "nothing" } } .Body { } }.done
    body.concat doc.data
    200
  end

  def meta env, headers
    204
  end

  def _404
    (doc = HTM.doc).
    Html {
      doc.tt.nl.
      Head {
        doc.tt.nl.
        Title {
          doc.s "Not Found"
        }.nl.
        Meta_(:'http-equiv' => 'content-type', :'content' => 'text/html; encoding=utf-8').
        bb.nl
      }.nl.
      Body {
        doc.tt.nl.
        H1 { doc.s "404 Not Found" }.
        P { doc.s "resource not found" }.
        bb.nl
      }.
      bb.nl
    }.done

    [404, def_headers(headers: {}, len: compute_length(doc.data)), doc.data]
  end

  def _500 exception
    (doc = HTM.doc).
    Html {
      doc.tt.nl.
      Head {
        doc.tt.nl.
        Title {
          doc.s "Internal Error"
        }.nl.
        Meta_(:'http-equiv' => 'content-type', :'content' => 'text/html; encoding=utf-8').
        bb.nl
      }.nl.
      Body {
        doc.tt.nl.
        H1 { doc.s "500 Internal Error" }.
        Pre { doc.s(exception.message).s("\n").s(exception.backtrace.join("\n")) }.
        bb.nl
      }.
      bb.nl
    }.done

    [500, def_headers(headers: {}, len: compute_length(doc.data)), doc.data]
  end
  
  def self.all; @all end
end

class DIR_SERVLET < SERVLET
  def initialize name, info
    super name, info
  end
end

class FILE_SERVLET < SERVLET
  def initialize name, info
    super name, info
  end
end

class ROOT_SERVLET < SERVLET
  def initialize name, info
    super name, info
  end

  def render env, headers, body
    super env, headers, body    
  end

  def meta env, headers

    if dt = env['HTTP_If-Modified-Since']

      time = Time.httpdate(dt)
      ret = 304

      @@all.each do |slet|
        next if slet == self
        ret = 204 if time < File.ctime(slet.info['path'])
      end

    end

    ret
  end
end

