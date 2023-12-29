import Foundation
import UIKit
import TelegramCore
import Postbox
import TextFormat
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences

public final class ChatMessageItemAssociatedData: Equatable {
    public enum ChannelDiscussionGroupStatus: Equatable {
        case unknown
        case known(EnginePeer.Id?)
    }
    
    public struct DisplayTranscribeButton: Equatable {
        public let canBeDisplayed: Bool
        public let displayForNotConsumed: Bool
        
        public init(
            canBeDisplayed: Bool,
            displayForNotConsumed: Bool
        ) {
            self.canBeDisplayed = canBeDisplayed
            self.displayForNotConsumed = displayForNotConsumed
        }
    }
    
    public let automaticDownloadPeerType: MediaAutoDownloadPeerType
    public let automaticDownloadPeerId: EnginePeer.Id?
    public let automaticDownloadNetworkType: MediaAutoDownloadNetworkType
    public let isRecentActions: Bool
    public let subject: ChatControllerSubject?
    public let contactsPeerIds: Set<EnginePeer.Id>
    public let channelDiscussionGroup: ChannelDiscussionGroupStatus
    public let animatedEmojiStickers: [String: [StickerPackItem]]
    public let additionalAnimatedEmojiStickers: [String: [Int: StickerPackItem]]
    public let forcedResourceStatus: FileMediaResourceStatus?
    public let currentlyPlayingMessageId: EngineMessage.Index?
    public let isCopyProtectionEnabled: Bool
    public let availableReactions: AvailableReactions?
    public let defaultReaction: MessageReaction.Reaction?
    public let isPremium: Bool
    public let forceInlineReactions: Bool
    public let alwaysDisplayTranscribeButton: DisplayTranscribeButton
    public let accountPeer: EnginePeer?
    public let topicAuthorId: EnginePeer.Id?
    public let hasBots: Bool
    public let translateToLanguage: String?
    public let maxReadStoryId: Int32?
    public let recommendedChannels: RecommendedChannels?
    public let audioTranscriptionTrial: AudioTranscription.TrialState
    public let chatThemes: [TelegramTheme]
    
    public init(
        automaticDownloadPeerType: MediaAutoDownloadPeerType,
        automaticDownloadPeerId: EnginePeer.Id?,
        automaticDownloadNetworkType: MediaAutoDownloadNetworkType,
        isRecentActions: Bool = false,
        subject: ChatControllerSubject? = nil,
        contactsPeerIds: Set<EnginePeer.Id> = Set(),
        channelDiscussionGroup: ChannelDiscussionGroupStatus = .unknown,
        animatedEmojiStickers: [String: [StickerPackItem]] = [:],
        additionalAnimatedEmojiStickers: [String: [Int: StickerPackItem]] = [:],
        forcedResourceStatus: FileMediaResourceStatus? = nil,
        currentlyPlayingMessageId: EngineMessage.Index? = nil,
        isCopyProtectionEnabled: Bool = false,
        availableReactions: AvailableReactions?,
        defaultReaction: MessageReaction.Reaction?,
        isPremium: Bool,
        accountPeer: EnginePeer?,
        forceInlineReactions: Bool = false,
        alwaysDisplayTranscribeButton: DisplayTranscribeButton = DisplayTranscribeButton(canBeDisplayed: false, displayForNotConsumed: false),
        topicAuthorId: EnginePeer.Id? = nil,
        hasBots: Bool = false,
        translateToLanguage: String? = nil,
        maxReadStoryId: Int32? = nil,
        recommendedChannels: RecommendedChannels? = nil,
        audioTranscriptionTrial: AudioTranscription.TrialState = .defaultValue,
        chatThemes: [TelegramTheme] = []
    ) {
        self.automaticDownloadPeerType = automaticDownloadPeerType
        self.automaticDownloadPeerId = automaticDownloadPeerId
        self.automaticDownloadNetworkType = automaticDownloadNetworkType
        self.isRecentActions = isRecentActions
        self.subject = subject
        self.contactsPeerIds = contactsPeerIds
        self.channelDiscussionGroup = channelDiscussionGroup
        self.animatedEmojiStickers = animatedEmojiStickers
        self.additionalAnimatedEmojiStickers = additionalAnimatedEmojiStickers
        self.forcedResourceStatus = forcedResourceStatus
        self.currentlyPlayingMessageId = currentlyPlayingMessageId
        self.isCopyProtectionEnabled = isCopyProtectionEnabled
        self.availableReactions = availableReactions
        self.defaultReaction = defaultReaction
        self.isPremium = isPremium
        self.accountPeer = accountPeer
        self.forceInlineReactions = forceInlineReactions
        self.topicAuthorId = topicAuthorId
        self.alwaysDisplayTranscribeButton = alwaysDisplayTranscribeButton
        self.hasBots = hasBots
        self.translateToLanguage = translateToLanguage
        self.maxReadStoryId = maxReadStoryId
        self.recommendedChannels = recommendedChannels
        self.audioTranscriptionTrial = audioTranscriptionTrial
        self.chatThemes = chatThemes
    }
    
