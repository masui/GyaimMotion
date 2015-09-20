# -*- coding: utf-8 -*-
#
# OpenSSL gem を使ってたのだがRubyMotionでは使えないので他の方法を使う
#

class Crypt
  def Crypt.encrypt(str,salt)
    uu = MD5.digest(salt)
    packed = [str].pack("u").chomp
    packed.split(//).each_with_index.map { |c,i|
      n = uu[(i*4)%32,4].hex
      (((c.ord-32+n)%64)+32).chr
    }.join('').unpack("H*")[0]
  end
  
  def Crypt.decrypt(str,salt)
    uu = MD5.digest(salt)
    res = [str].pack("H*").split(//).each_with_index.map { |c,i|
      n = uu[(i*4)%32,4].hex
      (((c.ord-32-n)%64)+32).chr
    }.join('').unpack("u")[0]
    res.force_encoding("UTF-8") # 無理に指定
  end
end

if __FILE__ == $0 then
  s = Crypt.encrypt("増井みたいな","def")
  puts s
  ss = Crypt.decrypt(s,"def")
  puts ss
end

