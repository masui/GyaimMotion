# -*- coding: utf-8 -*-
#
# Config.rb
#
# Created by Toshiyuki Masui on 2015/9.
# Copyright 2011-15 Pitecan Systems. All rights reserved.
#

class Config
  def Config.gyaimDir
    File.expand_path("~/.gyaim")
  end

  def Config.cacheDir
    "#{gyaimDir}/cacheimages"
  end

  def Config.imageDir
    "#{gyaimDir}/images"
  end

  def Config.localDictFile
    "#{gyaimDir}/localdict.txt"
  end

  def Config.studyDictFile
    "#{gyaimDir}/studydict.txt"
  end

  #
  # ここに書くのが良いのか全然わからないが確実な感じはする (2015/09/20 21:37:17)
  #
  Dir.mkdir(Config.gyaimDir) unless File.exist?(Config.gyaimDir)
  Dir.mkdir(Config.cacheDir) unless File.exist?(Config.cacheDir)
  Dir.mkdir(Config.imageDir) unless File.exist?(Config.imageDir)
  Files.touch(Config.localDictFile)
  Files.touch(Config.studyDictFile)
  
end

