# -*- coding: utf-8 -*-
#
# GyaimController.rb
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
end

