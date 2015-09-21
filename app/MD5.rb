# coding: utf-8

class MD5
  def MD5.digest(str)
    case Ruby.type
    when 'CRuby'
      Digest::MD5.hexdigest(str)      # 通常のRuby
    when 'RubyMotion'
      # RmDigest::SHA1.hexdigest(str) # RubyMotion
      RmDigest::MD5.hexdigest(str)    # RubyMotion
    else
      'Wrong Ruby version'
    end
  end
end

