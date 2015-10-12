
def if_arg arg, thing=Object, otherwise: nil
  error "no such argument", code: 3 unless $ARGP.key?(arg)
  if thing === $ARGP[arg]
    block_given? ? (yield $ARGP[arg]) : $ARGP[arg]
  else
    if otherwise.respond_to? :call
      otherwise.call
    else
      otherwise
    end
  end
end

def is_file *sym, _inverted: false, **ssym
  lambda do |f|
    _inverted ^ \
      begin 
        sym.all? {|s| File.send(s, f) } && \
        ssym.all? {|k,v| File.send(k, f) ? File.send(v, f) : true}
      rescue
        false
      end
  end
end

def error *msg, code: 1
  $stderr.print *msg, "\n"
  exit code
end

def open_file how, &b
  proc {|f| begin File.open(f, how, &b) rescue nil end}
end