    public static func == (lhs: ChatMessageItemAssociatedData, rhs: ChatMessageItemAssociatedData) -> Bool {
        if lhs.automaticDownloadPeerType != rhs.automaticDownloadPeerType {
            return false
        }
        if lhs.automaticDownloadPeerId != rhs.automaticDownloadPeerId {
            return false
        }
        if lhs.automaticDownloadNetworkType != rhs.automaticDownloadNetworkType {
            return false
        }
        if lhs.isRecentActions != rhs.isRecentActions {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.contactsPeerIds != rhs.contactsPeerIds {
            return false
        }
        if lhs.channelDiscussionGroup != rhs.channelDiscussionGroup {
            return false
        }
        if lhs.animatedEmojiStickers != rhs.animatedEmojiStickers {
            return false
        }
        if lhs.additionalAnimatedEmojiStickers != rhs.additionalAnimatedEmojiStickers {
            return false
        }
        if lhs.forcedResourceStatus != rhs.forcedResourceStatus {
            return false
        }
        if lhs.currentlyPlayingMessageId != rhs.currentlyPlayingMessageId {
            return false
        }
        if lhs.isCopyProtectionEnabled != rhs.isCopyProtectionEnabled {
            return false
        }
        if lhs.availableReactions != rhs.availableReactions {
            return false
        }
        if lhs.isPremium != rhs.isPremium {
            return false
        }
        if lhs.accountPeer != rhs.accountPeer {
            return false
        }
        if lhs.forceInlineReactions != rhs.forceInlineReactions {
            return false
        }
        if lhs.topicAuthorId != rhs.topicAuthorId {
            return false
        }
        if lhs.alwaysDisplayTranscribeButton != rhs.alwaysDisplayTranscribeButton {
            return false
        }
        if lhs.hasBots != rhs.hasBots {
            return false
        }
        if lhs.translateToLanguage != rhs.translateToLanguage {
            return false
        }
        if lhs.maxReadStoryId != rhs.maxReadStoryId {
            return false
        }
        if lhs.recommendedChannels != rhs.recommendedChannels {
            return false
        }
        if lhs.audioTranscriptionTrial != rhs.audioTranscriptionTrial {
            return false
        }
        if lhs.chatThemes != rhs.chatThemes {
            return false
        }
        return true
    }
}

public extension ChatMessageItemAssociatedData {
    var isInPinnedListMode: Bool {
        if case .pinnedMessages = self.subject {
            return true
        } else {
            return false
        }
    }
}

public enum ChatControllerInteractionLongTapAction {
    case url(String)
    case mention(String)
    case peerMention(EnginePeer.Id, String)
    case command(String)
    case hashtag(String)
    case timecode(Double, String)
    case bankCard(String)
}

public enum ChatHistoryMessageSelection: Equatable {
    case none
    case selectable(selected: Bool)
    
    public static func ==(lhs: ChatHistoryMessageSelection, rhs: ChatHistoryMessageSelection) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .selectable(selected):
                if case .selectable(selected) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum ChatControllerInitialBotStartBehavior {
    case interactive
    case automatic(returnToPeerId: EnginePeer.Id, scheduled: Bool)
}

public struct ChatControllerInitialBotStart {
    public let payload: String
    public let behavior: ChatControllerInitialBotStartBehavior
    
