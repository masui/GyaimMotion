# coding: utf-8
#
# GyaimMotion
#
# Created by Toshiyuki Masui on 2015/9/7
# Copyright (C) 2015 Pitecan Systems. All rights reserved.
#
class AppDelegate
  def applicationDidFinishLaunching(notification)
    #
    # IMKServerに接続
    #
    identifier = NSBundle.mainBundle.bundleIdentifier
    server = IMKServer.alloc.initWithName("Gyaim_Connection",bundleIdentifier:identifier)

    #
    # ペーストバッファの時刻を常に記憶しておく (古いものは変換候補に出さないようにするため)
    # ポーリングがダサいが他に方法がないような
    #
    Thread.new do
      while true do
        CopyText.set NSPasteboard.generalPasteboard.stringForType(NSPasteboardTypeString)
        sleep 60
      end
    end
  end
end
    

