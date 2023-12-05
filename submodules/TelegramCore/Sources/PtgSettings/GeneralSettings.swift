import Foundation
import Postbox

extension ApplicationSpecificSharedDataKeys {
    public static let ptgSettings = applicationSpecificPreferencesKey(102)
}

public struct PtgSettings: Codable, Equatable {
    public enum JumpToNextUnreadChannel: Int32 {
        case disabled
        case topFirst
        case bottomFirst
    }
    
    public let showPeerId: Bool
    public let showChannelCreationDate: Bool
    public let suppressForeignAgentNotice: Bool
    public let useRearCameraByDefault: Bool
    public let hideReactionsInChannels: Bool
    public let hideCommentsInChannels: Bool
    public let hideShareButtonInChannels: Bool
    public let useFullWidthInChannels: Bool
    public let addContextMenuSaveMessage: Bool
    public let addContextMenuShare: Bool
    public let jumpToNextUnreadChannel: JumpToNextUnreadChannel
    public let hideSignatureInChannels: Bool
    public let hideMuteUnmuteButtonInChannels: Bool
    public let disableSwipeActionsForChats: Bool
    public let disableSwipeToStoryCamera: Bool
    public let suppressReactionNotifications: Bool
    public let testToolsEnabled: Bool?
    
    public static var defaultSettings: PtgSettings {
        return PtgSettings(
            showPeerId: true,
            showChannelCreationDate: true,
            suppressForeignAgentNotice: false,
            useRearCameraByDefault: false,
            hideReactionsInChannels: false,
            hideCommentsInChannels: false,
            hideShareButtonInChannels: false,
            useFullWidthInChannels: false,
            addContextMenuSaveMessage: false,
            addContextMenuShare: false,
            jumpToNextUnreadChannel: .topFirst,
            hideSignatureInChannels: false,
            hideMuteUnmuteButtonInChannels: false,
            disableSwipeActionsForChats: false,
            disableSwipeToStoryCamera: false,
            suppressReactionNotifications: false,
            testToolsEnabled: nil
        )
    }
    
