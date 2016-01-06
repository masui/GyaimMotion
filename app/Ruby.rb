# coding: utf-8

class Ruby
  #@@rubytype = 'CRuby'
  #begin
  #  require 'digest/md5'
  #rescue
  #  @@rubytype = 'RubyMotion'
  #end
  @@rubytype = 'RubyMotion'

  def Ruby.type
    @@rubytype
  end
end