    public init(payload: String, behavior: ChatControllerInitialBotStartBehavior) {
        self.payload = payload
        self.behavior = behavior
    }
}

public struct ChatControllerInitialAttachBotStart {
    public let botId: EnginePeer.Id
    public let payload: String?
    public let justInstalled: Bool
    
    public init(botId: EnginePeer.Id, payload: String?, justInstalled: Bool) {
        self.botId = botId
        self.payload = payload
        self.justInstalled = justInstalled
    }
}

public struct ChatControllerInitialBotAppStart {
    public let botApp: BotApp
    public let payload: String?
    public let justInstalled: Bool
    
    public init(botApp: BotApp, payload: String?, justInstalled: Bool) {
        self.botApp = botApp
        self.payload = payload
        self.justInstalled = justInstalled
    }
}

public enum ChatControllerInteractionNavigateToPeer {
    public struct InfoParams {
        public let switchToRecommendedChannels: Bool
        
        public init(switchToRecommendedChannels: Bool) {
            self.switchToRecommendedChannels = switchToRecommendedChannels
        }
    }
    
    case `default`
    case chat(textInputState: ChatTextInputState?, subject: ChatControllerSubject?, peekData: ChatPeekTimeout?)
    case info(InfoParams?)
    case withBotStartPayload(ChatControllerInitialBotStart)
    case withAttachBot(ChatControllerInitialAttachBotStart)
    case withBotApp(ChatControllerInitialBotAppStart)
}

public struct ChatInterfaceForwardOptionsState: Codable, Equatable {
    public var hideNames: Bool
    public var hideCaptions: Bool
    public var unhideNamesOnCaptionChange: Bool
    
    public static func ==(lhs: ChatInterfaceForwardOptionsState, rhs: ChatInterfaceForwardOptionsState) -> Bool {
        return lhs.hideNames == rhs.hideNames && lhs.hideCaptions == rhs.hideCaptions && lhs.unhideNamesOnCaptionChange == rhs.unhideNamesOnCaptionChange
    }
    
    public init(hideNames: Bool, hideCaptions: Bool, unhideNamesOnCaptionChange: Bool) {
        self.hideNames = hideNames
        self.hideCaptions = hideCaptions
        self.unhideNamesOnCaptionChange = unhideNamesOnCaptionChange
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.hideNames = (try? container.decodeIfPresent(Bool.self, forKey: "hn")) ?? false
        self.hideCaptions = (try? container.decodeIfPresent(Bool.self, forKey: "hc")) ?? false
        self.unhideNamesOnCaptionChange = false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.hideNames, forKey: "hn")
        try container.encode(self.hideCaptions, forKey: "hc")
    }
}

public struct ChatTextInputState: Codable, Equatable {
    public var inputText: NSAttributedString
    public var selectionRange: Range<Int>
    
    public static func ==(lhs: ChatTextInputState, rhs: ChatTextInputState) -> Bool {
        return lhs.inputText.isEqual(to: rhs.inputText) && lhs.selectionRange == rhs.selectionRange
    }
    
    public init() {
        self.inputText = NSAttributedString()
        self.selectionRange = 0 ..< 0
    }
    
    public init(inputText: NSAttributedString, selectionRange: Range<Int>) {
        self.inputText = inputText
        self.selectionRange = selectionRange
    }
    
