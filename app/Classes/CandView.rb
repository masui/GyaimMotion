# CandView.rb
# Gyaim
#
# Created by Toshiyuki Masui on 2011/3/15.
# Copyright 2011 Pitecan Systems. All rights reserved.

File.open("/tmp/log","a"){ |f|
  f.puts "CandView start"
}

class CandView < NSView
  #def initWithFrame(NSRect:frame)
  #  super frame
  #  @@candView = self
  #end
  #
  #def CandView.candView
  #  @@candView
  #end
  
  def drawRect(rect)
    mainBundle = NSBundle.mainBundle
    # puts "mainBundle=#{mainBundle}"
    image = NSImage.alloc.initByReferencingFile(mainBundle.pathForResource("candwin",ofType:"png"))
    # puts "image=#{image}"
    image.compositeToPoint(NSZeroPoint,operation:NSCompositeSourceOver)
  end
end

File.open("/tmp/log","a"){ |f|
  f.puts "CandView end"
}

