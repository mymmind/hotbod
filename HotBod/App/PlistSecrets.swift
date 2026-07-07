import Foundation

enum PlistSecrets {
    static func string(resource: String, key: String) -> String? {
        guard let path = Bundle.main.path(forResource: resource, ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String],
              let value = dict[key],
              !value.isEmpty else { return nil }
        return value
    }
}