    public init(
        showPeerId: Bool,
        showChannelCreationDate: Bool,
        suppressForeignAgentNotice: Bool,
        useRearCameraByDefault: Bool,
        hideReactionsInChannels: Bool,
        hideCommentsInChannels: Bool,
        hideShareButtonInChannels: Bool,
        useFullWidthInChannels: Bool,
        addContextMenuSaveMessage: Bool,
        addContextMenuShare: Bool,
        jumpToNextUnreadChannel: JumpToNextUnreadChannel,
        hideSignatureInChannels: Bool,
        hideMuteUnmuteButtonInChannels: Bool,
        disableSwipeActionsForChats: Bool,
        disableSwipeToStoryCamera: Bool,
        suppressReactionNotifications: Bool,
        testToolsEnabled: Bool?
    ) {
        self.showPeerId = showPeerId
        self.showChannelCreationDate = showChannelCreationDate
        self.suppressForeignAgentNotice = suppressForeignAgentNotice
        self.useRearCameraByDefault = useRearCameraByDefault
        self.hideReactionsInChannels = hideReactionsInChannels
        self.hideCommentsInChannels = hideCommentsInChannels
        self.hideShareButtonInChannels = hideShareButtonInChannels
        self.useFullWidthInChannels = useFullWidthInChannels
        self.addContextMenuSaveMessage = addContextMenuSaveMessage
        self.addContextMenuShare = addContextMenuShare
        self.jumpToNextUnreadChannel = jumpToNextUnreadChannel
        self.hideSignatureInChannels = hideSignatureInChannels
        self.hideMuteUnmuteButtonInChannels = hideMuteUnmuteButtonInChannels
        self.disableSwipeActionsForChats = disableSwipeActionsForChats
        self.disableSwipeToStoryCamera = disableSwipeToStoryCamera
        self.suppressReactionNotifications = suppressReactionNotifications
        self.testToolsEnabled = testToolsEnabled
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.showPeerId = (try container.decodeIfPresent(Int32.self, forKey: "spi") ?? 1) != 0
        self.showChannelCreationDate = (try container.decodeIfPresent(Int32.self, forKey: "sccd") ?? 1) != 0
        self.suppressForeignAgentNotice = (try container.decodeIfPresent(Int32.self, forKey: "sfan") ?? 0) != 0
        self.useRearCameraByDefault = (try container.decodeIfPresent(Int32.self, forKey: "urcbd") ?? 0) != 0
        self.hideReactionsInChannels = (try container.decodeIfPresent(Int32.self, forKey: "hric") ?? 0) != 0
        self.hideCommentsInChannels = (try container.decodeIfPresent(Int32.self, forKey: "hcic") ?? 0) != 0
        self.hideShareButtonInChannels = (try container.decodeIfPresent(Int32.self, forKey: "hsbic") ?? 0) != 0
        self.useFullWidthInChannels = (try container.decodeIfPresent(Int32.self, forKey: "ufwic") ?? 0) != 0
        self.addContextMenuSaveMessage = (try container.decodeIfPresent(Int32.self, forKey: "acmsm") ?? 0) != 0
        self.addContextMenuShare = (try container.decodeIfPresent(Int32.self, forKey: "acms") ?? 0) != 0
        self.jumpToNextUnreadChannel = (try container.decodeIfPresent(Int32.self, forKey: "jtnuc")).flatMap({ JumpToNextUnreadChannel(rawValue: $0) }) ?? .topFirst
        self.hideSignatureInChannels = (try container.decodeIfPresent(Int32.self, forKey: "hsic") ?? 0) != 0
        self.hideMuteUnmuteButtonInChannels = (try container.decodeIfPresent(Int32.self, forKey: "hmubic") ?? 0) != 0
        self.disableSwipeActionsForChats = (try container.decodeIfPresent(Int32.self, forKey: "dsafc") ?? 0) != 0
        self.disableSwipeToStoryCamera = (try container.decodeIfPresent(Int32.self, forKey: "dstsc") ?? 0) != 0
        self.suppressReactionNotifications = (try container.decodeIfPresent(Int32.self, forKey: "srn") ?? 0) != 0
        self.testToolsEnabled = try container.decodeIfPresent(Int32.self, forKey: "test").flatMap({ $0 != 0 })
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode((self.showPeerId ? 1 : 0) as Int32, forKey: "spi")
        try container.encode((self.showChannelCreationDate ? 1 : 0) as Int32, forKey: "sccd")
        try container.encode((self.suppressForeignAgentNotice ? 1 : 0) as Int32, forKey: "sfan")
        try container.encode((self.useRearCameraByDefault ? 1 : 0) as Int32, forKey: "urcbd")
        try container.encode((self.hideReactionsInChannels ? 1 : 0) as Int32, forKey: "hric")
        try container.encode((self.hideCommentsInChannels ? 1 : 0) as Int32, forKey: "hcic")
        try container.encode((self.hideShareButtonInChannels ? 1 : 0) as Int32, forKey: "hsbic")
        try container.encode((self.useFullWidthInChannels ? 1 : 0) as Int32, forKey: "ufwic")
        try container.encode((self.addContextMenuSaveMessage ? 1 : 0) as Int32, forKey: "acmsm")
        try container.encode((self.addContextMenuShare ? 1 : 0) as Int32, forKey: "acms")
        try container.encode(self.jumpToNextUnreadChannel.rawValue, forKey: "jtnuc")
        try container.encode((self.hideSignatureInChannels ? 1 : 0) as Int32, forKey: "hsic")
        try container.encode((self.hideMuteUnmuteButtonInChannels ? 1 : 0) as Int32, forKey: "hmubic")
        try container.encode((self.disableSwipeActionsForChats ? 1 : 0) as Int32, forKey: "dsafc")
        try container.encode((self.disableSwipeToStoryCamera ? 1 : 0) as Int32, forKey: "dstsc")
        try container.encode((self.suppressReactionNotifications ? 1 : 0) as Int32, forKey: "srn")
        try container.encodeIfPresent(self.testToolsEnabled.flatMap({ ($0 ? 1 : 0) as Int32 }), forKey: "test")
    }
    
    public init(_ entry: PreferencesEntry?) {
        self = entry?.get(PtgSettings.self) ?? .defaultSettings
    }
    
    public init(_ transaction: AccountManagerModifier<TelegramAccountManagerTypes>) {
        let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.ptgSettings)
        self.init(entry)
    }
}
