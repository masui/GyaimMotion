#
# Created by Toshiyuki Masui on 2011/3/15.
# Modified by Toshiyuki Masui on 2015/9/8.
#
# Copyright (C) 2011-2015 Pitecan Systems. All rights reserved.
#
class CandView < NSView
  def drawRect(rect)
    mainBundle = NSBundle.mainBundle
    image = NSImage.alloc.initByReferencingFile(mainBundle.pathForResource("candwin",ofType:"png"))
    image.compositeToPoint(NSZeroPoint,operation:NSCompositeSourceOver)
  end
end
