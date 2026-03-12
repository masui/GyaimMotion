import Foundation

/// Google Transliteration API integration (optional feature).
/// Ported from Google.rb — uses URLSession instead of AFMotion.
enum GoogleTransliterate {

    // MARK: - Trigger Suffix Configuration

    private static let triggerKey = "googleTransliterateTrigger"
    private static let defaultTrigger = "`"

    /// The character suffix that triggers Google Transliterate (default: ".").
    static var triggerSuffix: String {
        UserDefaults.standard.string(forKey: triggerKey) ?? defaultTrigger
    }

    static func setTriggerSuffix(_ value: String) {
        UserDefaults.standard.set(value, forKey: triggerKey)
    }

    /// Check if a query string ends with the configured trigger suffix.
    /// Requires at least 2 characters (1 char query + trigger).
    static func hasTriggerSuffix(_ query: String) -> Bool {
        query.count > 1 && query.hasSuffix(triggerSuffix)
    }

    /// Strip the trigger suffix from a query string.
    static func stripTriggerSuffix(_ query: String) -> String {
        guard hasTriggerSuffix(query) else { return query }
        return String(query.dropLast(triggerSuffix.count))
    }

    // MARK: - URLSession with Timeout

    /// Timeout for API requests (exposed for testing).
    static var sessionTimeout: TimeInterval {
        session.configuration.timeoutIntervalForRequest
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3
        return URLSession(configuration: config)
    }()

    // MARK: - Filtering

    /// Filter raw API candidates: remove hiragana/katakana duplicates and deduplicate.
    static func filterCandidates(raw: [String], query: String) -> [String] {
        let rk = RomaKana()
        let hiragana = rk.roma2hiragana(query)
        let katakana = rk.roma2katakana(query)
        let filtered = raw.filter { $0 != hiragana && $0 != katakana }
        return Array(NSOrderedSet(array: filtered)) as? [String] ?? filtered
    }

    // MARK: - Candidate Building

    /// Build candidate list from Google API results with query and kana fallbacks.
    static func buildGoogleCandidates(apiResults: [String], query: String) -> [SearchCandidate] {
        let rk = RomaKana()
        let hiragana = rk.roma2hiragana(query)
        let katakana = rk.roma2katakana(query)

        var candidates: [SearchCandidate] = []
        candidates.append(SearchCandidate(word: query))

        for word in apiResults {
            candidates.append(SearchCandidate(word: word, reading: query))
        }

        if !hiragana.isEmpty {
            candidates.append(SearchCandidate(word: hiragana, reading: query))
        }
        if !katakana.isEmpty {
            candidates.append(SearchCandidate(word: katakana, reading: query))
        }

        // Deduplicate preserving order
        var seen: Set<String> = []
        candidates = candidates.filter { c in
            if seen.contains(c.word) { return false }
            seen.insert(c.word)
            return true
        }

        return candidates
    }

    // MARK: - Segment Combination

    /// Combine multiple segments into all combinations (cartesian product).
    /// e.g. [["増井","桝井"],["俊之","敏之"]] → ["増井俊之","増井敏之","桝井俊之","桝井敏之"]
    /// Limits total combinations to avoid explosion.
    static func combineSegments(_ segments: [[String]], limit: Int = 20) -> [String] {
        guard !segments.isEmpty else { return [] }
        var results = segments[0]
        for i in 1..<segments.count {
            var combined: [String] = []
            for prefix in results {
                for suffix in segments[i] {
                    combined.append(prefix + suffix)
                    if combined.count >= limit { break }
                }
                if combined.count >= limit { break }
            }
            results = combined
        }
        return results
    }

    // MARK: - API Call

    /// Search candidates using Google Transliteration API.
    /// - Parameter query: Romaji query string
    /// - Parameter completion: Called on main thread with filtered candidates
    static func searchCands(_ query: String, completion: @escaping ([String]) -> Void) {
        let rk = RomaKana()
        let hiragana = rk.roma2hiragana(query)

        guard var components = URLComponents(string: "https://google.com/transliterate") else {
            completion([])
            return
        }
        components.queryItems = [
            URLQueryItem(name: "langpair", value: "ja-Hira|ja"),
            URLQueryItem(name: "text", value: hiragana)
        ]
        guard let url = components.url else {
            completion([])
            return
        }

        let task = session.dataTask(with: url) { data, response, error in
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                Log.dict.error("Google Transliterate failed: status=\(status), error=\(error?.localizedDescription ?? "none")")
                DispatchQueue.main.async { completion([]) }
                return
            }

            // Parse all segments: [["ますい", ["増井","桝井"]], ["としゆき", ["俊之","敏之"]]]
            let segments = json.compactMap { entry -> [String]? in
                guard entry.count > 1, let cands = entry[1] as? [String], !cands.isEmpty else {
                    return nil
                }
                return cands
            }

            guard !segments.isEmpty else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            // Combine segments: e.g. [["増井","桝井"],["俊之","敏之"]] → ["増井俊之","増井敏之","桝井俊之","桝井敏之"]
            let combined = combineSegments(segments)
            let filtered = filterCandidates(raw: combined, query: query)
            DispatchQueue.main.async { completion(filtered) }
        }
        task.resume()
    }
}
