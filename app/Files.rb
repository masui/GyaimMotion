# -*- coding: utf-8 -*-
#
# GyaimController.rb
#
# Created by Toshiyuki Masui on 2011/3/14.
# Modified by Toshiyuki Masui on 2015/9.
# Copyright 2011-15 Pitecan Systems. All rights reserved.
#

class Files
  def Files.dictDir
    File.expand_path("~/.gyaimdict")
  end

  def Files.cacheDir
    "#{dictDir}/cacheimages"
  end

  def Files.imageDir
    "#{dictDir}/images"
  end

  def Files.localDictFile
    "#{dictDir}/localdict.txt"
  end

  def Files.studyDictFile
    "#{dictDir}/studydict.txt"
  end
end

