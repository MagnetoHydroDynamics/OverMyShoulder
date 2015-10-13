require './html.rb'

$VIEWS = {}

class View
  def initialize path, url, views
    @path = path
    @url = url
    @views = views
    @body = nil
    @headers = nil
    @time = nil
  end

  def clear
    @time = @body = @headers = nil
  end

  def self.register
    $VIEWS[self.view] = self
  end


  attr_reader :time, :body, :headers

  def build fifo=nil
    @time ||= Time.now
    @body ||= self.make_body fifo
    @headers ||= (h = {
      'Content-Type' => self.content_type,
      'Content-Length' => self.compute_length.to_s
    };
    h['Content-Disposition'] = d if d=self.disposition;
    h)
  end

  def re_build fifo=nil
    self.clear
    self.build fifo
  end

  def compute_length
    @body.reduce(0) { |len, str| len + str.bytesize} if @body
  end

  def self.resource_file p
    @@res ||= {}
    res = nil

    if p.file? && p.readable?
      if @@res[p].nil? || @@res[p][1] < p.ctime
        res, = (@@res[p] = [p.read, Time.now])
      end
    end

    res
  end

  def self.common_head doc, title
    doc.Title(id: 'TITLE') {
      title
    }.Style(id: 'STYLE') {
      doc.raw
      self.resource_file self.css_file
    }
  end

  def self.update_script doc
    $UPDATE_SCRIPT ||= $CONFIG['js-dir'] + 'UpdateScript.js'
    doc.Script(id: 'SCRIPT', type: 'text/javascript', charset: 'utf-8') {
      doc.raw
      ["//<![CDATA[\n",
        "updateFrequency = 5000;\n",
        self.class.resource_file($UPDATE_SCRIPT),
      "//]]>"]
    }
  end

  def self.css_file;
      $CONFIG['css-dir'] + $CONFIG['views'][self.view]
  end

  def make_body fifo
    raise NoMethodError, 'unimplemented'
  end

  def content_type; 'text/html; charset=UTF-8' end
  def disposition; nil end

  def self.view; raise NoMethodError, 'unimplemented' end
  def self.fifo?; false end
  def self.cache?; true end
end

class Navigation < View
  def self.view; 'nav' end
  self.register 

  def content_type; 'text/html; charset=UTF-8' end

  def make_body _
    HTM.doc.Html! { |doc|
      doc.Head {
        self.class.common_head doc, @path.basename
      }.Body {
        doc.Nav {
          @views.keys.each do
            |vw|
            doc.A(href: @url + "?#{vw}") { Views::VIEWS[vw] } if vw != 'nav'
          end
        }
      }
    }.done
  end
end

class Directory < View
  def self.view; 'dir' end
  self.register 

  def content_type; 'text/html; charset=UTF-8' end

  def make_body _
    HTM.doc.Html! { |doc|
      doc.Head {
        self.class.common_head doc, @path.basename
      }.Body {
        doc.Nav {
          doc.Ul {
            $PATHS.keys.select { |p|
              $1 if p =~ /\A#{@url}(.+)/o
            }.sort.each { |p|
              doc.Li { doc.A(href: @url + p) { p } }
            }
            nil
          }
        }
      }
    }.done
  end
end

class Markdown < View
  def self.fifo?; true; end
  def self.view; 'mark' end
  self.register 

  def content_type; 'text/html; charset=UTF-8' end

  def make_body fifo
    HTM.doc.Html! { |doc|
      doc.Head(id: 'HEAD') { 
        self.class.common_head doc, @path.basename
      }.Body(id: 'BODY') {
        doc.Nav(id: 'NAV') {
          doc.A(href: @url + '?nav') { "[Views]" } 
        }.Article(id: 'ARTICLE') {
          doc.raw
          if system("pandoc -f markdown -t html -i #{@path} > #{fifo} &")
            fifo.readlines
          else
            raise "Failed to run pandoc"
          end
        }
        self.class.update_script doc
      }
    }.done
  end
end

class Code < View
  def self.view; 'code' end
  self.register 

  def content_type; 'text/html; charset=UTF-8' end

  def make_body _

    HTM.doc.Html! { |doc|
      doc.Head(id: 'HEAD') {
        self.class.common_head doc, @path.basename
      }.Body(id: 'BODY') {
        doc.Nav(id: 'NAV') {
          doc.A(href: @url + '?nav') { "[Views]" } 
        }.Pre {
          doc.raw
          (nw = @path.readlines).tap { |lines|
            nw = lines.length.to_s.length
          }.map!.each_with_index { |s, i|
            [ "<span class='lineno'>#{s.rjust(nw)}</span>", s ]
          }.flatten!
        }
        self.class.update_script doc
      }
    }.done
  end
end

class Plain < View
  def self.view; 'txt' end
  self.register 

  def content_type; 'text/plain; charset=UTF-8' end

  def make_body _
    [@path.read]
  end
end

class HTML < View
  def self.view; 'html' end
  self.register 

  def make_body _
    [@path.read]
  end
end

class Download < View
  def self.cache?; false end
  def self.view; 'dl' end
  self.register 

  def content_type;
    @content_type ||= `file -b --mime-type --mime-encoding #{@path}`.chomp!
  end
  def disposition
    "attachment; filename=\"#{@path.basename}\""
  end

  def make_body _
    [File.open(@path,'rb', &:read)]
  end
end

class Image < View
  def self.fifo?; false end
  def self.view; 'img' end
  self.register 

  def make_body _
    HTM.doc.Html! { |doc|
      doc.Head { 
        self.class.common_head doc, @path.basename
      }.Body {
        doc.Nav(id: 'NAV') {
          doc.A(href: @url + '?nav') { "[Views]" } 
        }.Img_(src: @url + '?dl') 
        self.class.update_script doc
      }
    }.done
  end
end
