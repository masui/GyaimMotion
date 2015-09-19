# -*- coding: utf-8 -*-
#
# Image.rb
#
# Created by Toshiyuki Masui on 2015/9.
# Copyright 2011-15 Pitecan Systems. All rights reserved.
#

class Image
  def Image.resize(size,src,dst=nil)
    if dst then
      system "sips -s format png #{src} --resampleHeight #{size} --out #{dst} > /dev/null >& /dev/null"
    else
      system "sips -s format png #{src} --resampleHeight #{size} > /dev/null >& /dev/null"
    end
  end  
end

