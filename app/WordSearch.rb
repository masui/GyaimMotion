# -*- coding: utf-8 -*-
#
# Created by Toshiyuki Masui on 2011/3/15.
# Modified by Toshiyuki Masui on 2015/9/8.
#
# Copyright 2011-2015 Pitecan Systems. All rights reserved.
#
class WordSearch
  def initialize(connectionDictFile, localDictFile, studyDictFile)
    @connectionDictFile = connectionDictFile # 接続辞書
    @localDictFile = localDictFile           # 個人用ローカル辞書
    @studyDictFile = studyDictFile           # 学習辞書
    
    # 固定辞書(接続辞書)初期化
    @cd = ConnectionDict.new(connectionDictFile)

    # 個人辞書を読出し
    @localdict = loadDict(localDictFile)
    @localdicttime = File.mtime(localDictFile)

    # 学習辞書を読出し
    @studydict = loadDict(studyDictFile)
  end

  def search(q,searchmode,limit=10)
    @searchmode = searchmode  # @searchmode=0のとき前方マッチ, @searchmode=1のとき完全マッチ

    return [] if q.nil? || q == ''

    # 別システムによりlocalDictが更新されたときは読み直す
    if File.mtime(@localDictFile) > @localdicttime then
      @localdict = loadDict(@localDictFile)
    end

    candfound = {}
    candidates = []

    if q.length > 1 && q.sub!(/\.$/,'') then
      # パタンの最後にピリオドが入力されたらGoogle検索.
      # Google.searchCands()は非同期関数なので、実際にはその中で
      # showCandsが呼ばれる.
      candidates = Google.searchCands(q)
    elsif q =~ /^(.*)\#$/ then
      #
      # 色指定した画像を入力
      #
      color = $1
      tmpfile = "/tmp/gyaim_#{$$}.png"
      Image.generatePNG(tmpfile,color,40,40)
      data = File.read(tmpfile)
      id = MD5.digest(data)
      Files.move(tmpfile,"#{Config.imageDir}/#{id}.png")
      Image.generatePNG("#{Config.imageDir}/#{id}s.png",color,20,20)
      candidates << id
      
      #
      # 色指定
      #
      #color = $1
      #if color =~ /^([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])$/ then
      #  r = $1.hex
      #  g = $2.hex
      #  b = $3.hex
      #  data = [[[r,g,b]] * 40] * 40
      #  pnglarge = PNG.png(data)
      #  data = [[[r,g,b]] * 20] * 20
      #  pngsmall = PNG.png(data)
      #  id = Digest::MD5.hexdigest(pnglarge)
      #  File.open("#{Config.imageDir}/#{id}.png","w"){ |f|
      #    f.print pnglarge
      #  }
      #  File.open("#{Config.imageDir}/#{id}s.png","w"){ |f|
      #    f.print pngsmall
      #  }
      #  candidates << id
      #end
    elsif q =~ /^(.+)!$/ then
      ids = Google.searchImages($1)
      ids.each { |id|
        candidates << id
      }
    elsif q == "ds" then # TimeStamp or DateStamp(?)
      candidates << Time.now.strftime('%Y/%m/%d %H:%M:%S')
    elsif q.length > 1 && q =~ /^(.*)\?$/ then  # 個人辞書の中から暗号化された単語だけ抽出
      pat = $1
      @localdict.each { |entry|
        yomi = entry[0]
        word = entry[1]
        if yomi == '?' then # 暗号化された単語は読みが「?」になってる
          if !candfound[word] then
            # decryptしたバイト列が漢字だとうまくいかない...★★修正必要
            word = Crypt.decrypt(word,pat)
            if word then
              candidates << [word, yomi]
              candfound[word] = true
              break if candidates.length > limit
            end
          end
        end
      }
    elsif q =~ /[A-Z]/ then
      # 読みが大文字を含む場合は候補に入れる
      candidates << [q, q]
    else
      # 普通に検索
      qq = q.gsub(/[\.\{\}\[\]\(\)]/){ '\\' + $& }
      pat = Regexp.new(@searchmode > 0 ? "^#{qq}$" : "^#{qq}")

      # 超単純な辞書検索
      (@studydict + @localdict).each { |entry|
        yomi = entry[0]
        word = entry[1]
        if pat.match(yomi) then
          if !candfound[word] then
            candidates << [word, yomi]
            candfound[word] = true
            break if candidates.length > limit
          end
        end
      }
      # 接続辞書検索
      @cd.search(q,@searchmode){ |word,pat,outc|
        next if word =~ /\*$/
        word.gsub!(/\*/,'')
        if !candfound[word] then
          candidates << [word, pat]
          candfound[word] = true
          break if candidates.length > limit
        end
      }
    end
    candidates
  end

  #
  # ユーザ辞書登録
  #
  def register(word,yomi)
    @localdict.delete [yomi,word]
    @localdict.unshift [yomi,word]
    saveDict @localDictFile, @localdict
    @localdicttime = File.mtime @localDictFile
  end

  #
  # 学習辞書の扱い
  #
  def study(word,yomi)
    if yomi.length > 1 then  # 間違って変な単語を登録しないように
      registered = false
      @cd.search(yomi,@searchmode){ |w,p,outc|
        next if w =~ /\*$/
        w.gsub!(/\*/,'')
        if w == word
          registered = true
          break
        end
      }
      if !registered then # 学習辞書に入っている単語をもう一度確定するとローカル辞書に登録
        register(word,yomi) if @studydict.index [yomi,word]
      end
    end

    @studydict.unshift [yomi,word]
    @studydict = @studydict[0..1000]  # 学習辞書サイズは1000行に制限
  end

  def loadDict(dictfile)
    dict = []
    if File.exist?(dictfile) then
      File.open(dictfile){ |f|
        f.each { |line|
          next if line =~ /^#/ || line =~ /^\s*$/
          (yomi,word) = line.chomp.split(/\t/)
          dict << [yomi, word] if yomi && word
        }
      }
    end
    dict
  end

  def saveDict(dictfile,dict)
    saved = {}
    File.open(dictfile,"w"){ |f|
      dict.each { |entry|
        yomi = entry[0]
        word = entry[1]
        s = "#{yomi}\t#{word}"
        if !saved[s] then
          f.puts s
          saved[s] = true
        end
      }
    }
  end

  def start
    # 変換ウィンドウが出るときにこれを読んでいるのだが、これを
    # 実行すると変換が遅れて文字をとりこぼしてしまう。
    # たいした処理をしてないのに何故だろうか?
    # Thread.new do
    #  @studydict = loadDict(@studyDictFile)
    # end
    # どうしても駄目なのでロードするのをやめる。再ロードしたいときはKillすることに...
  end

  def finish
    saveDict(@studyDictFile,@studydict)
  end
end