    public init(inputText: NSAttributedString) {
        self.inputText = inputText
        let length = inputText.length
        self.selectionRange = length ..< length
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.inputText = ((try? container.decode(ChatTextInputStateText.self, forKey: "at")) ?? ChatTextInputStateText()).attributedText()
        let rangeFrom = (try? container.decode(Int32.self, forKey: "as0")) ?? 0
        let rangeTo = (try? container.decode(Int32.self, forKey: "as1")) ?? 0
        if rangeFrom <= rangeTo {
            self.selectionRange = Int(rangeFrom) ..< Int(rangeTo)
        } else {
            let length = self.inputText.length
            self.selectionRange = length ..< length
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(ChatTextInputStateText(attributedText: self.inputText), forKey: "at")
        try container.encode(Int32(self.selectionRange.lowerBound), forKey: "as0")
        try container.encode(Int32(self.selectionRange.upperBound), forKey: "as1")
    }
}

public enum ChatTextInputStateTextAttributeType: Codable, Equatable {
    case bold
    case italic
    case monospace
    case textMention(EnginePeer.Id)
    case textUrl(String)
    case customEmoji(stickerPack: StickerPackReference?, fileId: Int64)
    case strikethrough
    case underline
    case spoiler
    case quote
    case codeBlock(language: String?)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        switch (try? container.decode(Int32.self, forKey: "t")) ?? 0 {
        case 0:
            self = .bold
        case 1:
            self = .italic
        case 2:
            self = .monospace
        case 3:
            let peerId = (try? container.decode(Int64.self, forKey: "peerId")) ?? 0
            self = .textMention(EnginePeer.Id(peerId))
        case 4:
            let url = (try? container.decode(String.self, forKey: "url")) ?? ""
            self = .textUrl(url)
        case 5:
            let stickerPack = try container.decodeIfPresent(StickerPackReference.self, forKey: "s")
            let fileId = try container.decode(Int64.self, forKey: "f")
            self = .customEmoji(stickerPack: stickerPack, fileId: fileId)
        case 6:
            self = .strikethrough
        case 7:
            self = .underline
        case 8:
            self = .spoiler
        case 9:
            self = .quote
        case 10:
            self = .codeBlock(language: try container.decodeIfPresent(String.self, forKey: "l"))
        default:
            assertionFailure()
            self = .bold
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        switch self {
        case .bold:
            try container.encode(0 as Int32, forKey: "t")
        case .italic:
            try container.encode(1 as Int32, forKey: "t")
        case .monospace:
            try container.encode(2 as Int32, forKey: "t")
        case let .textMention(id):
            try container.encode(3 as Int32, forKey: "t")
            try container.encode(id.toInt64(), forKey: "peerId")
        case let .textUrl(url):
            try container.encode(4 as Int32, forKey: "t")
            try container.encode(url, forKey: "url")
        case let .customEmoji(stickerPack, fileId):
            try container.encode(5 as Int32, forKey: "t")
            try container.encodeIfPresent(stickerPack, forKey: "s")
            try container.encode(fileId, forKey: "f")
        case .strikethrough:
            try container.encode(6 as Int32, forKey: "t")
        case .underline:
            try container.encode(7 as Int32, forKey: "t")
        case .spoiler:
            try container.encode(8 as Int32, forKey: "t")
        case .quote:
            try container.encode(9 as Int32, forKey: "t")
        case let .codeBlock(language):
            try container.encode(10 as Int32, forKey: "t")
            try container.encodeIfPresent(language, forKey: "l")
        }
    }
}

public struct ChatTextInputStateTextAttribute: Codable, Equatable {
    public let type: ChatTextInputStateTextAttributeType
    public let range: Range<Int>
    
    public init(type: ChatTextInputStateTextAttributeType, range: Range<Int>) {
        self.type = type
        self.range = range
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.type = try container.decode(ChatTextInputStateTextAttributeType.self, forKey: "type")
        let rangeFrom = (try? container.decode(Int32.self, forKey: "range0")) ?? 0
        let rangeTo = (try? container.decode(Int32.self, forKey: "range1")) ?? 0

        self.range = Int(rangeFrom) ..< Int(rangeTo)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.type, forKey: "type")

        try container.encode(Int32(self.range.lowerBound), forKey: "range0")
        try container.encode(Int32(self.range.upperBound), forKey: "range1")
    }
    
    public static func ==(lhs: ChatTextInputStateTextAttribute, rhs: ChatTextInputStateTextAttribute) -> Bool {
        return lhs.type == rhs.type && lhs.range == rhs.range
    }
}

public struct ChatTextInputStateText: Codable, Equatable {
    public let text: String
    public let attributes: [ChatTextInputStateTextAttribute]
    
    public init() {
        self.text = ""
        self.attributes = []
    }
    
    public init(text: String, attributes: [ChatTextInputStateTextAttribute]) {
        self.text = text
        self.attributes = attributes
    }
    
