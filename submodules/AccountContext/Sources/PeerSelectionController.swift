import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import AnimationCache
import MultiAnimationRenderer

public struct ChatListNodePeersFilter: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let onlyWriteable = ChatListNodePeersFilter(rawValue: 1 << 0)
    public static let onlyPrivateChats = ChatListNodePeersFilter(rawValue: 1 << 1)
    public static let onlyGroups = ChatListNodePeersFilter(rawValue: 1 << 2)
    public static let onlyChannels = ChatListNodePeersFilter(rawValue: 1 << 3)
    public static let onlyManageable = ChatListNodePeersFilter(rawValue: 1 << 4)
    
    public static let excludeSecretChats = ChatListNodePeersFilter(rawValue: 1 << 5)
    public static let excludeRecent = ChatListNodePeersFilter(rawValue: 1 << 6)
    public static let excludeSavedMessages = ChatListNodePeersFilter(rawValue: 1 << 7)
    
    public static let doNotSearchMessages = ChatListNodePeersFilter(rawValue: 1 << 8)
    public static let removeSearchHeader = ChatListNodePeersFilter(rawValue: 1 << 9)
    
    public static let excludeDisabled = ChatListNodePeersFilter(rawValue: 1 << 10)
    public static let includeSavedMessages = ChatListNodePeersFilter(rawValue: 1 << 11)
    
    public static let excludeChannels = ChatListNodePeersFilter(rawValue: 1 << 12)
    public static let onlyGroupsAndChannels = ChatListNodePeersFilter(rawValue: 1 << 13)
    
    public static let excludeGroups = ChatListNodePeersFilter(rawValue: 1 << 14)
    public static let excludeUsers = ChatListNodePeersFilter(rawValue: 1 << 15)
    public static let excludeBots = ChatListNodePeersFilter(rawValue: 1 << 16)
}


public final class PeerSelectionControllerParams {
    public let context: AccountContext
    public let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    public let filter: ChatListNodePeersFilter
    public let requestPeerType: [ReplyMarkupButtonRequestPeerType]?
    public let forumPeerId: EnginePeer.Id?
    public let hasFilters: Bool
    public let hasChatListSelector: Bool
    public let hasContactSelector: Bool
    public let hasGlobalSearch: Bool
    public let title: String?
    public let attemptSelection: ((EnginePeer, Int64?) -> Void)?
    public let createNewGroup: (() -> Void)?
    public let pretendPresentedInModal: Bool
    public let multipleSelection: Bool
    public let forwardedMessageIds: [EngineMessage.Id]
    public let hasTypeHeaders: Bool
    public let selectForumThreads: Bool
    public let hasCreation: Bool
    
    /*public convenience init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        filter: ChatListNodePeersFilter = [.onlyWriteable],
        requestPeerType: [ReplyMarkupButtonRequestPeerType]? = nil,
        forumPeerId: EnginePeer.Id? = nil,
        hasFilters: Bool = false,
        hasChatListSelector: Bool = true,
        hasContactSelector: Bool = true,
        hasGlobalSearch: Bool = true,
        title: String? = nil,
        attemptSelection: ((EnginePeer, Int64?) -> Void)? = nil,
        createNewGroup: (() -> Void)? = nil,
        pretendPresentedInModal: Bool = false,
        multipleSelection: Bool = false,
        forwardedMessageIds: [EngineMessage.Id] = [],
        hasTypeHeaders: Bool = false,
        selectForumThreads: Bool = false,
        hasCreation: Bool = false
    ) {
        self.init(
            context: .account(context),
            updatedPresentationData: updatedPresentationData,
            filter: filter,
            requestPeerType: requestPeerType,
            forumPeerId: forumPeerId,
            hasFilters: hasFilters,
            hasChatListSelector: hasChatListSelector,
            hasContactSelector: hasContactSelector,
            hasGlobalSearch: hasGlobalSearch,
            title: title,
            attemptSelection: attemptSelection,
            createNewGroup: createNewGroup,
            pretendPresentedInModal: pretendPresentedInModal,
            multipleSelection: multipleSelection,
            forwardedMessageIds: forwardedMessageIds,
            hasTypeHeaders: hasTypeHeaders,
            selectForumThreads: selectForumThreads,
            hasCreation: hasCreation
        )
    }*/
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        filter: ChatListNodePeersFilter = [.onlyWriteable],
        requestPeerType: [ReplyMarkupButtonRequestPeerType]? = nil,
        forumPeerId: EnginePeer.Id? = nil,
        hasFilters: Bool = false,
        hasChatListSelector: Bool = true,
        hasContactSelector: Bool = true,
        hasGlobalSearch: Bool = true,
        title: String? = nil,
        attemptSelection: ((EnginePeer, Int64?) -> Void)? = nil,
        createNewGroup: (() -> Void)? = nil,
        pretendPresentedInModal: Bool = false,
        multipleSelection: Bool = false,
        forwardedMessageIds: [EngineMessage.Id] = [],
        hasTypeHeaders: Bool = false,
        selectForumThreads: Bool = false,
        hasCreation: Bool = false
    ) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.filter = filter
        self.requestPeerType = requestPeerType
        self.forumPeerId = forumPeerId
        self.hasFilters = hasFilters
        self.hasChatListSelector = hasChatListSelector
        self.hasContactSelector = hasContactSelector
        self.hasGlobalSearch = hasGlobalSearch
        self.title = title
        self.attemptSelection = attemptSelection
        self.createNewGroup = createNewGroup
        self.pretendPresentedInModal = pretendPresentedInModal
        self.multipleSelection = multipleSelection
        self.forwardedMessageIds = forwardedMessageIds
        self.hasTypeHeaders = hasTypeHeaders
        self.selectForumThreads = selectForumThreads
        self.hasCreation = hasCreation
    }
}

public enum AttachmentTextInputPanelSendMode {
    case generic
    case silent
    case schedule
    case whenOnline
}

public enum PeerSelectionControllerContext {
    public final class Custom {
        public let accountPeerId: EnginePeer.Id
        public let postbox: Postbox
        public let network: Network
        public let animationCache: AnimationCache
        public let animationRenderer: MultiAnimationRenderer
        public let presentationData: PresentationData
        public let updatedPresentationData: Signal<PresentationData, NoError>
        
        public init(
            accountPeerId: EnginePeer.Id,
            postbox: Postbox,
            network: Network,
            animationCache: AnimationCache,
            animationRenderer: MultiAnimationRenderer,
            presentationData: PresentationData,
            updatedPresentationData: Signal<PresentationData, NoError>
        ) {
            self.accountPeerId = accountPeerId
            self.postbox = postbox
            self.network = network
            self.animationCache = animationCache
            self.animationRenderer = animationRenderer
            self.presentationData = presentationData
            self.updatedPresentationData = updatedPresentationData
        }
    }
    
    case account(AccountContext)
    case custom(Custom)
}

public protocol PeerSelectionController: ViewController {
    var peerSelected: ((EnginePeer, Int64?) -> Void)? { get set }
    var multiplePeersSelected: (([EnginePeer], [EnginePeer.Id: EnginePeer], NSAttributedString, AttachmentTextInputPanelSendMode, ChatInterfaceForwardOptionsState?) -> Void)? { get set }
    var inProgress: Bool { get set }
    var customDismiss: (() -> Void)? { get set }
}
