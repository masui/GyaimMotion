# -*- coding: utf-8 -*-
#
# Files.rb
#
# ファイル処理、http/getなど
#
# Created by Toshiyuki Masui on 2011/3/14.
# Modified by Toshiyuki Masui on 2015/9.
# Copyright 2011-15 Pitecan Systems. All rights reserved.
#

class Files
  def Files.gyaimDir
    File.expand_path("~/.gyaim")
  end

  def Files.cacheDir
    "#{gyaimDir}/cacheimages"
  end

  def Files.imageDir
    "#{gyaimDir}/images"
  end

  def Files.localDictFile
    "#{gyaimDir}/localdict.txt"
  end

  def Files.studyDictFile
    "#{gyaimDir}/studydict.txt"
  end

  def Files.copy(srcfile,dstfile)
    open(srcfile){ |src|
      open(dstfile,"w"){ |dst|
        dst.write(src.read)
      }
    }
  end

  def Files.move(srcfile,dstfile)
    copy(srcfile,dstfile)
    File.unlink(srcfile)
  end

  def Files.get(url,file)
    # urlがmoved permanentlyのときを考慮する必要あるかも
    AFMotion::HTTP.get(url) do |result|
      File.open(file,"w"){ |f|
        f.print result.object
      }
    end
  end

  def Files.resize(size,src,dst=nil)
    if dst then
      system "sips -s format png #{src} --resampleHeight #{size} --out #{dst} > /dev/null >& /dev/null"
    else
      system "sips -s format png #{src} --resampleHeight #{size} > /dev/null >& /dev/null"
    end
  end  
end

