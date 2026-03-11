import Foundation

/// A search result candidate.
struct SearchCandidate: Equatable {
    let word: String
    let reading: String?

    init(word: String, reading: String? = nil) {
        self.word = word
        self.reading = reading
    }
}

/// Three-tier dictionary search system.
/// Priority: study dict > local dict > connection dict.
/// Ported from WordSearch.rb (Toshiyuki Masui, 2011-2015)
class WordSearch {
    private let connectionDict: ConnectionDict
    private let localDictFile: String
    private let studyDictFile: String
    private var localDict: [[String]]   // [[yomi, word], ...]
    private var studyDict: [[String]]
    private var localDictTime: Date
    private var searchMode: Int = 0

    init(connectionDictFile: String, localDictFile: String, studyDictFile: String) {
        self.localDictFile = localDictFile
        self.studyDictFile = studyDictFile
        self.connectionDict = PerfLog.measure("ConnectionDict load", logger: Log.dict) {
            ConnectionDict(dictFile: connectionDictFile)
        }
        self.localDict = Self.loadDict(dictFile: localDictFile)
        self.localDictTime = Self.fileModTime(localDictFile)
        self.studyDict = Self.loadDict(dictFile: studyDictFile)
        Log.dict.info("WordSearch initialized: local=\(localDict.count), study=\(studyDict.count) entries")
    }

    /// Main search method.
    /// - Parameters:
    ///   - query: Input romaji pattern
    ///   - searchMode: 0 = prefix, 1 = exact
    ///   - limit: Max results
    /// - Returns: Array of SearchCandidate
    func search(query: String, searchMode: Int, limit: Int = 10) -> [SearchCandidate] {
        self.searchMode = searchMode
        guard !query.isEmpty else { return [] }

        // Reload local dict if modified externally
        let currentMtime = Self.fileModTime(localDictFile)
        if currentMtime > localDictTime {
            localDict = Self.loadDict(dictFile: localDictFile)
            localDictTime = currentMtime
            Log.dict.info("Local dict hot-reloaded: \(localDict.count) entries")
        }

        var q = query
        var candfound: Set<String> = []
        var candidates: [SearchCandidate] = []

        // Special: Google transliteration (period suffix)
        if q.count > 1, q.hasSuffix(".") {
            q.removeLast()
            // Google transliteration is async/optional — return empty for now
            return candidates
        }

        // Special: color image (#suffix)
        if q.count > 1, q.hasSuffix("#") {
            q.removeLast()
            // Image generation — placeholder
            return candidates
        }

        // Special: image search (!suffix)
        if q.count > 1, q.hasSuffix("!") {
            q.removeLast()
            return candidates
        }

        // Special: timestamp
        if q == "ds" {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            candidates.append(SearchCandidate(word: formatter.string(from: Date())))
            return candidates
        }


        // Special: uppercase → pass through
        if q.range(of: "[A-Z]", options: .regularExpression) != nil {
            candidates.append(SearchCandidate(word: q, reading: q))
            return candidates
        }

        // Normal search
        let escaped = NSRegularExpression.escapedPattern(for: q)
        let pattern = searchMode > 0 ? "^\(escaped)$" : "^\(escaped)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return candidates }

        // Search study + local dicts
        for entry in (studyDict + localDict) {
            guard entry.count >= 2 else { continue }
            let yomi = entry[0]
            let word = entry[1]
            let range = NSRange(yomi.startIndex..., in: yomi)
            if regex.firstMatch(in: yomi, range: range) != nil {
                if !candfound.contains(word) {
                    candidates.append(SearchCandidate(word: word, reading: yomi))
                    candfound.insert(word)
                    if candidates.count > limit { break }
                }
            }
        }

        // Search connection dict
        connectionDict.search(pat: q, searchMode: searchMode) { word, pat, outc in
            var w = word
            if w.hasSuffix("*") { return }
            w = w.replacingOccurrences(of: "*", with: "")
            if !candfound.contains(w) {
                candidates.append(SearchCandidate(word: w, reading: pat))
                candfound.insert(w)
            }
        }
        // Limit results
        if candidates.count > limit {
            candidates = Array(candidates.prefix(limit))
        }

        return candidates
    }

    /// Register a word to the user's local dictionary.
    func register(word: String, reading: String) {
        localDict.removeAll { $0 == [reading, word] }
        localDict.insert([reading, word], at: 0)
        Self.saveDict(dictFile: localDictFile, dict: localDict)
        localDictTime = Self.fileModTime(localDictFile)
    }

    /// Learn a word to the study dictionary.
    func study(word: String, reading: String) {
        if reading.count > 1 {
            var registered = false
            connectionDict.search(pat: reading, searchMode: searchMode) { w, _, _ in
                var cleaned = w
                if cleaned.hasSuffix("*") { return }
                cleaned = cleaned.replacingOccurrences(of: "*", with: "")
                if cleaned == word {
                    registered = true
                }
            }
            if !registered {
                // If in study dict but not connection dict, promote to local dict
                if studyDict.contains([reading, word]) {
                    register(word: word, reading: reading)
                }
            }
        }

        studyDict.insert([reading, word], at: 0)
        if studyDict.count > 1000 {
            studyDict = Array(studyDict.prefix(1001))
        }
    }

    func start() {
        // Intentionally empty — reloading study dict caused input lag in original
    }

    func finish() {
        Self.saveDict(dictFile: studyDictFile, dict: studyDict)
    }

    // MARK: - File I/O

    static func loadDict(dictFile: String) -> [[String]] {
        var dict: [[String]] = []
        let content: String
        do {
            content = try String(contentsOfFile: dictFile, encoding: .utf8)
        } catch {
            Log.dict.error("Failed to load dict \(dictFile): \(error.localizedDescription)")
            return dict
        }
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(line)
            if s.hasPrefix("#") || s.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let parts = s.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count >= 2 {
                dict.append([String(parts[0]), String(parts[1])])
            }
        }
        return dict
    }

    static func saveDict(dictFile: String, dict: [[String]]) {
        var saved: Set<String> = []
        var lines: [String] = []
        for entry in dict {
            guard entry.count >= 2 else { continue }
            let s = "\(entry[0])\t\(entry[1])"
            if !saved.contains(s) {
                lines.append(s)
                saved.insert(s)
            }
        }
        let content = lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")
        do {
            try content.write(toFile: dictFile, atomically: true, encoding: .utf8)
        } catch {
            Log.dict.error("Failed to save dict \(dictFile): \(error.localizedDescription)")
        }
    }

    private static func fileModTime(_ path: String) -> Date {
        (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? Date.distantPast
    }
}
