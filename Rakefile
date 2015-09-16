# -*- coding: utf-8 -*-
#
#  % rake config で細かい設定がわかる
#
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/osx'

require 'rm-digest'

begin
  require 'bundler'
  Bundler.require
rescue LoadError
end

Motion::Project::App.setup do |app|
  #
  # Info.plistの設定が肝心なので以下のように細かく設定する。
  #
  app.name = 'Gyaim'
  app.icon = 'Gyaim.png'
  app.identifier = "com.pitecan.inputmethod.Gyaim"
  app.frameworks << 'InputMethodKit'
  app.frameworks << 'Security'
  #
  # RubyMotionの機能で設定しきれないものは直接指定
  #
  app.info_plist['tsInputMethodCharacterRepertoireKey'] = [
    "Hira", "Latn"
  ]
  app.info_plist['InputMethodConnectionName'] = "Gyaim_Connection"
  app.info_plist['InputMethodServerControllerClass'] = "GyaimController"
  app.info_plist['InputMethodServerDelegateClass'] = "GyaimController"
  app.info_plist['LSApplicationCategoryType'] = "public.app-category.productivity"
  
  app.info_plist['LSBackgroundOnly'] = true
  app.info_plist['NSMainNibFile'] = "Gyaim"
  app.info_plist['tsInputMethodIconFileKey'] = "icon.pdf"
  app.info_plist['CFBundleDevelopmentRegion'] = "English"

  app.info_plist['ComponentInputModeDict'] = {
    'tsInputModeListKey' => {
      'com.apple.inputmethod.Japanese' => {
        "TISInputSourceID" => "com.pitecan.inputmethod.Gyaim.Japanese",
        "TISIntendedLanguage" => "ja",
        "tsInputModeScriptKey" => "smJapanese",
        "tsInputModePrimaryInScriptKey" => true
      }
    },
    "tsVisibleInputModeOrderedArrayKey" => [
      "com.apple.inputmethod.Japanese"
    ]
  }

end

