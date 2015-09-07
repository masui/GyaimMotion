# CandView.rb
# Gyaim
#
# Created by Toshiyuki Masui on 2011/3/15.
# Copyright 2011 Pitecan Systems. All rights reserved.

class CandView < NSView
  def drawRect(rect)
    mainBundle = NSBundle.mainBundle
    puts "mainBundle=#{mainBundle}"
    image = NSImage.alloc.initByReferencingFile(mainBundle.pathForResource("candwin",ofType:"png"))
    puts "image=#{image}"
    image.compositeToPoint(NSZeroPoint,operation:NSCompositeSourceOver)
  end
end
