# coding: utf-8
#
#
class MD5
  @@ruby = 'CRuby'
  begin
    require 'digest/md5'
  rescue
    @@ruby = 'RubyMotion'
  end

  def MD5.digest(str)
    if @@ruby == 'CRuby'
      Digest::MD5.hexdigest(str)      # 通常のRuby
    else
      # RmDigest::SHA1.hexdigest(str) # RubyMotion
      RmDigest::MD5.hexdigest(str)    # RubyMotion
    end
  end
  
end

