import Foundation

/// Bidirectional romaji-kana conversion engine.
/// Ported from Romakana.rb (Toshiyuki Masui, 2011)
struct RomaKana {
    // Roma -> single kana mapping
    private let romaToHiragana: [String: String]
    private let romaToKatakana: [String: String]
    // Kana -> multiple roma mappings
    private let hiraganaToRoma: [String: [String]]
    private let katakanaToRoma: [String: [String]]

    // Sorted roma keys by length descending for greedy matching
    private let sortedHiraKeys: [String]
    private let sortedKataKeys: [String]

    init() {
        var hrk: [String: String] = [:]
        var krk: [String: String] = [:]
        var hkr: [String: [String]] = [:]
        var kkr: [String: [String]] = [:]

        for line in Self.rklist.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("#") || s.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let parts = s.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }
            let roma = String(parts[0])
            let hira = String(parts[1])
            let kata = String(parts[2])

            hrk[roma] = hira
            krk[roma] = kata
            hkr[hira, default: []].append(roma)
            kkr[kata, default: []].append(roma)
        }

        self.romaToHiragana = hrk
        self.romaToKatakana = krk
        self.hiraganaToRoma = hkr
        self.katakanaToRoma = kkr
        self.sortedHiraKeys = hrk.keys.sorted { $0.count > $1.count }
        self.sortedKataKeys = krk.keys.sorted { $0.count > $1.count }
    }

    // MARK: - Roma to Kana

    func roma2hiragana(_ roma: String) -> String {
        return romaToKana(roma, map: romaToHiragana, sortedKeys: sortedHiraKeys,
                          tsu: "ん", smallTsu: "っ", isHiragana: true)
    }

    func roma2katakana(_ roma: String) -> String {
        return romaToKana(roma, map: romaToKatakana, sortedKeys: sortedKataKeys,
                          tsu: "ン", smallTsu: "ッ", isHiragana: false)
    }

    private func romaToKana(_ roma: String, map: [String: String],
                             sortedKeys: [String],
                             tsu: String, smallTsu: String,
                             isHiragana: Bool) -> String {
        var kana = ""
        var ind = roma.startIndex

        while ind < roma.endIndex {
            var found = false
            for key in sortedKeys {
                let remaining = roma[ind...]
                if remaining.hasPrefix(key) {
                    kana += map[key]!
                    ind = roma.index(ind, offsetBy: key.count)
                    found = true
                    break
                }
            }
            if !found {
                let r0 = String(roma[ind])
                let r1Index = roma.index(after: ind)
                let r1: String? = r1Index < roma.endIndex ? String(roma[r1Index]) : nil

                let consonants = "bcdfghjklmnpqrstvwxz"
                if (r0 == "n" || r0 == "N"), let r1, consonants.contains(r1) {
                    kana += tsu  // "ん" / "ン"
                    ind = roma.index(after: ind)
                } else {
                    let doubleConsonants = "bcdfghjklmpqrstvwxyz"
                    if doubleConsonants.contains(r0), let r1, r0 == r1 {
                        kana += smallTsu  // "っ" / "ッ"
                        ind = roma.index(after: ind)
                    } else if (r0 == "n" || r0 == "N"), r1 == nil {
                        kana += tsu  // "ん" / "ン"
                        ind = roma.index(after: ind)
                    } else {
                        ind = roma.index(after: ind)
                    }
                }
            }
        }
        return kana
    }

    // MARK: - Kana to Roma

    func hiragana2roma(_ s: String) -> [String] {
        let results = krexpand(prefix: "", remaining: s, tsu: nil, kr: hiraganaToRoma)
        let filtered = results.filter { !$0.contains("ix") && !$0.contains("ux") }
        return filtered.isEmpty ? results : filtered
    }

    func katakana2roma(_ s: String) -> [String] {
        let results = krexpand(prefix: "", remaining: s, tsu: nil, kr: katakanaToRoma)
        let filtered = results.filter { !$0.contains("ix") && !$0.contains("ux") }
        return filtered.isEmpty ? results : filtered
    }

    /// Recursive expansion of kana to romaji.
    /// Mirrors the Ruby krexpand method.
    private func krexpand(prefix a: String, remaining b: String, tsu: Character?,
                          kr: [String: [String]]) -> [String] {
        var result: [String] = []

        if let t = tsu {
            // Processing っ/ッ: double the first consonant of the next kana
            let chars = Array(b)
            if !chars.isEmpty {
                let k = String(chars[0])
                if let rs = kr[k] {
                    for r in rs {
                        if let first = r.first, "bcdfghjklmpqrstvwxyz".contains(first) {
                            result += krexpand(prefix: a + String(first), remaining: b,
                                               tsu: nil, kr: kr)
                        } else {
                            if let tsuRomas = kr[String(t)] {
                                for rr in tsuRomas {
                                    result += krexpand(prefix: a + rr, remaining: b,
                                                       tsu: nil, kr: kr)
                                }
                            }
                        }
                    }
                }
            } else {
                if let tsuRomas = kr[String(t)] {
                    for r in tsuRomas {
                        result.append(a + r)
                    }
                }
            }
            return result
        }

        if b.isEmpty {
            var cleaned = a
            // n' before consonant → n
            let consonantPattern = "bcdfghjklmnpqrstvwxz"
            // Replace n'<consonant> with n<consonant>
            while let range = cleaned.range(of: "n'", options: .literal) {
                let afterRange = cleaned.index(range.upperBound, offsetBy: 0)
                if afterRange < cleaned.endIndex {
                    let nextChar = cleaned[afterRange]
                    if consonantPattern.contains(nextChar) {
                        cleaned.replaceSubrange(range, with: "n")
                        continue
                    }
                }
                // n' at end → n
                if afterRange == cleaned.endIndex {
                    cleaned.replaceSubrange(range, with: "n")
                    continue
                }
                break
            }
            result.append(cleaned)
            return result
        }

        let chars = Array(b)

        // Try 3-char kana (e.g. "う゛ぁ")
        if chars.count >= 3 {
            let k3 = String(chars[0...2])
            if kr[k3] != nil {
                let rest = String(b.dropFirst(3))
                if let rs = kr[k3] {
                    for r in rs {
                        result += krexpand(prefix: a + r, remaining: rest, tsu: nil, kr: kr)
                    }
                }
            }
        }

        // Try 2-char kana (e.g. "しゃ")
        if chars.count >= 2 {
            let k2 = String(chars[0...1])
            if kr[k2] != nil {
                let rest = String(b.dropFirst(2))
                if let rs = kr[k2] {
                    for r in rs {
                        result += krexpand(prefix: a + r, remaining: rest, tsu: nil, kr: kr)
                    }
                }
            }
        }

        // Try 1-char kana
        if !chars.isEmpty {
            let k1 = String(chars[0])
            let rest = String(b.dropFirst(1))
            if let rs = kr[k1], k1 != "っ" && k1 != "ッ" {
                for r in rs {
                    result += krexpand(prefix: a + r, remaining: rest, tsu: nil, kr: kr)
                }
            }
            if k1 == "っ" || k1 == "ッ" {
                result += krexpand(prefix: a, remaining: rest, tsu: chars[0], kr: kr)
            }
        }

        return result
    }

    // MARK: - RKLIST Data

    static let rklist = """
    #
    #\tstandard rklist
    #
    a\tあ\tア
    ba\tば\tバ
    be\tべ\tベ
    bi\tび\tビ
    bo\tぼ\tボ
    bu\tぶ\tブ
    bya\tびゃ\tビャ
    bye\tびぇ\tビェ
    byi\tびぃ\tビィ
    byo\tびょ\tビョ
    byu\tびゅ\tビュ
    cha\tちゃ\tチャ
    che\tちぇ\tチェ
    chi\tち\tチ
    cho\tちょ\tチョ
    chu\tちゅ\tチュ
    da\tだ\tダ
    de\tで\tデ
    dha\tでゃ\tデャ
    dhe\tでぇ\tデェ
    dhi\tでぃ\tディ
    dho\tでょ\tデョ
    dhu\tでゅ\tデュ
    di\tぢ\tヂ
    do\tど\tド
    du\tづ\tヅ
    dya\tぢゃ\tヂャ
    dye\tぢぇ\tヂェ
    dyi\tぢぃ\tヂィ
    dyo\tぢょ\tヂョ
    dyu\tでゅ\tデュ
    e\tえ\tエ
    fa\tふぁ\tファ
    fe\tふぇ\tフェ
    fi\tふぃ\tフィ
    fo\tふぉ\tフォ
    fuxyu\tふゅ\tフュ
    fu\tふ\tフ
    ga\tが\tガ
    ge\tげ\tゲ
    gi\tぎ\tギ
    go\tご\tゴ
    gu\tぐ\tグ
    gya\tぎゃ\tギャ
    gye\tぎぇ\tギェ
    gyi\tぎぃ\tギィ
    gyo\tぎょ\tギョ
    gyu\tぎゅ\tギュ
    ha\tは\tハ
    he\tへ\tヘ
    hi\tひ\tヒ
    ho\tほ\tホ
    hu\tふ\tフ
    hya\tひゃ\tヒャ
    hye\tひぇ\tヒェ
    hyi\tひぃ\tヒィ
    hyo\tひょ\tヒョ
    hyu\tひゅ\tヒュ
    i\tい\tイ
    ja\tじゃ\tジャ
    je\tじぇ\tジェ
    ji\tじ\tジ
    jo\tじょ\tジョ
    ju\tじゅ\tジュ
    ka\tか\tカ
    ke\tけ\tケ
    ki\tき\tキ
    ko\tこ\tコ
    ku\tく\tク
    kya\tきゃ\tキャ
    kye\tきぇ\tキェ
    kyi\tきぃ\tキィ
    kyo\tきょ\tキョ
    kyu\tきゅ\tキュ
    ma\tま\tマ
    me\tめ\tメ
    mi\tみ\tミ
    mo\tも\tモ
    mu\tむ\tム
    mya\tみゃ\tミャ
    mye\tみぇ\tミェ
    myi\tみぃ\tミィ
    myo\tみょ\tミョ
    myu\tみゅ\tミュ
    nn\tん\tン
    na\tな\tナ
    ne\tね\tネ
    ni\tに\tニ
    no\tの\tノ
    nu\tぬ\tヌ
    nya\tにゃ\tニャ
    nye\tにぇ\tニェ
    nyi\tにぃ\tニィ
    nyo\tにょ\tニョ
    nyu\tにゅ\tニュ
    o\tお\tオ
    pa\tぱ\tパ
    pe\tぺ\tペ
    pi\tぴ\tピ
    po\tぽ\tポ
    pu\tぷ\tプ
    pya\tぴゃ\tピャ
    pye\tぴぇ\tピェ
    pyi\tぴぃ\tピィ
    pyo\tぴょ\tピョ
    pyu\tぴゅ\tピュ
    ra\tら\tラ
    re\tれ\tレ
    ri\tり\tリ
    ro\tろ\tロ
    ru\tる\tル
    rya\tりゃ\tリャ
    rye\tりぇ\tリェ
    ryi\tりぃ\tリィ
    ryo\tりょ\tリョ
    ryu\tりゅ\tリュ
    sa\tさ\tサ
    se\tせ\tセ
    sha\tしゃ\tシャ
    she\tしぇ\tシェ
    shi\tし\tシ
    sho\tしょ\tショ
    shu\tしゅ\tシュ
    si\tし\tシ
    so\tそ\tソ
    su\tす\tス
    sya\tしゃ\tシャ
    sye\tしぇ\tシェ
    syi\tしぃ\tシィ
    syo\tしょ\tショ
    syu\tしゅ\tシュ
    ta\tた\tタ
    te\tて\tテ
    tha\tてゃ\tテャ
    the\tてぇ\tテェ
    thi\tてぃ\tティ
    tho\tてょ\tテョ
    thu\tてゅ\tテュ
    ti\tち\tチ
    to\tと\tト
    tsu\tつ\tツ
    tu\tつ\tツ
    tya\tちゃ\tチャ
    tye\tちぇ\tチェ
    tyi\tちぃ\tチィ
    tyo\tちょ\tチョ
    tyu\tちゅ\tチュ
    u\tう\tウ
    va\tう゛ぁ\tヴァ
    ve\tう゛ぃ\tヴェ
    vi\tう゛ぅ\tヴィ
    vo\tう゛ぉ\tヴォ
    vu\tう゛\tヴ
    wa\tわ\tワ
    we\tうぇ\tウェ
    wi\tうぃ\tウィ
    wo\tを\tヲ
    xa\tぁ\tァ
    xe\tぇ\tェ
    xi\tぃ\tィ
    xo\tぉ\tォ
    xtu\tっ\tッ
    xtsu\tっ\tッ
    xu\tぅ\tゥ
    xwa\tゎ\tヮ
    ya\tや\tヤ
    yo\tよ\tヨ
    yu\tゆ\tユ
    za\tざ\tザ
    ze\tぜ\tゼ
    zi\tじ\tジ
    zo\tぞ\tゾ
    zu\tず\tズ
    zya\tじゃ\tジャ
    zye\tじぇ\tジェ
    zyi\tじぃ\tジィ
    zyo\tじょ\tジョ
    zyu\tじゅ\tジュ
    xya\tゃ\tャ
    xyu\tゅ\tュ
    xyo\tょ\tョ
    -\tー\tー
    ?\t？\t？
    !\t！\t！
    .\t。\t。
    ,\t、\t、
    /\t・\t・
    ~\t〜\t〜
    [\t「\t「
    ]\t」\t」
    (\t（\t（
    )\t）\t）
    """
}
