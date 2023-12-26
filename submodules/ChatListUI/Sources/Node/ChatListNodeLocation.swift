import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import TelegramUIPreferences
import AccountContext

enum ChatListNodeLocation: Equatable {
    case initial(count: Int, filter: ChatListFilter?)
    case navigation(index: EngineChatList.Item.Index, filter: ChatListFilter?)
    case scroll(index: EngineChatList.Item.Index, sourceIndex: EngineChatList.Item.Index, scrollPosition: ListViewScrollPosition, animated: Bool, filter: ChatListFilter?)
    
    var filter: ChatListFilter? {
        switch self {
        case let .initial(_, filter):
            return filter
        case let .navigation(_, filter):
            return filter
        case let .scroll(_, _, _, _, filter):
            return filter
        }
    }
}

struct ChatListNodeViewUpdate {
    let list: EngineChatList
    let type: ViewUpdateType
    let scrollPosition: ChatListNodeViewScrollPosition?
}

public func chatListFilterPredicate(filter: ChatListFilterData, accountPeerId: EnginePeer.Id) -> ChatListFilterPredicate {
    let includePeers = Set(filter.includePeers.peers)
    let excludePeers = Set(filter.excludePeers)
    
    // commented out to fix bug: pinning user chat in folder hides secret chats of the same user
//    if !filter.includePeers.pinnedPeers.isEmpty {
//        includePeers.subtract(filter.includePeers.pinnedPeers)
//        excludePeers.subtract(filter.includePeers.pinnedPeers)
//    }
    
    var includeAdditionalPeerGroupIds: [PeerGroupId] = []
    if !filter.excludeArchived {
        includeAdditionalPeerGroupIds.append(Namespaces.PeerGroup.archive)
    }
    
    var messageTagSummary: ChatListMessageTagSummaryResultCalculation?
    if filter.excludeRead || filter.excludeMuted {
        messageTagSummary = ChatListMessageTagSummaryResultCalculation(addCount: ChatListMessageTagSummaryResultComponent(tag: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud), subtractCount: ChatListMessageTagActionsSummaryResultComponent(type: PendingMessageActionType.consumeUnseenPersonalMessage, namespace: Namespaces.Message.Cloud))
    }
    return ChatListFilterPredicate(includePeerIds: includePeers, excludePeerIds: excludePeers, pinnedPeerIds: filter.includePeers.pinnedPeers, messageTagSummary: messageTagSummary, includeAdditionalPeerGroupIds: includeAdditionalPeerGroupIds, include: { peer, isMuted, isUnread, isContact, messageTagSummaryResult in
        if filter.excludeRead {
            var effectiveUnread = isUnread
            if let messageTagSummaryResult = messageTagSummaryResult, messageTagSummaryResult {
                effectiveUnread = true
            }
            if !effectiveUnread {
                return false
            }
        }
        if filter.excludeMuted {
            if isMuted {
                if let messageTagSummaryResult = messageTagSummaryResult, messageTagSummaryResult {
                } else {
                    return false
                }
            }
        }
        if !filter.categories.contains(.contacts) && isContact {
            if let user = peer as? TelegramUser {
                if user.botInfo == nil {
                    return false
                }
            } else if let _ = peer as? TelegramSecretChat {
                return false
            }
        }
        if peer.id == accountPeerId {
            return false
        }
        if !filter.categories.contains(.nonContacts) && !isContact {
            if let user = peer as? TelegramUser {
                if user.botInfo == nil {
                    return false
                }
            } else if let _ = peer as? TelegramSecretChat {
                return false
            }
        }
        if !filter.categories.contains(.bots) {
            if let user = peer as? TelegramUser {
                if user.botInfo != nil {
                    return false
                }
            }
        }
        if !filter.categories.contains(.groups) {
            if let _ = peer as? TelegramGroup {
                return false
            } else if let channel = peer as? TelegramChannel {
                if case .group = channel.info {
                    return false
                }
            }
        }
        if !filter.categories.contains(.channels) {
            if let channel = peer as? TelegramChannel {
                if case .broadcast = channel.info {
                    return false
                }
            }
        }
        return true
    })
}

