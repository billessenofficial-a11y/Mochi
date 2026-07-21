import Foundation

enum EmbeddedOpenAIKeyProvider {
    static var value: String? {
        guard let url = Bundle.main.url(forResource: "MochiOpenAIKey", withExtension: "txt"),
              let rawValue = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
