import Foundation

/// Google Transliteration API integration (optional feature).
/// Ported from Google.rb — uses URLSession instead of AFMotion.
enum GoogleTransliterate {
    /// Search candidates using Google Transliteration API.
    /// - Parameter query: Romaji query string
    /// - Returns: Array of transliterated candidates
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

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[Any]],
                  let first = json.first,
                  first.count > 1,
                  let candidates = first[1] as? [String] else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let katakana = rk.roma2katakana(query)
            let filtered = candidates.filter { $0 != hiragana && $0 != katakana }
            let unique = Array(NSOrderedSet(array: filtered)) as? [String] ?? filtered
            DispatchQueue.main.async { completion(unique) }
        }
        task.resume()
    }
}
