# -*- coding: utf-8 -*-
#
# GyaimController.rb
#
# Created by Toshiyuki Masui on 2011/3/14.
# Modified by Toshiyuki Masui on 2015/9.
# Copyright 2011-15 Pitecan Systems. All rights reserved.
#

class DictFiles
  def DictFiles.dictDir
    File.expand_path("~/.gyaimdict")
  end

  def DictFiles.cacheDir
    "#{dictDir}/cacheimages"
  end

  def DictFiles.imageDir
    "#{dictDir}/images"
  end

  def DictFiles.localDictFile
    "#{dictDir}/localdict.txt"
  end

  def DictFiles.studyDictFile
    "#{dictDir}/studydict.txt"
  end
end

