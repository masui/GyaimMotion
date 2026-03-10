import Foundation

enum Config {
    static let gyaimDir: String = {
        let path = NSString("~/.gyaim").expandingTildeInPath
        return path
    }()

    static let cacheDir: String = {
        "\(gyaimDir)/cacheimages"
    }()

    static let imageDir: String = {
        "\(gyaimDir)/images"
    }()

    static let localDictFile: String = {
        "\(gyaimDir)/localdict.txt"
    }()

    static let studyDictFile: String = {
        "\(gyaimDir)/studydict.txt"
    }()

    static let copyTextFile: String = {
        "\(gyaimDir)/copytext"
    }()

    static func setup() {
        let fm = FileManager.default
        for dir in [gyaimDir, cacheDir, imageDir] {
            if !fm.fileExists(atPath: dir) {
                try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            }
        }
        for file in [localDictFile, studyDictFile] {
            if !fm.fileExists(atPath: file) {
                fm.createFile(atPath: file, contents: nil)
            }
        }
    }
}
