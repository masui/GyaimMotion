import XCTest
@testable import Gyaim

final class RomaKanaTests: XCTestCase {
    let rk = RomaKana()

    // MARK: - roma2hiragana

    func testBasicRoma2Hiragana() {
        XCTAssertEqual(rk.roma2hiragana("masui"), "ますい")
    }

    func testRoma2HiraganaSingleVowels() {
        XCTAssertEqual(rk.roma2hiragana("a"), "あ")
        XCTAssertEqual(rk.roma2hiragana("i"), "い")
        XCTAssertEqual(rk.roma2hiragana("u"), "う")
        XCTAssertEqual(rk.roma2hiragana("e"), "え")
        XCTAssertEqual(rk.roma2hiragana("o"), "お")
    }

    func testRoma2HiraganaNN() {
        XCTAssertEqual(rk.roma2hiragana("nn"), "ん")
        XCTAssertEqual(rk.roma2hiragana("hannnya"), "はんにゃ")
    }

    func testRoma2HiraganaNBeforeConsonant() {
        XCTAssertEqual(rk.roma2hiragana("kanka"), "かんか")
        XCTAssertEqual(rk.roma2hiragana("senpai"), "せんぱい")
    }

    func testRoma2HiraganaDoubleTsu() {
        XCTAssertEqual(rk.roma2hiragana("kitto"), "きっと")
        XCTAssertEqual(rk.roma2hiragana("gakkari"), "がっかり")
    }

    func testRoma2HiraganaLongWord() {
        XCTAssertEqual(rk.roma2hiragana("toukyou"), "とうきょう")
    }

    func testRoma2HiraganaSha() {
        XCTAssertEqual(rk.roma2hiragana("sha"), "しゃ")
        XCTAssertEqual(rk.roma2hiragana("chi"), "ち")
        XCTAssertEqual(rk.roma2hiragana("tsu"), "つ")
    }

    func testRoma2HiraganaNAtEnd() {
        XCTAssertEqual(rk.roma2hiragana("san"), "さん")
    }

    // MARK: - roma2katakana

    func testBasicRoma2Katakana() {
        XCTAssertEqual(rk.roma2katakana("vaiorinn"), "ヴァイオリン")
    }

    func testRoma2KatakanaDoubleTsu() {
        XCTAssertEqual(rk.roma2katakana("katto"), "カット")
    }

    // MARK: - hiragana2roma

    func testBasicHiragana2Roma() {
        let results = rk.hiragana2roma("ますい")
        XCTAssertTrue(results.contains("masui"), "Expected 'masui' in \(results)")
    }

    func testHiragana2RomaMultiple() {
        let results = rk.hiragana2roma("じしょ")
        XCTAssertTrue(results.contains("jisho") || results.contains("zisho"),
                       "Expected jisho/zisho variant in \(results)")
    }

    // MARK: - katakana2roma

    func testBasicKatakana2Roma() {
        let results = rk.katakana2roma("ヴァイオリン")
        XCTAssertTrue(results.contains("vaiorinn"), "Expected 'vaiorinn' in \(results)")
    }

    // MARK: - Round-trip

    func testRoundTripSimple() {
        // Words where roma->hira->roma round-trips exactly
        let words = ["masui", "toukyou", "kitto", "sha", "chi"]
        for word in words {
            let hira = rk.roma2hiragana(word)
            let back = rk.hiragana2roma(hira)
            XCTAssertTrue(back.contains(word),
                          "Round-trip failed for '\(word)': hira='\(hira)', back=\(back)")
        }
    }

    func testNBeforeConsonantRoundTrip() {
        // "senpai" uses abbreviated 'n' before consonant, reverse always produces "nn"
        let hira = rk.roma2hiragana("senpai")
        XCTAssertEqual(hira, "せんぱい")
        let back = rk.hiragana2roma(hira)
        XCTAssertTrue(back.contains("sennpai"), "Expected 'sennpai' in \(back)")
    }

    // MARK: - Edge cases

    func testEmptyString() {
        XCTAssertEqual(rk.roma2hiragana(""), "")
        XCTAssertEqual(rk.roma2katakana(""), "")
    }

    func testDash() {
        XCTAssertEqual(rk.roma2hiragana("-"), "ー")
        XCTAssertEqual(rk.roma2katakana("-"), "ー")
    }

    func testSmallKana() {
        XCTAssertEqual(rk.roma2hiragana("xtu"), "っ")
        XCTAssertEqual(rk.roma2hiragana("xa"), "ぁ")
    }
}
