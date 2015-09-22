# -*- coding: utf-8-emacs -*-
#
# GyaimController.rb
#
# Created by Toshiyuki Masui on 2011/3/14.
# Modified by Toshiyuki Masui on 2015/9.
# Copyright 2011-15 Pitecan Systems. All rights reserved.
#

class GyaimController < IMKInputController
  attr :candidates, true
  attr :searchmode, true
  
  @@gc = nil

  def initWithServer(server, delegate:d, client:c)
    @client = c
    #
    # RubyMotionでIBとの関連づけがうまくいかないので
    #
    @textview = CandTextView.candTextView
    @candwin = CandWindow.candWindow

    # 辞書サーチ
    connectionDictFile = NSBundle.mainBundle.pathForResource("dict", ofType:"txt")
    if @ws.nil? then
      @ws = WordSearch.new(connectionDictFile, Config.localDictFile, Config.studyDictFile)
    end

    CopyText.set NSPasteboard.generalPasteboard.stringForType(NSPasteboardTypeString)

    resetState

    if super then
      @@gc = self
    end
  end

  #
  # 入力システムがアクティブになると呼ばれる
  #
  def activateServer(sender)
    CopyText.set NSPasteboard.generalPasteboard.stringForType(NSPasteboardTypeString)
    @ws.start
    showWindow
  end

  #
  # 別の入力システムに切り換わったとき呼ばれる
  #
  def deactivateServer(sender)
    hideWindow
    fix
    @ws.finish
  end

  def resetState
    @inputPat = ""
    @candidates = []
    @nthCand = 0
    @searchmode = 0
    @selectedstr = nil
  end

  def converting
    @inputPat.length > 0
  end

  #
  # キー入力などのイベントをすべて取得、必要なあらゆる処理を行なう
  # BS, Retなどが来ないこともあるのか?
  #
  def handleEvent(event, client:sender)
    # かなキーボードのコード
    kVirtual_JISRomanModeKey = 102
    kVirtual_JISKanaModeKey  = 104

    @client = sender
    # puts "handleEvent: event.type = #{event.type}"
    return false if event.type != NSKeyDown

    eventString = event.characters
    keyCode = event.keyCode
    modifierFlags = event.modifierFlags

    # 選択されている文字列があれば覚えておく
    # 後で登録に利用するかも
    range = @client.selectedRange
    astr = @client.attributedSubstringFromRange(range)
    if astr then
      s = astr.string
      @selectedstr = s if s != ""
    end

    return true if keyCode == kVirtual_JISKanaModeKey || keyCode == kVirtual_JISRomanModeKey
    return true if !eventString
    return true if eventString.length == 0

    handled = false

    # eventStringの文字コード取得
    # する方法がわからないので...
    s = sprintf("%s",eventString) # NSStringを普通のStringに??
    c = s.each_byte.to_a[0]

    #
    # スペース、バックスペース、通常文字などの処理
    #
    if c == 0x08 || c == 0x7f || c == 0x1b then
      if converting && @tmp_image_displayed && !@bs_through then
        @tmp_image_displayed = false
        Emulation.key(51) # Delete
        return true
      end
      if !@bs_through then
        if converting then
          if @nthCand > 0 then
            @nthCand -= 1
            showCands
          else
            @inputPat.sub!(/.$/,'')
            searchAndShowCands
          end
          handled = true
        end
      end
      @bs_through = false
    elsif c == 0x20 then
      if converting then
        if @tmp_image_displayed then
          Emulation.key("z", "command down") # undo
          Emulation.key(49)                  # SP
          
          @tmp_image_displayed = false
          return true
        end

        if @nthCand < @candidates.length-1 then
          @nthCand += 1
          showCands
        end
        handled = true
      end
    elsif c == 0x0a || c == 0x0d then
      if converting then
        if @tmp_image_displayed then
          @tmp_image_displayed = false
          resetState
          return true
        end
        if @searchmode > 0 then
          fix
        else
          if @nthCand == 0 then
            @searchmode = 1
            searchAndShowCands
          else
            fix
          end
        end
        handled = true
      end
    elsif c >= 0x21 && c <= 0x7e && (modifierFlags & (NSControlKeyMask|NSCommandKeyMask|NSAlternateKeyMask)) == 0 then
      fix if @nthCand > 0 || @searchmode > 0
      @inputPat += eventString
      searchAndShowCands
      @searchmode = 0
      handled = true
    end

    showWindow
    return handled
  end

  def wordpart(e) # 候補が[単語, 読み]のような配列で返ってくるとき単語部分だけ取得
    e.class == String ? e : e[0]
  end
  
  # 単語検索して候補の配列作成
  def searchAndShowCands
    #
    # WordSearch#search で検索して WordSearch#candidates で受け取る
    #
    # @searchmode == 0 前方マッチ
    # @searchmode == 1 完全マッチ ひらがな/カタカナも候補に加える
    #
    if @searchmode == 1 then
      @candidates = @ws.search(@inputPat,@searchmode)
      katakana = @inputPat.roma2katakana
      if katakana != "" then
        @candidates = @candidates.find_all { |e| wordpart(e) != katakana }
        @candidates.unshift(katakana)
      end
      hiragana = @inputPat.roma2hiragana
      if hiragana != "" then
        @candidates = @candidates.find_all { |e| wordpart(e) != hiragana }
        @candidates.unshift(hiragana)
      end
    else
      @candidates = @ws.search(@inputPat,@searchmode)
      @candidates.unshift(@selectedstr) if @selectedstr && @selectedstr !~ /^\s*$/ && @selectedstr !~ /[0-9a-f]{32}/i
      copytext = CopyText.get
      @candidates.unshift(copytext) if copytext != '' && Time.now - CopyText.time < 5 && copytext !~ /[0-9a-f]{32}/i
      @candidates.unshift(@inputPat)
      if @candidates.length < 8 then
        hiragana = @inputPat.roma2hiragana
        @candidates.push(hiragana)
      end
      @candidates.uniq!
    end
    @nthCand = 0
    showCands
  end

  def imagecand?(word) # wordがハッシュ値ならGyazoの画像候補だと判断
    word =~ /^[0-9a-f]{32}$/i
  end
  
  def fix
    if @candidates.length > @nthCand then
      word = wordpart(@candidates[@nthCand])
      if imagecand?(word) then
        if !@tmp_image_displayed then
          Emulation.key("v", "command down") # paste
        end
        @tmp_image_displayed = false
      else
        @client.insertText(word,replacementRange:NSMakeRange(NSNotFound, NSNotFound))
      end

      if word == @selectedstr then
        if @inputPat =~ /^(.*)\?$/ then # 暗号化単語登録
          @ws.register(Crypt.encrypt(word,$1).to_s,'?')
        else
          @ws.register(word,@inputPat)
        end
        @selectedstr = nil
      else
        c = @candidates[@nthCand]
        if c.class == Array then
          if c[1] != 'ds' && c[1] != '?' then
            @ws.study(c[0],c[1])
          end
        else
          # 読みが未登録 = ユーザ辞書に登録されていない
          if @inputPat != 'ds' && @inputPat != '?' then
            @ws.study(word,@inputPat)
          end
        end
      end
    end
      
    resetState
  end

  def showCands
    #
    # 選択中の単語をキャレット位置にアンダーライン表示
    #
    cands = @candidates.collect { |e|
      wordpart(e)
    }
    word = cands[@nthCand]
    if word then
      if imagecand?(word) then
        # 入力中モードじゃなくするためのハック
        @client.insertText(' ',replacementRange:NSMakeRange(NSNotFound, NSNotFound))
        @bs_through = true
        Emulation.key(51) # delete

        # 画像をペーストボードに貼る
        Image.pasteGyazoToPasteboard(word)
        
        # 画像をペースト
        Emulation.key("v","command down") # Cmd-v を送る

        @tmp_image_displayed = true
      else
        if @tmp_image_displayed then
          Emulation.key("z","command down") # undo

          @tmp_image_displayed = false
        end

        kTSMHiliteRawText = 2
        attr = self.markForStyle(kTSMHiliteRawText,atRange:NSMakeRange(0,word.length))
        attrstr = NSAttributedString.alloc.initWithString(word,attributes:attr)
        @client.setMarkedText(attrstr,selectionRange:NSMakeRange(word.length,0),replacementRange:NSMakeRange(NSNotFound, NSNotFound))
      end
    end
    #
    # 候補単語リストを表示
    #
    # @textview.setString(@cands[@nthCand+1 .. @nthCand+1+10].join(' '))
    @textview.setString('')
    (0..10).each { |i|
      cand = cands[@nthCand+1+i]
      break if cand.nil?
      if imagecand?(cand) then
        Image.pasteGyazoToTextView(cand,@textview)
      else
        @textview.insertText(cand)
      end
      @textview.insertText(' ')
    }
  end

  #
  # キャレットの位置に候補ウィンドウを出す
  #
  def showWindow
    # MacRubyでポインタを使う方法
    # http://d.hatena.ne.jp/Watson/20100823/1282543331
    lineRectP = Pointer.new('{CGRect={CGPoint=dd}{CGSize=dd}}')
    @client.attributesForCharacterIndex(0,lineHeightRectangle:lineRectP)
    lineRect = lineRectP[0]
    origin = lineRect.origin
    origin.x -= 15;
    origin.y -= 125;
    @candwin.setFrameOrigin(origin) if @candwin != nil
    NSApp.unhide(self)
  end

  def hideWindow
    NSApp.hide(self)
  end

  def GyaimController.showCands(candidates)
    @@gc.candidates = candidates
    @@gc.searchmode = 2 # こうなっていないとRet押したときsearchmodeが1になってしまう
    @@gc.showCands
  end
end