    public init(attributedText: NSAttributedString) {
        self.text = attributedText.string
        var parsedAttributes: [ChatTextInputStateTextAttribute] = []
        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: [], using: { attributes, range, _ in
            for (key, value) in attributes {
                if key == ChatTextInputAttributes.bold {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .bold, range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.italic {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .italic, range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.monospace {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .monospace, range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.textMention, let value = value as? ChatTextInputTextMentionAttribute {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .textMention(value.peerId), range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.textUrl, let value = value as? ChatTextInputTextUrlAttribute {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .textUrl(value.url), range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.customEmoji, let value = value as? ChatTextInputTextCustomEmojiAttribute {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .customEmoji(stickerPack: nil, fileId: value.fileId), range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.strikethrough {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .strikethrough, range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.underline {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .underline, range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.spoiler {
                    parsedAttributes.append(ChatTextInputStateTextAttribute(type: .spoiler, range: range.location ..< (range.location + range.length)))
                } else if key == ChatTextInputAttributes.block, let value = value as? ChatTextInputTextQuoteAttribute {
                    switch value.kind {
                    case .quote:
                        parsedAttributes.append(ChatTextInputStateTextAttribute(type: .quote, range: range.location ..< (range.location + range.length)))
                    case let .code(language):
                        parsedAttributes.append(ChatTextInputStateTextAttribute(type: .codeBlock(language: language), range: range.location ..< (range.location + range.length)))
                    }
                }
            }
        })
        self.attributes = parsedAttributes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.text = (try? container.decode(String.self, forKey: "text")) ?? ""
        self.attributes = (try? container.decode([ChatTextInputStateTextAttribute].self, forKey: "attributes")) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.text, forKey: "text")
        try container.encode(self.attributes, forKey: "attributes")
    }
    
    static public func ==(lhs: ChatTextInputStateText, rhs: ChatTextInputStateText) -> Bool {
        return lhs.text == rhs.text && lhs.attributes == rhs.attributes
    }
    
    public func attributedText() -> NSAttributedString {
        let result = NSMutableAttributedString(string: self.text)
        for attribute in self.attributes {
            switch attribute.type {
            case .bold:
                result.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case .italic:
                result.addAttribute(ChatTextInputAttributes.italic, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case .monospace:
                result.addAttribute(ChatTextInputAttributes.monospace, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case let .textMention(id):
                result.addAttribute(ChatTextInputAttributes.textMention, value: ChatTextInputTextMentionAttribute(peerId: id), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case let .textUrl(url):
                result.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: url), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case let .customEmoji(_, fileId):
                result.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: nil), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case .strikethrough:
                result.addAttribute(ChatTextInputAttributes.strikethrough, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case .underline:
                result.addAttribute(ChatTextInputAttributes.underline, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case .spoiler:
                result.addAttribute(ChatTextInputAttributes.spoiler, value: true as NSNumber, range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case .quote:
                result.addAttribute(ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: .quote), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            case let .codeBlock(language):
                result.addAttribute(ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: .code(language: language)), range: NSRange(location: attribute.range.lowerBound, length: attribute.range.count))
            }
        }
        return result
    }
}

public enum ChatControllerSubject: Equatable {
    public enum MessageSubject: Equatable {
        case id(EngineMessage.Id)
        case timestamp(Int32)
    }

    public struct ForwardOptions: Equatable {
        public var hideNames: Bool
        public var hideCaptions: Bool
        
        public init(hideNames: Bool, hideCaptions: Bool) {
            self.hideNames = hideNames
            self.hideCaptions = hideCaptions
        }
    }
    
    public struct LinkOptions: Equatable {
        public var messageText: String
        public var messageEntities: [MessageTextEntity]
        public var hasAlternativeLinks: Bool
        public var replyMessageId: EngineMessage.Id?
        public var replyQuote: String?
        public var url: String
        public var webpage: TelegramMediaWebpage
        public var linkBelowText: Bool
        public var largeMedia: Bool
        
        public init(
            messageText: String,
            messageEntities: [MessageTextEntity],
            hasAlternativeLinks: Bool,
            replyMessageId: EngineMessage.Id?,
            replyQuote: String?,
            url: String,
            webpage: TelegramMediaWebpage,
            linkBelowText: Bool,
            largeMedia: Bool
        ) {
            self.messageText = messageText
            self.messageEntities = messageEntities
            self.hasAlternativeLinks = hasAlternativeLinks
            self.replyMessageId = replyMessageId
            self.replyQuote = replyQuote
            self.url = url
            self.webpage = webpage
            self.linkBelowText = linkBelowText
            self.largeMedia = largeMedia
        }
    }
    
    public enum MessageOptionsInfo: Equatable {
        public struct Quote: Equatable {
            public let messageId: EngineMessage.Id
            public let text: String
            public let offset: Int?
            
            public init(messageId: EngineMessage.Id, text: String, offset: Int?) {
                self.messageId = messageId
                self.text = text
                self.offset = offset
            }
        }
        
        public struct SelectionState: Equatable {
            public var canQuote: Bool
            public var quote: Quote?
            
            public init(canQuote: Bool, quote: Quote?) {
                self.canQuote = canQuote
                self.quote = quote
            }
        }
        
        public struct Reply: Equatable {
            public var quote: Quote?
            public var selectionState: Promise<SelectionState>
            
            public init(quote: Quote?, selectionState: Promise<SelectionState>) {
                self.quote = quote
                self.selectionState = selectionState
            }
            
            public static func ==(lhs: Reply, rhs: Reply) -> Bool {
                if lhs.quote != rhs.quote {
                    return false
                }
                if lhs.selectionState !== rhs.selectionState {
                    return false
                }
                return true
            }
        }
        
        public struct Forward: Equatable {
            public var options: Signal<ForwardOptions, NoError>
            
            public init(options: Signal<ForwardOptions, NoError>) {
                self.options = options
            }
            
            public static func ==(lhs: Forward, rhs: Forward) -> Bool {
                return true
            }
        }
        
        public struct Link: Equatable {
            public var options: Signal<LinkOptions, NoError>
            
            public init(options: Signal<LinkOptions, NoError>) {
                self.options = options
            }
            
            public static func ==(lhs: Link, rhs: Link) -> Bool {
                return true
            }
        }
        
        case reply(Reply)
        case forward(Forward)
        case link(Link)
    }
    
    public struct MessageHighlight: Equatable {
        public struct Quote: Equatable {
            public var string: String
            public var offset: Int?
            
            public init(string: String, offset: Int?) {
                self.string = string
                self.offset = offset
            }
        }
        
        public var quote: Quote?
        
        public init(quote: Quote? = nil) {
            self.quote = quote
        }
    }
    
    case message(id: MessageSubject, highlight: MessageHighlight?, timecode: Double?)
    case scheduledMessages
    case pinnedMessages(id: EngineMessage.Id?)
    case messageOptions(peerIds: [EnginePeer.Id], ids: [EngineMessage.Id], info: MessageOptionsInfo)
    
    public static func ==(lhs: ChatControllerSubject, rhs: ChatControllerSubject) -> Bool {
        switch lhs {
        case let .message(lhsId, lhsHighlight, lhsTimecode):
            if case let .message(rhsId, rhsHighlight, rhsTimecode) = rhs, lhsId == rhsId && lhsHighlight == rhsHighlight && lhsTimecode == rhsTimecode {
                return true
            } else {
                return false
            }
        case .scheduledMessages:
            if case .scheduledMessages = rhs {
                return true
            } else {
                return false
            }
        case let .pinnedMessages(id):
            if case .pinnedMessages(id) = rhs {
                return true
            } else {
                return false
            }
        case let .messageOptions(lhsPeerIds, lhsIds, lhsInfo):
            if case let .messageOptions(rhsPeerIds, rhsIds, rhsInfo) = rhs, lhsPeerIds == rhsPeerIds, lhsIds == rhsIds, lhsInfo == rhsInfo {
                return true
            } else {
                return false
            }
        }
    }
    
    public var isService: Bool {
        switch self {
        case .message:
            return false
        default:
            return true
        }
    }
}

public enum ChatControllerPresentationMode: Equatable {
    case standard(previewing: Bool)
    case overlay(NavigationController?)
    case inline(NavigationController?)
}

public enum ChatPresentationInputQueryResult: Equatable {
    case stickers([FoundStickerItem])
    case hashtags([String])
    case mentions([EnginePeer])
    case commands([PeerCommand])
    case emojis([(String, TelegramMediaFile?, String)], NSRange)
    case contextRequestResult(EnginePeer?, ChatContextResultCollection?)
    
    public static func ==(lhs: ChatPresentationInputQueryResult, rhs: ChatPresentationInputQueryResult) -> Bool {
        switch lhs {
        case let .stickers(lhsItems):
            if case let .stickers(rhsItems) = rhs, lhsItems == rhsItems {
                return true
            } else {
                return false
            }
        case let .hashtags(lhsResults):
            if case let .hashtags(rhsResults) = rhs {
                return lhsResults == rhsResults
            } else {
                return false
            }
        case let .mentions(lhsPeers):
            if case let .mentions(rhsPeers) = rhs {
                if lhsPeers != rhsPeers {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .commands(lhsCommands):
            if case let .commands(rhsCommands) = rhs {
                if lhsCommands != rhsCommands {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .emojis(lhsValue, lhsRange):
            if case let .emojis(rhsValue, rhsRange) = rhs {
                if lhsRange != rhsRange {
                    return false
                }
                if lhsValue.count != rhsValue.count {
                    return false
                }
                for i in 0 ..< lhsValue.count {
                    if lhsValue[i].0 != rhsValue[i].0 {
                        return false
                    }
                    if lhsValue[i].1?.fileId != rhsValue[i].1?.fileId {
                        return false
                    }
                    if lhsValue[i].2 != rhsValue[i].2 {
                        return false
                    }
                }
                return true
            } else {
                return false
            }
        case let .contextRequestResult(lhsPeer, lhsCollection):
            if case let .contextRequestResult(rhsPeer, rhsCollection) = rhs {
                if lhsPeer != rhsPeer {
                    return false
                }
                if lhsCollection != rhsCollection {
                    return false
                }
                return true
            } else {
                return false
            }
        }
    }
}

#if DEBUG
public let ChatControllerCount = Atomic<Int32>(value: 0)
#endif

public final class PeerInfoNavigationSourceTag {
    public let peerId: EnginePeer.Id
    
    public init(peerId: EnginePeer.Id) {
        self.peerId = peerId
    }
}

public protocol PeerInfoScreen: ViewController {
    var peerId: PeerId { get }
}

public extension Peer {
    func canSetupAutoremoveTimeout(accountPeerId: EnginePeer.Id) -> Bool {
        if let _ = self as? TelegramSecretChat {
            return false
        } else if let group = self as? TelegramGroup {
            if case .creator = group.role {
                return true
            } else if case let .admin(rights, _) = group.role {
                if rights.rights.contains(.canDeleteMessages) {
                    return true
                }
            }
        } else if let user = self as? TelegramUser {
            if user.id != accountPeerId && user.botInfo == nil {
                return true
            }
        } else if let channel = self as? TelegramChannel {
            if channel.hasPermission(.deleteAllMessages) {
                return true
            }
        }
        
        return false
    }
}

public protocol ChatController: ViewController {
    var chatLocation: ChatLocation { get }
    var canReadHistory: ValuePromise<Bool> { get }
    var parentController: ViewController? { get set }
    
    var purposefulAction: (() -> Void)? { get set }
    
    var selectedMessageIds: Set<EngineMessage.Id>? { get }
    var presentationInterfaceStateSignal: Signal<Any, NoError> { get }
    
    func updatePresentationMode(_ mode: ChatControllerPresentationMode)
    func beginMessageSearch(_ query: String)
    func displayPromoAnnouncement(text: String)
    
    func updatePushedTransition(_ fraction: CGFloat, transition: ContainedViewLayoutTransition)
    
    func hintPlayNextOutgoingGift()
    
    var isSendButtonVisible: Bool { get }
    
    var isSelectingMessagesUpdated: ((Bool) -> Void)? { get set }
    func cancelSelectingMessages()
    func activateSearch(domain: ChatSearchDomain, query: String)
    func beginClearHistory(type: InteractiveHistoryClearingType)
}

public protocol ChatMessagePreviewItemNode: AnyObject {
    var forwardInfoReferenceNode: ASDisplayNode? { get }
}

public enum FileMediaResourcePlaybackStatus: Equatable {
    case playing
    case paused
}

public struct FileMediaResourceStatus: Equatable {
    public var mediaStatus: FileMediaResourceMediaStatus
    public var fetchStatus: EngineMediaResource.FetchStatus
    
    public init(mediaStatus: FileMediaResourceMediaStatus, fetchStatus: EngineMediaResource.FetchStatus) {
        self.mediaStatus = mediaStatus
        self.fetchStatus = fetchStatus
    }
}

public enum FileMediaResourceMediaStatus: Equatable {
    case fetchStatus(EngineMediaResource.FetchStatus)
    case playbackStatus(FileMediaResourcePlaybackStatus)
}

public protocol ChatMessageItemNodeProtocol: ListViewItemNode {
    func targetReactionView(value: MessageReaction.Reaction) -> UIView?
    func targetForStoryTransition(id: StoryId) -> UIView?
    func contentFrame() -> CGRect
}

public final class ChatControllerNavigationData: CustomViewControllerNavigationData {
    public let peerId: PeerId
    public let threadId: Int64?
    
    public init(peerId: PeerId, threadId: Int64?) {
        self.peerId = peerId
        self.threadId = threadId
    }
    
    public func combine(summary: CustomViewControllerNavigationDataSummary?) -> CustomViewControllerNavigationDataSummary? {
        if let summary = summary as? ChatControllerNavigationDataSummary {
            return summary.adding(peerNavigationItem: ChatNavigationStackItem(peerId: self.peerId, threadId: threadId))
        } else {
            return ChatControllerNavigationDataSummary(peerNavigationItems: [ChatNavigationStackItem(peerId: self.peerId, threadId: threadId)])
        }
    }
}

public final class ChatControllerNavigationDataSummary: CustomViewControllerNavigationDataSummary {
    public let peerNavigationItems: [ChatNavigationStackItem]
    
    public init(peerNavigationItems: [ChatNavigationStackItem]) {
        self.peerNavigationItems = peerNavigationItems
    }
    
    public func adding(peerNavigationItem: ChatNavigationStackItem) -> ChatControllerNavigationDataSummary {
        var peerNavigationItems = self.peerNavigationItems
        if let index = peerNavigationItems.firstIndex(of: peerNavigationItem) {
            peerNavigationItems.removeSubrange(0 ... index)
        }
        peerNavigationItems.insert(peerNavigationItem, at: 0)
        return ChatControllerNavigationDataSummary(peerNavigationItems: peerNavigationItems)
    }
}

public enum ChatHistoryListSource {
    public struct Quote {
        public var text: String
        public var offset: Int?
        
        public init(text: String, offset: Int?) {
            self.text = text
            self.offset = offset
        }
    }
    
    case `default`
    case custom(messages: Signal<([Message], Int32, Bool), NoError>, messageId: MessageId, quote: Quote?, loadMore: (() -> Void)?)
}

public enum ChatHistoryListDisplayHeaders {
    case none
    case all
    case allButLast
}

public enum ChatHistoryListMode: Equatable {
    case bubbles
    case list(search: Bool, reversed: Bool, reverseGroups: Bool, displayHeaders: ChatHistoryListDisplayHeaders, hintLinks: Bool, isGlobalSearch: Bool)
}

public protocol ChatControllerInteractionProtocol: AnyObject {
}

public enum ChatHistoryNodeHistoryState: Equatable {
    case loading
    case loaded(isEmpty: Bool)
}

public protocol ChatHistoryListNode: ListView {
    var historyState: ValuePromise<ChatHistoryNodeHistoryState> { get }
    
    func scrollToEndOfHistory()
    func updateLayout(transition: ContainedViewLayoutTransition, updateSizeAndInsets: ListViewUpdateSizeAndInsets)
    func messageInCurrentHistoryView(_ id: MessageId) -> Message?
}
