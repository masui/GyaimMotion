# -*- coding: utf-8 -*-
#
# Emulration.rb
#
# Created by Toshiyuki Masui on 2015/9.
# Copyright 2011-15 Pitecan Systems. All rights reserved.
#

class Emulation
  #
  # JXA(MacのJavaScript)でキーボードエミュレーションを行なう. (Yosemite以降のみ)
  # かなり苦しいが割と安定して動いている.
  #
  def Emulation.key(keycode, modifier=nil)
    #
    # Emulation.key("z", "command down") # undo
    # Emulation.key(49)                  # space
    #
    modstr = (modifier ? ", {using:[\"#{modifier}\"]}" : '')
    jxa_cmd =
      if keycode.class == String then
        "Application(\"System Events\").keystroke(\"#{keycode}\"#{modstr});"
      else
        "Application(\"System Events\").keyCode(#{keycode}#{modstr});"
      end
    system "osascript -l JavaScript -e '#{jxa_cmd}'"
  end
end
