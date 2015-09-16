# coding: utf-8
#
# GyaimMotion
#
# Created by Toshiyuki Masui on 2015/9/8.
# Copyright (C) 2011-2015 Pitecan Systems. All rights reserved.
#
class CandTextView < NSTextView
  @@candTextView = nil

  # TextViewが生成されるときに呼ばれる。
  # initWithFrameなどは呼ばれないようである
  def awakeFromNib
    super
    @@candTextView = self
  end
  
  def CandTextView.candTextView
    @@candTextView
  end
end

