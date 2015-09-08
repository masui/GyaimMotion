# coding: utf-8
#
# GyaimMotion
#
# Created by Toshiyuki Masui on 2015/9/7
# Copyright 2015 Pitecan Systems. All rights reserved.

class AppDelegate
  def applicationDidFinishLaunching(notification)
    puts "AppDidFinishLaunching"

    #
    # IMKServerに接続
    #
    identifier = NSBundle.mainBundle.bundleIdentifier
    server = IMKServer.alloc.initWithName("Gyaim_Connection",bundleIdentifier:identifier)
  end
end
    

