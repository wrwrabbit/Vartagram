import Foundation
import Postbox

extension ApplicationSpecificPreferencesKeys {
    public static let ptgAccountSettings = applicationSpecificPreferencesKey(100)
}

public struct PtgAccountSettings: Codable, Equatable {
    public let ignoreAllContentRestrictions: Bool
    public let skipSetTyping: Bool
    
    public static var `default`: PtgAccountSettings {
        return PtgAccountSettings(
            ignoreAllContentRestrictions: false,
            skipSetTyping: false
        )
    }
    
    public init(
        ignoreAllContentRestrictions: Bool,
        skipSetTyping: Bool
    ) {
        self.ignoreAllContentRestrictions = ignoreAllContentRestrictions
        self.skipSetTyping = skipSetTyping
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.ignoreAllContentRestrictions = (try container.decodeIfPresent(Int32.self, forKey: "iacr") ?? 0) != 0
        self.skipSetTyping = (try container.decodeIfPresent(Int32.self, forKey: "sst") ?? 0) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode((self.ignoreAllContentRestrictions ? 1 : 0) as Int32, forKey: "iacr")
        try container.encode((self.skipSetTyping ? 1 : 0) as Int32, forKey: "sst")
    }
    
    public init(_ entry: PreferencesEntry?) {
        self = entry?.get(PtgAccountSettings.self) ?? .default
    }
    
    public init(_ transaction: Transaction) {
        let entry = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.ptgAccountSettings)
        self.init(entry)
    }
}
