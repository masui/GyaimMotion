# -*- coding: utf-8 -*-
#
# OpenSSL gem を使ってたのだがRubyMotionでは使えないので他の方法を検討する
#

if __FILE__ == $0 then
  require 'digest/md5'
end

class Crypt
  def Crypt.digest(str)
    if __FILE__ == $0 then
      Digest::MD5.hexdigest(str)      # 通常のRuby
    else
      RmDigest::SHA1.hexdigest('foo') # RubyMotion
    end
  end

  def Crypt.encrypt(str,salt)
    uu = digest(salt)
    packed = [str].pack("u").chomp
    packed.split(//).each_with_index.map { |c,i|
      n = uu[(i*4)%32,4].hex
      (((c.ord-32+n)%64)+32).chr
    }.join('').unpack("H*")[0]
  end
  
  def Crypt.decrypt(str,salt)
    uu = digest(salt)
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

#class Crypt
#  #
#  # 単語の暗号化登録のために利用する暗号化/複号化ライブラリ
#  # ウノウラボから持ってきたもの
#  # http://labs.unoh.net/2007/05/ruby.html
#  # decryptしても漢字に戻らない不具合あり
#  # 
#  def Crypt.encrypt(aaa, salt = 'salt')
#    puts "encrypt(#{aaa},#{salt})"
#    # enc = OpenSSL::Cipher::Cipher.new('aes256')
#    # enc.encrypt
#    # enc.pkcs5_keyivgen(salt)
#    # #((enc.update(aaa) + enc.final).unpack("H*")).to_s  # 何故か文字列への変換に失敗することがある...
#    # ((enc.update(aaa) + enc.final).unpack("H*"))[0]
#    "xxxxxxx"
#  rescue
#    false
#  end
#
#  def Crypt.decrypt(bbb, salt = 'salt')
#  # dec = OpenSSL::Cipher::Cipher.new('aes256')
#  # dec.decrypt
#  # dec.pkcs5_keyivgen(salt)
#  # (dec.update(Array.new([bbb]).pack("H*")) + dec.final)
#    "yyyyyyyy"
#  rescue  
#    false
#  end
#end

