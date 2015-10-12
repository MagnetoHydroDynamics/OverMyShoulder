
class HTM

  DOCTYPE = "<?xml encoding='UTF-8' version='1.0'\n" \
            "?><!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.1//EN'\n" \
            "'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'\n".freeze
  
  BIG = {}
  %w[html head body div nav table ul ol article section].each {|s| BIG[s] = true}

  DEFAULTS = {
    'html' => { xmlns: 'http://www.w3.org/1999/xhtml' },
  }
  
  def self.doc
    self.new([DOCTYPE], first: '>')
  end

  def self.sdoc
    self.new(DOCTYPE.dup, first: '>')
  end

  def initialize data=[], first: nil, tab: 0
    @data = data 
    @closer = first
    @tabstop = tab
  end

  def nl
    @data << "\n"
    @data << ' '*@tabstop if @tabstop > 0
    self
  end

  def tt
    @tabstop += 1
    self
  end

  def bb
    @tabstop -= 1
    self
  end

  attr_reader :data

  def tag name, **attrs, &block

    self._open name
    
    self._attributes attrs, big: BIG[name]

    self.tt.nl if BIG[name]
    
    self._interpret (
      case block.arity
      when 0
        block.call
      when 1
        block.call self
      else
        raise ArgumentError, "wrong number of arguments to block"
      end
    ) if block

    self.bb.nl if BIG[name]

    self._close name

    self
  end

  def tag! name, **attrs, &block

    DEFAULTS[name].each do |attr, val|
        attrs[attr] ||= val
    end

    self.tag name, **attrs, &block
  end

  def tag_ name, **attrs

    self._open name

    self._attributes attrs, big: BIG[self]

    self._empty
    
    self
  end

  def done
    self._nix
    @data
  end

  def _open name
    self._nix '>'
    @data << '<' << name
  end

  def _nix closer=nil
    @data << @closer if @closer
    @closer = closer
  end

  def _close name
    self._nix '>'
    @data << '</' << name
  end

  def _empty
    @closer = '/>'
  end
  
  def _attributes attrs, big: false
    attrs.each do |key, value|
      self.nl if big
      @data << ' ' << key.to_s << '=' << value.encode(xml: :attr)
    end
  end

  def _interpret res
    case res
    when HTM
      self._interpret res.data unless self.equal? res
    when Array
      self._nix
      case @data
      when Array
        @data.concat res
      when String
        @data << res.join
      end
    when String
      self._nix
      @data << res.encode(xml: :text)
    end
  end

  def self.[] *arr
    arr.map {|s| s.encode(xml: :text) }
  end
  
  def method_missing name, *args, **attrs, &block
    name = name.to_s
    if name[0] == name[0].upcase && name[0].downcase != name[0].upcase
      name.downcase!
      return (
        if name[-1] == '_'
          name.slice! -1
          self.tag_ name, **attrs
        elsif name[-1] == '!'
          name.slice! -1
          self.tag! name, **attrs, &block
        else
          self.tag name, **attrs, &block
        end
      )
    else
      raise NoMethodError, "no method `#{name}' for #{self}"
    end
    self
  end
   
end
