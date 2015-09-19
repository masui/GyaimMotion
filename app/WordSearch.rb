# -*- coding: utf-8 -*-
#
# Created by Toshiyuki Masui on 2011/3/15.
# Modified by Toshiyuki Masui on 2015/9/8.
#
# Copyright 2011-2015 Pitecan Systems. All rights reserved.
#
class WordSearch
  attr :searchmode, true

  def downloadImage(url)
    downloaded = {}
    marshalfile = "#{Files.cacheDir}/downloaded"
    if File.exist?(marshalfile) then
      downloaded = Marshal.load(File.read(marshalfile))
    end
    if !downloaded[url] then
      begin
        # system "/usr/local/bin/wget #{url} -O #{Files.cacheDir}/tmpimage > /dev/null >& /dev/null"
        # url がmoved permanentlyとかじゃなければいいのだけど
        AFMotion::HTTP.get(url) do |result|
          File.open("#{Files.cacheDir}/tmpimage","w"){ |f|
            f.print result.object
          }
        end
        system "sips -s format png #{Files.cacheDir}/tmpimage --resampleHeight 100 --out #{Files.cacheDir}/tmpimage.png > /dev/null >& /dev/null"
        # system "sips --resampleHeight 50 #{Files.cacheDir}/tmpimage.png > /dev/null >& /dev/null"
        imagedata = File.read("#{Files.cacheDir}/tmpimage.png")
        id = Digest::MD5.hexdigest(imagedata)
        system "/bin/mv #{Files.cacheDir}/tmpimage.png #{Files.cacheDir}/#{id}.png"
        system "/bin/cp #{Files.cacheDir}/#{id}.png #{Files.cacheDir}/#{id}s.png"
        system "/usr/bin/sips --resampleHeight 20 #{Files.cacheDir}/#{id}s.png > /dev/null >& /dev/null"
        downloaded[url] = id
      rescue
        res = false
      end
    end
    File.open(marshalfile,"w"){ |f|
      f.print Marshal.dump(downloaded)
    }
    downloaded[url]
  end
  
  #
  # Google検索
  #
  def searchGoogleImages(q)
    ids = []
    server = 'ajax.googleapis.com'
    command = "/ajax/services/search/images?q=#{q}&v=1.0&rsz=large&start=1"
    Net::HTTP.start(server, 80) {|http|
      response = http.get(command)
      json = BubbleWrap::JSON.parse(response.body)
      images = json['responseData']['results']
      images.each { |image|
        url = image['url']
        if id = downloadImage(url) then
          ids << id
        end
      }
    }
    puts ids
    ids
  end

  # dict = NSBundle.mainBundle.pathForResource("dict", ofType:"txt")
  # dict = "../Resources/dict.txt"
  def initialize(dictfile)
    @searchmode = 0
    Dir.mkdir(Files.gyaimDir) unless File.exist?(Files.gyaimDir)
    Dir.mkdir(Files.cacheDir) unless File.exist?(Files.cacheDir)
    Dir.mkdir(Files.imageDir) unless File.exist?(Files.imageDir)
    File.open(Files.localDictFile,"w"){ |f| f.print "" } unless File.exist?(Files.localDictFile)
    File.open(Files.studyDictFile,"w"){ |f| f.print "" } unless File.exist?(Files.studyDictFile)

    # 固定辞書初期化
    @cd = ConnectionDict.new(dictfile)

    # 個人辞書を読出し
    @localdict = loadDict(Files.localDictFile)
    @localdicttime = File.mtime(Files.localDictFile)

    # 学習辞書を読出し
    @studydict = loadDict(Files.studyDictFile)
  end

  def search(q,limit=10)
    # @searchmode=0のとき前方マッチ, @searchmode=1のとき完全マッチとする

    return if q.nil? || q == ''

    # 別システムによりlocalDictが更新されたときは読み直す
    if File.mtime(Files.localDictFile) > @localdicttime then
      @localdict = loadDict(Files.localDictFile)
    end

    candfound = {}
    @candidates = []

    if q.length > 1 && q.sub!(/\.$/,'') then
      # パタンの最後にピリオドが入力されたらGoogle Suggestを検索
      registered = {}
      words = []

      # Google Suggest API ... 何度も使ってると拒否られるようになった
      #Net::HTTP.start('google.co.jp', 80) {|http|
      #  response = http.get("/complete/search?output=toolbar&hl=ja&q=#{q}",header)
      #  s = response.body.to_s
      #  s = NKF.nkf('-w',s)
      #  while s.sub!(/data="([^"]*)"\/>/,'') do
      #    word = $1.split[0]
      #    if !candfound[word] then
      #      candfound[word] = 1
      #      @candidates << word
      #    end
      #  end
      #}

      AFMotion::JSON.get("http://google.com/transliterate", {langpair: "ja-Hira|ja", text: q.roma2hiragana}) do |result|
        result.object[0][1].each { |candword|
          if !candfound[candword] then
            candfound[candword] = 1
            @candidates << candword
          end
        }
        GyaimController.showCands # AFMotionが非同期なのでここで更新!
      end
    elsif q =~ /^(.*)\#$/ then
      #
      # 色指定
      #
      color = $1
      if color =~ /^([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])$/ then
        r = $1.hex
        g = $2.hex
        b = $3.hex
        data = [[[r,g,b]] * 40] * 40
        pnglarge = PNG.png(data)
        data = [[[r,g,b]] * 20] * 20
        pngsmall = PNG.png(data)
        id = Digest::MD5.hexdigest(pnglarge)
        File.open("#{Files.imageDir}/#{id}.png","w"){ |f|
          f.print pnglarge
        }
        File.open("#{Files.imageDir}/#{id}s.png","w"){ |f|
          f.print pngsmall
        }
        @candidates << id
      end
    elsif q =~ /^(.+)!$/ then
      #
      # Google画像検索
      #
      ids = searchGoogleImages($1)
      ids.each { |id|
        @candidates << id
      }
    elsif q == "ds" then # TimeStamp or DateStamp(?)
      @candidates << Time.now.strftime('%Y/%m/%d %H:%M:%S')
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
              @candidates << [word, yomi]
              candfound[word] = true
              break if @candidates.length > limit
            end
          end
        end
      }
    elsif q =~ /[A-Z]/ then
      # 読みが大文字を含む場合は候補に入れる
      @candidates << [q, q]
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
            @candidates << [word, yomi]
            candfound[word] = true
            break if @candidates.length > limit
          end
        end
      }
      # 接続辞書検索
      @cd.search(q,@searchmode){ |word,pat,outc|
        next if word =~ /\*$/
        word.gsub!(/\*/,'')
        if !candfound[word] then
          @candidates << [word, pat]
          candfound[word] = true
          break if @candidates.length > limit
        end
      }
    end
  end
  
  def candidates
    @candidates
  end

  #
  # ユーザ辞書登録
  #
  def register(word,yomi)
    puts "register(#{word},#{yomi})"
    if !@localdict.index([yomi,word]) then
      @localdict.unshift([yomi,word])
      saveDict(Files.localDictFile,@localdict)
      @localdicttime = File.mtime(Files.localDictFile)
    end
  end

  #
  # 学習辞書の扱い
  #
  def study(word,yomi)
    # puts "study(#{word},#{yomi})"
    if yomi.length > 1 then                    # (間違って変な単語を登録しないように)
      registered = false
      @cd.search(yomi,@searchmode){ |w,p,outc|
        next if w =~ /\*$/
        w.gsub!(/\*/,'')
        if w == word
          registered = true
          break
        end
      }
      if !registered then
        #      if ! @dc[yomi].index([yomi,word]) then   # 固定辞書に入ってない
        if @studydict.index([yomi,word]) then  # しかし学習辞書に入っている
          register(word,yomi)                  # ならば登録してしまう
        end
      end
    end

    @studydict.unshift([yomi,word])
    @studydict = @studydict[0..1000] # 1000行に制限
  end

  def loadDict(dictfile)
    dict = []
    if File.exist?(dictfile) then
      File.open(dictfile){ |f|
        f.each { |line|
          next if line =~ /^#/
          next if line =~ /^\s*$/
          line.chomp!
          (yomi,word) = line.split(/\t/)
          if yomi && word then
            dict << [yomi, word]
          end
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
    #  @studydict = loadDict(Files.studyDictFile)
    # end
    # どうしても駄目なのでロードするのをやめる。再ロードしたいときはKillすることに...
  end

  def finish
    saveDict(Files.studyDictFile,@studydict)
  end

end

if __FILE__ == $0 && nil then
  ws = WordSearch.new("/Users/masui/Gyaim/Resources/dict.txt")
  ws.search("masui")
  puts ws.candidates
  ws.search("kanj")
  puts ws.candidates
end
