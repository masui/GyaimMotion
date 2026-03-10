import Foundation

struct DictEntry {
    let pat: String
    let word: String
    let inConnection: Int
    let outConnection: Int
    var keyLink: Int?
    var connectionLink: Int?
}

/// Morphological connection dictionary for compound word matching.
/// Ported from ConnectionDict.rb (Toshiyuki Masui, 2011)
class ConnectionDict {
    private var dict: [DictEntry] = []
    private var keyLink: [Int: Int] = [:]        // first char unicode scalar -> dict index
    private var connectionLink: [Int: Int] = [:]  // inConnection value -> dict index

    init(dictFile: String) {
        readDict(dictFile)
        initLink()
    }

    private func readDict(_ path: String) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(line)
            if s.hasPrefix("#") || s.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let parts = s.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 2 else { continue }
            let pat = String(parts[0])
            let word = String(parts[1])
            let inConn = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
            let outConn = parts.count > 3 ? Int(parts[3]) ?? 0 : 0
            dict.append(DictEntry(pat: pat, word: word,
                                  inConnection: inConn, outConnection: outConn))
        }
    }

    private func initLink() {
        // Build keyLink: first character → linked list through dict
        var curKey: [Int: Int] = [:]
        for i in 0..<dict.count {
            if dict[i].word.hasPrefix("*") { continue }
            guard let firstScalar = dict[i].pat.unicodeScalars.first else { continue }
            let ind = Int(firstScalar.value)
            if keyLink[ind] == nil {
                keyLink[ind] = i
                curKey[ind] = i
            } else {
                dict[curKey[ind]!].keyLink = i
                curKey[ind] = i
            }
            dict[i].keyLink = nil
        }

        // Build connectionLink: inConnection → linked list through dict
        var curConn: [Int: Int] = [:]
        for i in 0..<dict.count {
            let ind = dict[i].inConnection
            if connectionLink[ind] == nil {
                connectionLink[ind] = i
                curConn[ind] = i
            } else {
                dict[curConn[ind]!].connectionLink = i
                curConn[ind] = i
            }
            dict[i].connectionLink = nil
        }
    }

    /// Search the dictionary for matches.
    /// - Parameters:
    ///   - pat: Input romaji pattern
    ///   - searchMode: 0 = prefix matching, 1 = exact matching
    ///   - callback: (word, matchedPat, outConnection) for each result
    func search(pat: String, searchMode: Int,
                callback: (_ word: String, _ pat: String, _ outConnection: Int) -> Void) {
        generateCand(connection: nil, pat: pat, foundWord: "", foundPat: "",
                     searchMode: searchMode, callback: callback)
    }

    private func generateCand(connection: Int?, pat: String,
                               foundWord: String, foundPat: String,
                               searchMode: Int,
                               callback: (_ word: String, _ pat: String, _ outConnection: Int) -> Void) {
        guard let firstScalar = pat.unicodeScalars.first else { return }
        var d: Int?
        if let conn = connection {
            d = connectionLink[conn]
        } else {
            d = keyLink[Int(firstScalar.value)]
        }

        while let idx = d {
            let entry = dict[idx]
            if pat == entry.pat {
                // Exact match
                callback(foundWord + entry.word, foundPat + entry.pat, entry.outConnection)
            } else if entry.pat.hasPrefix(pat) {
                // Dict entry starts with pattern (prefix match)
                if searchMode == 0 {
                    callback(foundWord + entry.word, foundPat + entry.pat, entry.outConnection)
                }
            } else if pat.hasPrefix(entry.pat) {
                // Pattern starts with dict entry (potential compound via connection)
                let restPat = String(pat.dropFirst(entry.pat.count))
                generateCand(connection: entry.outConnection, pat: restPat,
                             foundWord: foundWord + entry.word,
                             foundPat: foundPat + entry.pat,
                             searchMode: searchMode, callback: callback)
            }

            if connection != nil {
                d = dict[idx].connectionLink
            } else {
                d = dict[idx].keyLink
            }
        }
    }
}