func chatListViewForLocation(chatListLocation: ChatListControllerLocation, location: ChatListNodeLocation, account: Account, inactiveSecretChatPeerIds: Signal<Set<PeerId>, NoError>) -> Signal<ChatListNodeViewUpdate, NoError> {
    switch chatListLocation {
    case let .chatList(groupId):
        let filterPredicate: ChatListFilterPredicate?
        if let filter = location.filter, case let .filter(_, _, _, data) = filter {
            filterPredicate = chatListFilterPredicate(filter: data, accountPeerId: account.peerId)
        } else {
            filterPredicate = nil
        }
        
        switch location {
        case let .initial(count, _):
            let signal: Signal<(ChatListView, ViewUpdateType), NoError>
            signal = account.viewTracker.tailChatListView(groupId: groupId._asGroup(), filterPredicate: filterPredicate, count: count, inactiveSecretChatPeerIds: inactiveSecretChatPeerIds)
            return signal
            |> map { view, updateType -> ChatListNodeViewUpdate in
                return ChatListNodeViewUpdate(list: EngineChatList(view), type: updateType, scrollPosition: nil)
            }
        case let .navigation(index, _):
            guard case let .chatList(index) = index else {
                return .never()
            }
            var first = true
            return account.viewTracker.aroundChatListView(groupId: groupId._asGroup(), filterPredicate: filterPredicate, index: index, count: 80, inactiveSecretChatPeerIds: inactiveSecretChatPeerIds)
            |> map { view, updateType -> ChatListNodeViewUpdate in
                let genericType: ViewUpdateType
                if first {
                    first = false
                    genericType = ViewUpdateType.UpdateVisible
                } else {
                    genericType = updateType
                }
                return ChatListNodeViewUpdate(list: EngineChatList(view), type: genericType, scrollPosition: nil)
            }
        case let .scroll(index, sourceIndex, scrollPosition, animated, _):
            guard case let .chatList(index) = index else {
                return .never()
            }
            
            let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > .chatList(index) ? .Down : .Up
            let chatScrollPosition: ChatListNodeViewScrollPosition = .index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
            var first = true
            return account.viewTracker.aroundChatListView(groupId: groupId._asGroup(), filterPredicate: filterPredicate, index: index, count: 80, inactiveSecretChatPeerIds: inactiveSecretChatPeerIds)
            |> map { view, updateType -> ChatListNodeViewUpdate in
                let genericType: ViewUpdateType
                let scrollPosition: ChatListNodeViewScrollPosition? = first ? chatScrollPosition : nil
                if first {
                    first = false
                    genericType = ViewUpdateType.UpdateVisible
                } else {
                    genericType = updateType
                }
                return ChatListNodeViewUpdate(list: EngineChatList(view), type: genericType, scrollPosition: scrollPosition)
            }
        }
    case let .forum(peerId):
        let viewKey: PostboxViewKey = .messageHistoryThreadIndex(
            id: peerId,
            summaryComponents: ChatListEntrySummaryComponents(
                components: [
                    ChatListEntryMessageTagSummaryKey(
                        tag: .unseenPersonalMessage,
                        actionType: PendingMessageActionType.consumeUnseenPersonalMessage
                    ): ChatListEntrySummaryComponents.Component(
                        tagSummary: ChatListEntryMessageTagSummaryComponent(namespace: Namespaces.Message.Cloud),
                        actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent(namespace: Namespaces.Message.Cloud)
                    ),
                    ChatListEntryMessageTagSummaryKey(
                        tag: .unseenReaction,
                        actionType: PendingMessageActionType.readReaction
                    ): ChatListEntrySummaryComponents.Component(
                        tagSummary: ChatListEntryMessageTagSummaryComponent(namespace: Namespaces.Message.Cloud),
                        actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent(namespace: Namespaces.Message.Cloud)
                    )
                ]
            )
        )
        
        let readStateKey: PostboxViewKey = .combinedReadState(peerId: peerId, handleThreads: false)
        
        var isFirst = false
        return account.postbox.combinedView(keys: [viewKey, readStateKey])
        |> map { views -> ChatListNodeViewUpdate in
            guard let view = views.views[viewKey] as? MessageHistoryThreadIndexView else {
                preconditionFailure()
            }
            guard let readStateView = views.views[readStateKey] as? CombinedReadStateView else {
                preconditionFailure()
            }
            
            var maxReadId: Int32 = 0
            if let state = readStateView.state?.states.first(where: { $0.0 == Namespaces.Message.Cloud }) {
                if case let .idBased(maxIncomingReadId, _, _, _, _) = state.1 {
                    maxReadId = maxIncomingReadId
                }
            }
            
            var items: [EngineChatList.Item] = []
            for item in view.items {
                guard let peer = view.peer else {
                    continue
                }
                guard let data = item.info.get(MessageHistoryThreadData.self) else {
                    continue
                }
                
                let defaultPeerNotificationSettings: TelegramPeerNotificationSettings = (view.peerNotificationSettings as? TelegramPeerNotificationSettings) ?? .defaultSettings
                
                var hasUnseenMentions = false
                
                var isMuted = false
                switch data.notificationSettings.muteState {
                case .muted:
                    isMuted = true
                case .unmuted:
                    isMuted = false
                case .default:
                    if case .default = data.notificationSettings.muteState {
                        if case .muted = defaultPeerNotificationSettings.muteState {
                            isMuted = true
                        }
                    }
                }
                
                if let info = item.tagSummaryInfo[ChatListEntryMessageTagSummaryKey(
                    tag: .unseenPersonalMessage,
                    actionType: PendingMessageActionType.consumeUnseenPersonalMessage
                )] {
                    hasUnseenMentions = (info.tagSummaryCount ?? 0) > (info.actionsSummaryCount ?? 0)
                }
                
                var hasUnseenReactions = false
                if let info = item.tagSummaryInfo[ChatListEntryMessageTagSummaryKey(
                    tag: .unseenReaction,
                    actionType: PendingMessageActionType.readReaction
                )] {
                    hasUnseenReactions = (info.tagSummaryCount ?? 0) != 0// > (info.actionsSummaryCount ?? 0)
                }
                
                let pinnedIndex: EngineChatList.Item.PinnedIndex
                if let index = item.pinnedIndex {
                    pinnedIndex = .index(index)
                } else {
                    pinnedIndex = .none
                }
                
                var topicMaxIncomingReadId = data.maxIncomingReadId
                if data.maxIncomingReadId == 0 && maxReadId != 0 && Int64(maxReadId) <= item.id {
                    topicMaxIncomingReadId = max(topicMaxIncomingReadId, maxReadId)
                }
                
                let readCounters = EnginePeerReadCounters(state: CombinedPeerReadState(states: [(Namespaces.Message.Cloud, .idBased(maxIncomingReadId: topicMaxIncomingReadId, maxOutgoingReadId: data.maxOutgoingReadId, maxKnownId: 1, count: data.incomingUnreadCount, markedUnread: false))]), isMuted: false)
                
                var draft: EngineChatList.Draft?
                if let embeddedState = item.embeddedInterfaceState, let _ = embeddedState.overrideChatTimestamp {
                    if let opaqueState = _internal_decodeStoredChatInterfaceState(state: embeddedState) {
                        if let text = opaqueState.synchronizeableInputState?.text {
                            draft = EngineChatList.Draft(text: text, entities: opaqueState.synchronizeableInputState?.entities ?? [])
                        }
                    }
                }
                
                items.append(EngineChatList.Item(
                    id: .forum(item.id),
                    index: .forum(pinnedIndex: pinnedIndex, timestamp: item.index.timestamp, threadId: item.id, namespace: item.index.id.namespace, id: item.index.id.id),
                    messages: item.topMessage.flatMap { [EngineMessage($0)] } ?? [],
                    readCounters: readCounters,
                    isMuted: isMuted,
                    draft: draft,
                    threadData: data,
                    renderedPeer: EngineRenderedPeer(peer: EnginePeer(peer)),
                    presence: nil,
                    hasUnseenMentions: hasUnseenMentions,
                    hasUnseenReactions: hasUnseenReactions,
                    forumTopicData: nil,
                    topForumTopicItems: [],
                    hasFailed: false,
                    isContact: false,
                    autoremoveTimeout: nil,
                    storyStats: nil
                ))
            }
            
            let list = EngineChatList(
                items: items.reversed(),
                groupItems: [],
                additionalItems: [],
                hasEarlier: false,
                hasLater: false,
                isLoading: view.isLoading
            )
            
            let type: ViewUpdateType
            if isFirst {
                type = .Initial
            } else {
                type = .Generic
            }
            isFirst = false
            return ChatListNodeViewUpdate(list: list, type: type, scrollPosition: nil)
        }
    case .savedMessagesChats:
        var isFirst = true
        
        return account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: account.peerId, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, count: 1000, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: Set(), tagMask: nil, appendMessagesFromTheSameGroup: false, namespaces: .not(Set([Namespaces.Message.ScheduledCloud, Namespaces.Message.ScheduledLocal])), orderStatistics: [])
        |> map { view, _, _ -> ChatListNodeViewUpdate in
            let isLoading = view.isLoading
            
            var items: [EngineChatList.Item] = []
            
            var topMessageByPeerId: [EnginePeer.Id: Message] = [:]
            if !isLoading {
                for entry in view.entries {
                    guard let threadId = entry.message.threadId else {
                        continue
                    }
                    let sourcePeerId = PeerId(threadId)
                    
                    if let currentTopMessage = topMessageByPeerId[sourcePeerId] {
                        if currentTopMessage.index < entry.index {
                            topMessageByPeerId[sourcePeerId] = entry.message
                        }
                    } else {
                        topMessageByPeerId[sourcePeerId] = entry.message
                    }
                }
                for (_, message) in topMessageByPeerId.sorted(by: { $0.value.index > $1.value.index }) {
                    guard let threadId = message.threadId else {
                        continue
                    }
                    let sourceId = PeerId(threadId)
                    var sourcePeer = message.peers[sourceId]
                    if sourcePeer == nil, let forwardInfo = message.forwardInfo, let authorSignature = forwardInfo.authorSignature {
                        sourcePeer = TelegramUser(
                            id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(1)),
                            accessHash: nil,
                            firstName: authorSignature,
                            lastName: nil,
                            username: nil,
                            phone: nil,
                            photo: [],
                            botInfo: nil,
                            restrictionInfo: nil,
                            flags: [],
                            emojiStatus: nil,
                            usernames: [],
                            storiesHidden: nil,
                            nameColor: nil,
                            backgroundEmojiId: nil,
                            profileColor: nil,
                            profileBackgroundEmojiId: nil
                        )
                    }
                    guard let sourcePeer else {
                        continue
                    }
                    let mappedMessageIndex = MessageIndex(id: MessageId(peerId: sourceId, namespace: message.index.id.namespace, id: message.index.id.id), timestamp: message.index.timestamp)
                    items.append(EngineChatList.Item(
                        id: .chatList(sourceId),
                        index: .chatList(ChatListIndex(pinningIndex: nil, messageIndex: mappedMessageIndex)),
                        messages: [EngineMessage(message)],
                        readCounters: nil,
                        isMuted: false,
                        draft: nil,
                        threadData: nil,
                        renderedPeer: EngineRenderedPeer(peer: EnginePeer(sourcePeer)),
                        presence: nil,
                        hasUnseenMentions: false,
                        hasUnseenReactions: false,
                        forumTopicData: nil,
                        topForumTopicItems: [],
                        hasFailed: false,
                        isContact: false,
                        autoremoveTimeout: nil,
                        storyStats: nil
                    ))
                }
            }
            
            let list = EngineChatList(
                items: items.reversed(),
                groupItems: [],
                additionalItems: [],
                hasEarlier: false,
                hasLater: false,
                isLoading: isLoading
            )
            
            let type: ViewUpdateType
            if isFirst {
                type = .Initial
            } else {
                type = .Generic
            }
            isFirst = false
            return ChatListNodeViewUpdate(list: list, type: type, scrollPosition: nil)
        }
    }
}
