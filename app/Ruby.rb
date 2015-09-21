# coding: utf-8

class Ruby
  @@rubytype = 'CRuby'
  begin
    require 'digest/md5'
  rescue
    @@rubytype = 'RubyMotion'
  end

  def Ruby.type
    @@rubytype
  end
end

