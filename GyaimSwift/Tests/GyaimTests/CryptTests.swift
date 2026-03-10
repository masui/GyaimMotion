import XCTest
@testable import Gyaim

final class CryptTests: XCTestCase {
    func testEncryptDecryptRoundTrip() {
        let original = "hello world"
        let salt = "password123"
        guard let encrypted = Crypt.encrypt(original, salt: salt) else {
            XCTFail("Encryption failed")
            return
        }
        guard let decrypted = Crypt.decrypt(encrypted, salt: salt) else {
            XCTFail("Decryption failed")
            return
        }
        XCTAssertEqual(decrypted, original)
    }

    func testEncryptDecryptJapanese() {
        let original = "日本語テスト"
        let salt = "mysalt"
        guard let encrypted = Crypt.encrypt(original, salt: salt) else {
            XCTFail("Encryption of Japanese text failed")
            return
        }
        guard let decrypted = Crypt.decrypt(encrypted, salt: salt) else {
            XCTFail("Decryption of Japanese text failed")
            return
        }
        XCTAssertEqual(decrypted, original)
    }

    func testDifferentSaltProducesDifferentResult() {
        let original = "secret"
        let enc1 = Crypt.encrypt(original, salt: "salt1")
        let enc2 = Crypt.encrypt(original, salt: "salt2")
        XCTAssertNotNil(enc1)
        XCTAssertNotNil(enc2)
        XCTAssertNotEqual(enc1, enc2)
    }

    func testWrongSaltDecryptionFails() {
        let original = "secret data"
        guard let encrypted = Crypt.encrypt(original, salt: "correctsalt") else {
            XCTFail("Encryption failed")
            return
        }
        let decrypted = Crypt.decrypt(encrypted, salt: "wrongsalt")
        // Decryption with wrong salt should produce different text
        XCTAssertNotEqual(decrypted, original)
    }

    func testEmptyString() {
        let encrypted = Crypt.encrypt("", salt: "salt")
        XCTAssertNotNil(encrypted)
        if let enc = encrypted {
            let decrypted = Crypt.decrypt(enc, salt: "salt")
            XCTAssertEqual(decrypted, "")
        }
    }

    func testMD5Hex() {
        // Known MD5 hash of empty string
        XCTAssertEqual(Crypt.md5Hex(""), "d41d8cd98f00b204e9800998ecf8427e")
        // Known MD5 hash of "hello"
        XCTAssertEqual(Crypt.md5Hex("hello"), "5d41402abc4b2a76b9719d911017c592")
    }
}
