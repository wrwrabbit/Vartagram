import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public enum AddressNameValidationStatus: Equatable {
    case checking
    case invalidFormat(AddressNameFormatError)
    case availability(AddressNameAvailability)
}

public typealias EngineStringIndexTokenTransliteration = StringIndexTokenTransliteration

public final class OpaqueChatInterfaceState {
    public let opaqueData: Data?
    public let historyScrollMessageIndex: MessageIndex?
    public let synchronizeableInputState: SynchronizeableChatInputState?

    public init(
        opaqueData: Data?,
        historyScrollMessageIndex: MessageIndex?,
        synchronizeableInputState: SynchronizeableChatInputState?
    ) {
        self.opaqueData = opaqueData
        self.historyScrollMessageIndex = historyScrollMessageIndex
        self.synchronizeableInputState = synchronizeableInputState
    }
}

public extension TelegramEngine {
    enum NextUnreadChannelLocation: Equatable {
        case same
        case archived
        case unarchived
        case folder(id: Int32, title: String)
    }

    final class Peers {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func addressNameAvailability(domain: AddressNameDomain, name: String) -> Signal<AddressNameAvailability, NoError> {
            return _internal_addressNameAvailability(account: self.account, domain: domain, name: name)
        }

        public func updateAddressName(domain: AddressNameDomain, name: String?) -> Signal<Void, UpdateAddressNameError> {
            return _internal_updateAddressName(account: self.account, domain: domain, name: name)
        }
        
        public func deactivateAllAddressNames(peerId: EnginePeer.Id) -> Signal<Never, DeactivateAllAddressNamesError> {
            return _internal_deactivateAllAddressNames(account: self.account, peerId: peerId)
        }
        
        public func toggleAddressNameActive(domain: AddressNameDomain, name: String, active: Bool) -> Signal<Void, ToggleAddressNameActiveError> {
            return _internal_toggleAddressNameActive(account: self.account, domain: domain, name: name, active: active)
        }
        
        public func reorderAddressNames(domain: AddressNameDomain, names: [TelegramPeerUsername]) -> Signal<Void, ReorderAddressNamesError> {
            return _internal_reorderAddressNames(account: self.account, domain: domain, names: names)
        }
        
        public func checkPublicChannelCreationAvailability(location: Bool = false) -> Signal<Bool, NoError> {
            return _internal_checkPublicChannelCreationAvailability(account: self.account, location: location)
        }

        public func adminedPublicChannels(scope: AdminedPublicChannelsScope = .all) -> Signal<[EnginePeer], NoError> {
            return _internal_adminedPublicChannels(account: self.account, scope: scope)
            |> map { peers -> [EnginePeer] in
                return peers.map(EnginePeer.init)
            }
        }
        
        public func channelsForStories() -> Signal<[EnginePeer], NoError> {
            return _internal_channelsForStories(account: self.account)
            |> map { peers -> [EnginePeer] in
                return peers.map(EnginePeer.init)
            }
        }

        public func channelAddressNameAssignmentAvailability(peerId: PeerId?) -> Signal<ChannelAddressNameAssignmentAvailability, NoError> {
            return _internal_channelAddressNameAssignmentAvailability(account: self.account, peerId: peerId)
        }

        public func validateAddressNameInteractive(domain: AddressNameDomain, name: String) -> Signal<AddressNameValidationStatus, NoError> {
            if let error = _internal_checkAddressNameFormat(name) {
                return .single(.invalidFormat(error))
            } else {
                return .single(.checking)
                |> then(
                    self.addressNameAvailability(domain: domain, name: name)
                    |> delay(0.3, queue: Queue.concurrentDefaultQueue())
                    |> map { result -> AddressNameValidationStatus in
                        .availability(result)
                    }
                )
            }
        }

        public func findChannelById(channelId: Int64) -> Signal<EnginePeer?, NoError> {
            return _internal_findChannelById(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, channelId: channelId)
            |> map { peer in
                return peer.flatMap(EnginePeer.init)
            }
        }

        public func supportPeerId() -> Signal<PeerId?, NoError> {
            return _internal_supportPeerId(account: self.account)
        }

        public func inactiveChannelList() -> Signal<[InactiveChannel], NoError> {
            return _internal_inactiveChannelList(network: self.account.network)
        }

        public func resolvePeerByName(name: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<ResolvePeerResult, NoError> {
            return _internal_resolvePeerByName(account: self.account, name: name, ageLimit: ageLimit)
            |> mapToSignal { result -> Signal<ResolvePeerResult, NoError> in
                switch result {
                case .progress:
                    return .single(.progress)
                case let .result(peerId):
                    guard let peerId = peerId else {
                        return .single(.result(nil))
                    }
                    return self.account.postbox.transaction { transaction -> ResolvePeerResult in
                        return .result(transaction.getPeer(peerId).flatMap(EnginePeer.init))
                    }
                }
            }
        }
        
        public func resolvePeerByPhone(phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<EnginePeer?, NoError> {
            return _internal_resolvePeerByPhone(account: self.account, phone: phone, ageLimit: ageLimit)
            |> mapToSignal { peerId -> Signal<EnginePeer?, NoError> in
                guard let peerId = peerId else {
                    return .single(nil)
                }
                return self.account.postbox.transaction { transaction -> EnginePeer? in
                    return transaction.getPeer(peerId).flatMap(EnginePeer.init)
                }
            }
        }

        public func updatedRemotePeer(peer: PeerReference) -> Signal<Peer, UpdatedRemotePeerError> {
            return _internal_updatedRemotePeer(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, peer: peer)
        }

        public func chatOnlineMembers(peerId: PeerId) -> Signal<Int32, NoError> {
            return _internal_chatOnlineMembers(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func convertGroupToSupergroup(peerId: PeerId, additionalProcessing: ((EnginePeer.Id) -> Signal<Never, NoError>)? = nil) -> Signal<PeerId, ConvertGroupToSupergroupError> {
            return _internal_convertGroupToSupergroup(account: self.account, peerId: peerId, additionalProcessing: additionalProcessing)
        }

        public func createGroup(title: String, peerIds: [PeerId], ttlPeriod: Int32?) -> Signal<CreateGroupResult?, CreateGroupError> {
            return _internal_createGroup(account: self.account, title: title, peerIds: peerIds, ttlPeriod: ttlPeriod)
        }

        public func createSecretChat(peerId: PeerId) -> Signal<PeerId, CreateSecretChatError> {
            return _internal_createSecretChat(account: self.account, peerId: peerId)
        }

        public func setChatMessageAutoremoveTimeoutInteractively(peerId: PeerId, timeout: Int32?) -> Signal<Never, SetChatMessageAutoremoveTimeoutError> {
            if peerId.namespace == Namespaces.Peer.SecretChat {
                return _internal_setSecretChatMessageAutoremoveTimeoutInteractively(account: self.account, peerId: peerId, timeout: timeout)
                |> ignoreValues
                    |> castError(SetChatMessageAutoremoveTimeoutError.self)
            } else {
                return _internal_setChatMessageAutoremoveTimeoutInteractively(account: self.account, peerId: peerId, timeout: timeout)
            }
        }
        
        public func setChatMessageAutoremoveTimeouts(peerIds: [EnginePeer.Id], timeout: Int32?) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    if peerId.namespace == Namespaces.Peer.SecretChat {
                        _internal_setSecretChatMessageAutoremoveTimeoutInteractively(transaction: transaction, account: self.account, peerId: peerId, timeout: timeout)
                    } else {
                        var canManage = false
                        guard let peer = transaction.getPeer(peerId) else {
                            continue
                        }
                        if let user = peer as? TelegramUser {
                            if user.botInfo == nil {
                                canManage = true
                            }
                        } else if let _ = peer as? TelegramSecretChat {
                            canManage = true
                        } else if let group = peer as? TelegramGroup {
                            canManage = !group.hasBannedPermission(.banChangeInfo)
                        } else if let channel = peer as? TelegramChannel {
                            canManage = channel.hasPermission(.changeInfo)
                        }
                        
                        if !canManage {
                            continue
                        }
                        
                        let cachedData = transaction.getPeerCachedData(peerId: peerId)
                        var currentValue: Int32?
                        if let cachedData = cachedData as? CachedUserData {
                            if case let .known(value) = cachedData.autoremoveTimeout {
                                currentValue = value?.effectiveValue
                            }
                        } else if let cachedData = cachedData as? CachedGroupData {
                            if case let .known(value) = cachedData.autoremoveTimeout {
                                currentValue = value?.effectiveValue
                            }
                        } else if let cachedData = cachedData as? CachedChannelData {
                            if case let .known(value) = cachedData.autoremoveTimeout {
                                currentValue = value?.effectiveValue
                            }
                        }
                        if currentValue != timeout {
                            let _ = _internal_setChatMessageAutoremoveTimeoutInteractively(account: self.account, peerId: peerId, timeout: timeout).start()
                        }
                    }
                }
            }
            |> ignoreValues
        }

        public func updateChannelSlowModeInteractively(peerId: PeerId, timeout: Int32?) -> Signal<Void, UpdateChannelSlowModeError> {
            return _internal_updateChannelSlowModeInteractively(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: peerId, timeout: timeout)
        }

        public func reportPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_reportPeer(account: self.account, peerId: peerId)
        }

        public func reportPeer(peerId: PeerId, reason: ReportReason, message: String) -> Signal<Void, NoError> {
            return _internal_reportPeer(account: self.account, peerId: peerId, reason: reason, message: message)
        }

        public func reportPeerPhoto(peerId: PeerId, reason: ReportReason, message: String) -> Signal<Void, NoError> {
            return _internal_reportPeerPhoto(account: self.account, peerId: peerId, reason: reason, message: message)
        }

        public func reportPeerMessages(messageIds: [MessageId], reason: ReportReason, message: String) -> Signal<Void, NoError> {
            return _internal_reportPeerMessages(account: self.account, messageIds: messageIds, reason: reason, message: message)
        }
        
        public func reportPeerStory(peerId: PeerId, storyId: Int32, reason: ReportReason, message: String) -> Signal<Void, NoError> {
            return _internal_reportPeerStory(account: self.account, peerId: peerId, storyId: storyId, reason: reason, message: message)
        }
        
        public func reportPeerReaction(authorId: PeerId, messageId: MessageId) -> Signal<Never, NoError> {
            return _internal_reportPeerReaction(account: self.account, authorId: authorId, messageId: messageId)
        }

        public func dismissPeerStatusOptions(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_dismissPeerStatusOptions(account: self.account, peerId: peerId)
        }

        public func reportRepliesMessage(messageId: MessageId, deleteMessage: Bool, deleteHistory: Bool, reportSpam: Bool) -> Signal<Never, NoError> {
            return _internal_reportRepliesMessage(account: self.account, messageId: messageId, deleteMessage: deleteMessage, deleteHistory: deleteHistory, reportSpam: reportSpam)
        }

        public func togglePeerMuted(peerId: PeerId, threadId: Int64?) -> Signal<Void, NoError> {
            return _internal_togglePeerMuted(account: self.account, peerId: peerId, threadId: threadId)
        }
        
        public func togglePeerStoriesMuted(peerId: EnginePeer.Id) -> Signal<Never, NoError> {
            return _internal_togglePeerStoriesMuted(account: self.account, peerId: peerId)
            |> ignoreValues
        }

        public func updatePeerMuteSetting(peerId: PeerId, threadId: Int64?, muteInterval: Int32?) -> Signal<Void, NoError> {
            return _internal_updatePeerMuteSetting(account: self.account, peerId: peerId, threadId: threadId, muteInterval: muteInterval)
        }
        
        public func updateMultiplePeerMuteSettings(peerIds: [EnginePeer.Id], muted: Bool) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_updatePeerMuteSetting(account: self.account, transaction: transaction, peerId: peerId, threadId: nil, muteInterval: muted ? Int32.max : nil)
                }
            }
            |> ignoreValues
        }

        public func updatePeerDisplayPreviewsSetting(peerId: PeerId, threadId: Int64?, displayPreviews: PeerNotificationDisplayPreviews) -> Signal<Void, NoError> {
            return _internal_updatePeerDisplayPreviewsSetting(account: self.account, peerId: peerId, threadId: threadId, displayPreviews: displayPreviews)
        }
        
        public func updatePeerStoriesMutedSetting(peerId: PeerId, mute: PeerStoryNotificationSettings.Mute) -> Signal<Void, NoError> {
            return _internal_updatePeerStoriesMutedSetting(account: self.account, peerId: peerId, mute: mute)
        }
        
        public func updatePeerStoriesHideSenderSetting(peerId: PeerId, hideSender: PeerStoryNotificationSettings.HideSender) -> Signal<Void, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_updatePeerStoriesHideSenderSetting(account: self.account, transaction: transaction, peerId: peerId, hideSender: hideSender)
            }
        }
        
        public func updatePeerStorySoundInteractive(peerId: PeerId, sound: PeerMessageSound) -> Signal<Void, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_updatePeerStoryNotificationSoundInteractive(account: self.account, transaction: transaction, peerId: peerId, sound: sound)
            }
        }

        public func updatePeerNotificationSoundInteractive(peerId: PeerId, threadId: Int64?, sound: PeerMessageSound) -> Signal<Void, NoError> {
            return _internal_updatePeerNotificationSoundInteractive(account: self.account, peerId: peerId, threadId: threadId, sound: sound)
        }

        public func removeCustomNotificationSettings(peerIds: [PeerId]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_updatePeerNotificationSoundInteractive(account: self.account, transaction: transaction, peerId: peerId, threadId: nil, sound: .default)
                    _internal_updatePeerMuteSetting(account: self.account, transaction: transaction, peerId: peerId, threadId: nil, muteInterval: nil)
                    _internal_updatePeerDisplayPreviewsSetting(account: self.account, transaction: transaction, peerId: peerId, threadId: nil, displayPreviews: .default)
                }
            }
            |> ignoreValues
        }
        
        public func removeCustomThreadNotificationSettings(peerId: EnginePeer.Id, threadIds: [Int64]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for threadId in threadIds {
                    _internal_updatePeerNotificationSoundInteractive(account: self.account, transaction: transaction, peerId: peerId, threadId: threadId, sound: .default)
                    _internal_updatePeerMuteSetting(account: self.account, transaction: transaction, peerId: peerId, threadId: threadId, muteInterval: nil)
                    _internal_updatePeerDisplayPreviewsSetting(account: self.account, transaction: transaction, peerId: peerId, threadId: threadId, displayPreviews: .default)
                }
            }
            |> ignoreValues
        }
        
        public func removeCustomStoryNotificationSettings(peerIds: [PeerId]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_updatePeerStoriesMutedSetting(account: self.account, transaction: transaction, peerId: peerId, mute: .default)
                    _internal_updatePeerStoriesHideSenderSetting(account: self.account, transaction: transaction, peerId: peerId, hideSender: .default)
                    _internal_updatePeerStoryNotificationSoundInteractive(account: self.account, transaction: transaction, peerId: peerId, sound: .default)
                }
            }
            |> ignoreValues
        }

        public func channelAdminEventLog(peerId: PeerId) -> ChannelAdminEventLogContext {
            return ChannelAdminEventLogContext(postbox: self.account.postbox, network: self.account.network, peerId: peerId, accountPeerId: self.account.peerId)
        }

        public func updateChannelMemberBannedRights(peerId: PeerId, memberId: PeerId, rights: TelegramChatBannedRights?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant?, Bool), NoError> {
            return _internal_updateChannelMemberBannedRights(account: self.account, peerId: peerId, memberId: memberId, rights: rights)
        }

        public func updateDefaultChannelMemberBannedRights(peerId: PeerId, rights: TelegramChatBannedRights) -> Signal<Never, NoError> {
            return _internal_updateDefaultChannelMemberBannedRights(account: self.account, peerId: peerId, rights: rights)
        }

        public func createChannel(title: String, description: String?, username: String? = nil) -> Signal<PeerId, CreateChannelError> {
            return _internal_createChannel(account: self.account, title: title, description: description, username: username)
        }

        public func createSupergroup(title: String, description: String?, username: String? = nil, isForum: Bool = false, location: (latitude: Double, longitude: Double, address: String)? = nil, isForHistoryImport: Bool = false) -> Signal<PeerId, CreateChannelError> {
            return _internal_createSupergroup(postbox: self.account.postbox, network: self.account.network, stateManager: account.stateManager, title: title, description: description, username: username, isForum: isForum, location: location, isForHistoryImport: isForHistoryImport)
        }

        public func deleteChannel(peerId: PeerId) -> Signal<Void, DeleteChannelError> {
            return _internal_deleteChannel(account: self.account, peerId: peerId)
        }

        public func updateChannelHistoryAvailabilitySettingsInteractively(peerId: PeerId, historyAvailableForNewMembers: Bool) -> Signal<Void, ChannelHistoryAvailabilityError> {
            return _internal_updateChannelHistoryAvailabilitySettingsInteractively(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: peerId, historyAvailableForNewMembers: historyAvailableForNewMembers)
        }

        public func channelMembers(peerId: PeerId, category: ChannelMembersCategory = .recent(.all), offset: Int32 = 0, limit: Int32 = 64, hash: Int64 = 0) -> Signal<[RenderedChannelParticipant]?, NoError> {
            return _internal_channelMembers(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, peerId: peerId, category: category, offset: offset, limit: limit, hash: hash)
        }

        public func checkOwnershipTranfserAvailability(memberId: PeerId) -> Signal<Never, ChannelOwnershipTransferError> {
            return _internal_checkOwnershipTranfserAvailability(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, memberId: memberId)
        }

        public func updateChannelOwnership(channelId: PeerId, memberId: PeerId, password: String) -> Signal<[(ChannelParticipant?, RenderedChannelParticipant)], ChannelOwnershipTransferError> {
            return _internal_updateChannelOwnership(account: self.account, accountStateManager: self.account.stateManager, channelId: channelId, memberId: memberId, password: password)
        }

        public func searchGroupMembers(peerId: PeerId, query: String) -> Signal<[EnginePeer], NoError> {
            return _internal_searchGroupMembers(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, peerId: peerId, query: query)
            |> map { peers -> [EnginePeer] in
                return peers.map { EnginePeer($0) }
            }
        }

        public func toggleShouldChannelMessagesSignatures(peerId: PeerId, enabled: Bool) -> Signal<Void, NoError> {
            return _internal_toggleShouldChannelMessagesSignatures(account: self.account, peerId: peerId, enabled: enabled)
        }

        public func toggleMessageCopyProtection(peerId: PeerId, enabled: Bool) -> Signal<Void, NoError> {
            return _internal_toggleMessageCopyProtection(account: self.account, peerId: peerId, enabled: enabled)
        }
        
        public func toggleChannelJoinToSend(peerId: PeerId, enabled: Bool) -> Signal<Never, UpdateChannelJoinToSendError> {
            return _internal_toggleChannelJoinToSend(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: peerId, enabled: enabled)
        }
        
        public func toggleChannelJoinRequest(peerId: PeerId, enabled: Bool) -> Signal<Never, UpdateChannelJoinRequestError> {
            return _internal_toggleChannelJoinRequest(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: peerId, enabled: enabled)
        }
        
        public func toggleAntiSpamProtection(peerId: PeerId, enabled: Bool) -> Signal<Void, NoError> {
            return _internal_toggleAntiSpamProtection(account: self.account, peerId: peerId, enabled: enabled)
        }
        
        public func reportAntiSpamFalsePositive(peerId: PeerId, messageId: MessageId) -> Signal<Bool, NoError> {
            return _internal_reportAntiSpamFalsePositive(account: self.account, peerId: peerId, messageId: messageId)
        }

        
        public func requestPeerPhotos(peerId: PeerId) -> Signal<[TelegramPeerPhoto], NoError> {
            return _internal_requestPeerPhotos(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func updateGroupSpecificStickerset(peerId: PeerId, info: StickerPackCollectionInfo?) -> Signal<Void, UpdateGroupSpecificStickersetError> {
            return _internal_updateGroupSpecificStickerset(postbox: self.account.postbox, network: self.account.network, peerId: peerId, info: info)
        }

        public func joinChannel(peerId: PeerId, hash: String?) -> Signal<RenderedChannelParticipant?, JoinChannelError> {
            return _internal_joinChannel(account: self.account, peerId: peerId, hash: hash)
        }

        public func removePeerMember(peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
            return _internal_removePeerMember(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func availableGroupsForChannelDiscussion() -> Signal<[EnginePeer], AvailableChannelDiscussionGroupError> {
            return _internal_availableGroupsForChannelDiscussion(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network)
            |> map { peers -> [EnginePeer] in
                return peers.map(EnginePeer.init)
            }
        }

        public func updateGroupDiscussionForChannel(channelId: PeerId?, groupId: PeerId?) -> Signal<Bool, ChannelDiscussionGroupError> {
            return _internal_updateGroupDiscussionForChannel(network: self.account.network, postbox: self.account.postbox, channelId: channelId, groupId: groupId)
        }

        public func peerCommands(id: PeerId) -> Signal<PeerCommands, NoError> {
            return _internal_peerCommands(account: self.account, id: id)
        }

        public func addGroupAdmin(peerId: PeerId, adminId: PeerId) -> Signal<Void, AddGroupAdminError> {
            return _internal_addGroupAdmin(account: self.account, peerId: peerId, adminId: adminId)
        }

        public func removeGroupAdmin(peerId: PeerId, adminId: PeerId) -> Signal<Void, RemoveGroupAdminError> {
            return _internal_removeGroupAdmin(account: self.account, peerId: peerId, adminId: adminId)
        }

        public func fetchChannelParticipant(peerId: PeerId, participantId: PeerId) -> Signal<ChannelParticipant?, NoError> {
            return _internal_fetchChannelParticipant(account: self.account, peerId: peerId, participantId: participantId)
        }

        public func updateChannelAdminRights(peerId: PeerId, adminId: PeerId, rights: TelegramChatAdminRights?, rank: String?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant), UpdateChannelAdminRightsError> {
            return _internal_updateChannelAdminRights(account: self.account, peerId: peerId, adminId: adminId, rights: rights, rank: rank)
        }

        public func peerSpecificStickerPack(peerId: PeerId) -> Signal<PeerSpecificStickerPackData, NoError> {
            return _internal_peerSpecificStickerPack(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func addRecentlySearchedPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_addRecentlySearchedPeer(postbox: self.account.postbox, peerId: peerId)
        }

        public func removeRecentlySearchedPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_removeRecentlySearchedPeer(postbox: self.account.postbox, peerId: peerId)
        }

        public func clearRecentlySearchedPeers() -> Signal<Void, NoError> {
            return _internal_clearRecentlySearchedPeers(postbox: self.account.postbox)
        }

        public func recentlySearchedPeers() -> Signal<[RecentlySearchedPeer], NoError> {
            return _internal_recentlySearchedPeers(postbox: self.account.postbox)
        }

        public func removePeerChat(peerId: PeerId, reportChatSpam: Bool, deleteGloballyIfPossible: Bool = false) -> Signal<Void, NoError> {
            return _internal_removePeerChat(account: self.account, peerId: peerId, reportChatSpam: reportChatSpam, deleteGloballyIfPossible: deleteGloballyIfPossible)
        }

        public func removePeerChats(peerIds: [PeerId]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_removePeerChat(account: self.account, transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: peerId, reportChatSpam: false, deleteGloballyIfPossible: peerId.namespace == Namespaces.Peer.SecretChat)
                }
            }
            |> ignoreValues
        }

        public func terminateSecretChat(peerId: PeerId, requestRemoteHistoryRemoval: Bool) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_terminateSecretChat(transaction: transaction, peerId: peerId, requestRemoteHistoryRemoval: requestRemoteHistoryRemoval)
            }
            |> ignoreValues
        }

        public func addGroupMember(peerId: PeerId, memberId: PeerId) -> Signal<Void, AddGroupMemberError> {
            return _internal_addGroupMember(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func addChannelMember(peerId: PeerId, memberId: PeerId) -> Signal<(ChannelParticipant?, RenderedChannelParticipant), AddChannelMemberError> {
            return _internal_addChannelMember(account: self.account, peerId: peerId, memberId: memberId)
        }
        
        public func sendBotRequestedPeer(messageId: MessageId, buttonId: Int32, requestedPeerId: PeerId) -> Signal<Void, SendBotRequestedPeerError> {
            return _internal_sendBotRequestedPeer(account: self.account, peerId: messageId.peerId, messageId: messageId, buttonId: buttonId, requestedPeerId: requestedPeerId)
        }

        public func addChannelMembers(peerId: PeerId, memberIds: [PeerId]) -> Signal<Void, AddChannelMemberError> {
            return _internal_addChannelMembers(account: self.account, peerId: peerId, memberIds: memberIds)
        }

        public func recentPeers() -> Signal<RecentPeers, NoError> {
            return _internal_recentPeers(accountPeerId: self.account.peerId, postbox: self.account.postbox)
        }

        public func managedUpdatedRecentPeers() -> Signal<Void, NoError> {
            return _internal_managedUpdatedRecentPeers(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network)
        }

        public func removeRecentPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_removeRecentPeer(account: self.account, peerId: peerId)
        }

        public func updateRecentPeersEnabled(enabled: Bool) -> Signal<Void, NoError> {
            return _internal_updateRecentPeersEnabled(postbox: self.account.postbox, network: self.account.network, enabled: enabled)
        }

        public func addRecentlyUsedInlineBot(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_addRecentlyUsedInlineBot(postbox: self.account.postbox, peerId: peerId)
        }

        public func recentlyUsedInlineBots() -> Signal<[(EnginePeer, Double)], NoError> {
            return _internal_recentlyUsedInlineBots(postbox: self.account.postbox)
            |> map { list -> [(EnginePeer, Double)] in
                return list.map { peer, rating in
                    return (EnginePeer(peer), rating)
                }
            }
        }

        public func removeRecentlyUsedInlineBot(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_removeRecentlyUsedInlineBot(account: self.account, peerId: peerId)
        }

        public func uploadedPeerPhoto(resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
            return _internal_uploadedPeerPhoto(postbox: self.account.postbox, network: self.account.network, resource: resource)
        }

        public func uploadedPeerVideo(resource: MediaResource) -> Signal<UploadedPeerPhotoData, NoError> {
            return _internal_uploadedPeerVideo(postbox: self.account.postbox, network: self.account.network, messageMediaPreuploadManager: self.account.messageMediaPreuploadManager, resource: resource)
        }

        public func updatePeerPhoto(peerId: PeerId, photo: Signal<UploadedPeerPhotoData, NoError>?, video: Signal<UploadedPeerPhotoData?, NoError>? = nil, videoStartTimestamp: Double? = nil, markup: UploadPeerPhotoMarkup? = nil, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
            return _internal_updatePeerPhoto(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, accountPeerId: self.account.peerId, peerId: peerId, photo: photo, video: video, videoStartTimestamp: videoStartTimestamp, markup: markup, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
        }

        public func requestUpdateChatListFilter(id: Int32, filter: ChatListFilter?) -> Signal<Never, RequestUpdateChatListFilterError> {
            return _internal_requestUpdateChatListFilter(postbox: self.account.postbox, network: self.account.network, id: id, filter: filter)
        }

        public func requestUpdateChatListFilterOrder(ids: [Int32]) -> Signal<Never, RequestUpdateChatListFilterOrderError> {
            return _internal_requestUpdateChatListFilterOrder(account: self.account, ids: ids)
        }

        public func generateNewChatListFilterId(filters: [ChatListFilter]) -> Int32 {
            return _internal_generateNewChatListFilterId(filters: filters)
        }

        public func updateChatListFiltersInteractively(_ f: @escaping ([ChatListFilter]) -> [ChatListFilter]) -> Signal<[ChatListFilter], NoError> {
            return _internal_updateChatListFiltersInteractively(postbox: self.account.postbox, f)
        }

        public func updatedChatListFilters() -> Signal<[ChatListFilter], NoError> {
            return _internal_updatedChatListFilters(postbox: self.account.postbox, hiddenIds: self.account.viewTracker.hiddenChatListFilterIds)
        }
        
        public func chatListFiltersAreSynced() -> Signal<Bool, NoError> {
            return _internal_chatListFiltersAreSynced(postbox: self.account.postbox)
        }

        public func updatedChatListFiltersInfo() -> Signal<(filters: [ChatListFilter], synchronized: Bool), NoError> {
            return _internal_updatedChatListFiltersInfo(postbox: self.account.postbox)
        }

        public func currentChatListFilters() -> Signal<[ChatListFilter], NoError> {
            return _internal_currentChatListFilters(postbox: self.account.postbox)
        }

        public func markChatListFeaturedFiltersAsSeen() -> Signal<Never, NoError> {
            return _internal_markChatListFeaturedFiltersAsSeen(postbox: self.account.postbox)
        }

        public func updateChatListFeaturedFilters() -> Signal<Never, NoError> {
            return _internal_updateChatListFeaturedFilters(postbox: self.account.postbox, network: self.account.network)
        }

        public func unmarkChatListFeaturedFiltersAsSeen() -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction in
                _internal_unmarkChatListFeaturedFiltersAsSeen(transaction: transaction)
            }
            |> ignoreValues
        }

        public func checkPeerChatServiceActions(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_checkPeerChatServiceActions(postbox: self.account.postbox, peerId: peerId)
        }

        public func createPeerExportedInvitation(peerId: PeerId, title: String?, expireDate: Int32?, usageLimit: Int32?, requestNeeded: Bool?) -> Signal<ExportedInvitation?, CreatePeerExportedInvitationError> {
            return _internal_createPeerExportedInvitation(account: self.account, peerId: peerId, title: title, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded)
        }

        public func editPeerExportedInvitation(peerId: PeerId, link: String, title: String?, expireDate: Int32?, usageLimit: Int32?, requestNeeded: Bool?) -> Signal<ExportedInvitation?, EditPeerExportedInvitationError> {
            return _internal_editPeerExportedInvitation(account: self.account, peerId: peerId, link: link, title: title, expireDate: expireDate, usageLimit: usageLimit, requestNeeded: requestNeeded)
        }

        public func revokePeerExportedInvitation(peerId: PeerId, link: String) -> Signal<RevokeExportedInvitationResult?, RevokePeerExportedInvitationError> {
            return _internal_revokePeerExportedInvitation(account: self.account, peerId: peerId, link: link)
        }

        public func deletePeerExportedInvitation(peerId: PeerId, link: String) -> Signal<Never, DeletePeerExportedInvitationError> {
            return _internal_deletePeerExportedInvitation(account: self.account, peerId: peerId, link: link)
        }

        public func deleteAllRevokedPeerExportedInvitations(peerId: PeerId, adminId: PeerId) -> Signal<Never, NoError> {
            return _internal_deleteAllRevokedPeerExportedInvitations(account: self.account, peerId: peerId, adminId: adminId)
        }

        public func peerExportedInvitationsCreators(peerId: PeerId) -> Signal<[ExportedInvitationCreator], NoError> {
            return _internal_peerExportedInvitationsCreators(account: self.account, peerId: peerId)
        }
        public func direct_peerExportedInvitations(peerId: PeerId, revoked: Bool, adminId: PeerId? = nil, offsetLink: ExportedInvitation? = nil) -> Signal<ExportedInvitations?, NoError> {
            return _internal_peerExportedInvitations(account: self.account, peerId: peerId, revoked: revoked, adminId: adminId, offsetLink: offsetLink)
        }

        public func peerExportedInvitations(peerId: PeerId, adminId: PeerId?, revoked: Bool, forceUpdate: Bool) -> PeerExportedInvitationsContext {
            return PeerExportedInvitationsContext(account: self.account, peerId: peerId, adminId: adminId, revoked: revoked, forceUpdate: forceUpdate)
        }
        
        public func revokePersistentPeerExportedInvitation(peerId: PeerId) -> Signal<ExportedInvitation?, NoError> {
            return _internal_revokePersistentPeerExportedInvitation(account: self.account, peerId: peerId)
        }

        public func peerInvitationImporters(peerId: PeerId, subject: PeerInvitationImportersContext.Subject) -> PeerInvitationImportersContext {
            return PeerInvitationImportersContext(account: self.account, peerId: peerId, subject: subject)
        }

        public func notificationExceptionsList() -> Signal<NotificationExceptionsList, NoError> {
            return combineLatest(
                _internal_notificationExceptionsList(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, isStories: false),
                _internal_notificationExceptionsList(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, isStories: true)
            )
            |> map { lhs, rhs in
                return NotificationExceptionsList(
                    peers: lhs.peers.merging(rhs.peers, uniquingKeysWith: { a, _ in a }),
                    settings: lhs.settings.merging(rhs.settings, uniquingKeysWith: { a, _ in a })
                )
            }
        }

        public func fetchAndUpdateCachedPeerData(peerId: PeerId) -> Signal<Bool, NoError> {
            return _internal_fetchAndUpdateCachedPeerData(accountPeerId: self.account.peerId, peerId: peerId, network: self.account.network, postbox: self.account.postbox)
        }

        public func toggleItemPinned(location: TogglePeerChatPinnedLocation, itemId: PinnedItemId) -> Signal<TogglePeerChatPinnedResult, NoError> {
            return _internal_toggleItemPinned(postbox: self.account.postbox, accountPeerId: self.account.peerId, location: location, itemId: itemId)
        }

        public func getPinnedItemIds(location: TogglePeerChatPinnedLocation) -> Signal<[PinnedItemId], NoError> {
            return self.account.postbox.transaction { transaction -> [PinnedItemId] in
                return _internal_getPinnedItemIds(transaction: transaction, location: location)
            }
        }

        public func reorderPinnedItemIds(location: TogglePeerChatPinnedLocation, itemIds: [PinnedItemId]) -> Signal<Bool, NoError> {
            return self.account.postbox.transaction { transaction -> Bool in
                return _internal_reorderPinnedItemIds(transaction: transaction, location: location, itemIds: itemIds)
            }
        }

        public func joinChatInteractively(with hash: String) -> Signal <EnginePeer?, JoinLinkError> {
            let account = self.account
            return _internal_joinChatInteractively(with: hash, account: self.account)
            |> mapToSignal { id -> Signal <EnginePeer?, JoinLinkError> in
                guard let id = id else {
                    return .single(nil)
                }
                return account.postbox.transaction { transaction -> EnginePeer? in
                    return transaction.getPeer(id).flatMap(EnginePeer.init)
                }
                |> castError(JoinLinkError.self)
            }
        }

        public func joinLinkInformation(_ hash: String) -> Signal<ExternalJoiningChatState, JoinLinkInfoError> {
            return _internal_joinLinkInformation(hash, account: self.account)
        }

        public func updatePeerTitle(peerId: PeerId, title: String) -> Signal<Void, UpdatePeerTitleError> {
            return _internal_updatePeerTitle(account: self.account, peerId: peerId, title: title)
        }

        public func updatePeerDescription(peerId: PeerId, description: String?) -> Signal<Void, UpdatePeerDescriptionError> {
            return _internal_updatePeerDescription(account: self.account, peerId: peerId, description: description)
        }
        
        public func updateBotName(peerId: PeerId, name: String) -> Signal<Void, UpdateBotInfoError> {
            return _internal_updateBotName(account: self.account, peerId: peerId, name: name)
        }
        
        public func updateBotAbout(peerId: PeerId, about: String) -> Signal<Void, UpdateBotInfoError> {
            return _internal_updateBotAbout(account: self.account, peerId: peerId, about: about)
        }
        
        public func updatePeerNameColorAndEmoji(peerId: EnginePeer.Id, nameColor: PeerNameColor, backgroundEmojiId: Int64?) -> Signal<Void, UpdatePeerNameColorAndEmojiError> {
            return _internal_updatePeerNameColorAndEmoji(account: self.account, peerId: peerId, nameColor: nameColor, backgroundEmojiId: backgroundEmojiId)
        }
        
        public func getChatListPeers(filterPredicate: ChatListFilterPredicate) -> Signal<[EnginePeer], NoError> {
            return self.account.postbox.transaction { transaction -> [EnginePeer] in
                return transaction.getChatListPeers(groupId: .root, filterPredicate: filterPredicate, additionalFilter: nil).map(EnginePeer.init)
            }
        }

        public func getNextUnreadChannel(peerId: PeerId, chatListFilterId: Int32?, getFilterPredicate: @escaping (ChatListFilterData) -> ChatListFilterPredicate) -> Signal<(peer: EnginePeer, unreadCount: Int, location: NextUnreadChannelLocation)?, NoError> {
            let startTime = CFAbsoluteTimeGetCurrent()
            return self.account.postbox.transaction { transaction -> (peer: EnginePeer, unreadCount: Int, location: NextUnreadChannelLocation)? in
                func getForFilter(predicate: ChatListFilterPredicate?, isArchived: Bool) -> (peer: EnginePeer, unreadCount: Int)? {
                    let additionalFilter: (Peer) -> Bool = { peer in
                        if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                            return true
                        } else {
                            return false
                        }
                    }
                    
                    var peerIds: [PeerId] = []
                    if predicate != nil {
                        peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: .root, filterPredicate: predicate, additionalFilter: additionalFilter, stopOnFirstMatch: true))
                        peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: Namespaces.PeerGroup.archive, filterPredicate: predicate, additionalFilter: additionalFilter, stopOnFirstMatch: true))
                    } else {
                        if isArchived {
                            peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: Namespaces.PeerGroup.archive, filterPredicate: nil, additionalFilter: additionalFilter, stopOnFirstMatch: true))
                        } else {
                            peerIds.append(contentsOf: transaction.getUnreadChatListPeerIds(groupId: .root, filterPredicate: nil, additionalFilter: additionalFilter, stopOnFirstMatch: true))
                        }
                    }

                    var results: [(EnginePeer, PeerGroupId, ChatListIndex)] = []

                    for listId in peerIds {
                        guard let peer = transaction.getPeer(listId) else {
                            continue
                        }
                        guard let channel = peer as? TelegramChannel, case .broadcast = channel.info else {
                            continue
                        }
                        if channel.id == peerId {
                            continue
                        }
                        guard let readState = transaction.getCombinedPeerReadState(channel.id), readState.count != 0 else {
                            continue
                        }
                        guard let (groupId, index) = transaction.getPeerChatListIndex(channel.id) else {
                            continue
                        }

                        results.append((EnginePeer(channel), groupId, index))
                    }

                    results.sort(by: { $0.2 > $1.2 })

                    if let peer = results.first?.0 {
                        let unreadCount: Int32 = transaction.getCombinedPeerReadState(peer.id)?.count ?? 0
                        return (peer: peer, unreadCount: Int(unreadCount))
                    } else {
                        return nil
                    }
                }

                let peerGroupId: PeerGroupId
                if let peerGroupIdValue = transaction.getPeerChatListIndex(peerId)?.0 {
                    peerGroupId = peerGroupIdValue
                } else {
                    peerGroupId = .root
                }

                if let filterId = chatListFilterId {
                    let filters = _internal_currentChatListFilters(transaction: transaction)
                    guard let index = filters.firstIndex(where: { $0.id == filterId }) else {
                        return nil
                    }
                    var sortedFilters: [ChatListFilter] = []
                    sortedFilters.append(contentsOf: filters[index...])
                    sortedFilters.append(contentsOf: filters[0 ..< index])
                    for i in 0 ..< sortedFilters.count {
                        if case let .filter(id, title, _, data) = sortedFilters[i] {
                            if let value = getForFilter(predicate: getFilterPredicate(data), isArchived: false) {
                                return (peer: value.peer, unreadCount: value.unreadCount, location: i == 0 ? .same : .folder(id: id, title: title))
                            }
                        }
                    }
                    return nil
                } else {
                    let folderOrder: [(PeerGroupId, NextUnreadChannelLocation)]
                    if peerGroupId == .root {
                        folderOrder = [
                            (.root, .same),
                            (Namespaces.PeerGroup.archive, .archived),
                        ]
                    } else {
                        folderOrder = [
                            (Namespaces.PeerGroup.archive, .same),
                            (.root, .unarchived),
                        ]
                    }

                    for (groupId, location) in folderOrder {
                        if let value = getForFilter(predicate: nil, isArchived: groupId != .root) {
                            return (peer: value.peer, unreadCount: value.unreadCount, location: location)
                        }
                    }
                    return nil
                }
            }
            |> beforeNext { _ in
                let delayTime = CFAbsoluteTimeGetCurrent() - startTime
                if delayTime > 0.3 {
                    //Logger.shared.log("getNextUnreadChannel", "took \(delayTime) s")
                }
            }
        }

        public func getOpaqueChatInterfaceState(peerId: PeerId, threadId: Int64?) -> Signal<OpaqueChatInterfaceState?, NoError> {
            return self.account.postbox.transaction { transaction -> OpaqueChatInterfaceState? in
                let storedState: StoredPeerChatInterfaceState?
                if let threadId = threadId {
                    storedState = transaction.getPeerChatThreadInterfaceState(peerId, threadId: threadId)
                } else {
                    storedState = transaction.getPeerChatInterfaceState(peerId)
                }

                guard let state = storedState, let data = state.data else {
                    return nil
                }
                guard let internalState = try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data) else {
                    return nil
                }
                return OpaqueChatInterfaceState(
                    opaqueData: internalState.opaqueData,
                    historyScrollMessageIndex: internalState.historyScrollMessageIndex,
                    synchronizeableInputState: internalState.synchronizeableInputState
                )
            }
        }

        public func setOpaqueChatInterfaceState(peerId: PeerId, threadId: Int64?, state: OpaqueChatInterfaceState) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                guard let data = try? AdaptedPostboxEncoder().encode(InternalChatInterfaceState(
                    synchronizeableInputState: state.synchronizeableInputState,
                    historyScrollMessageIndex: state.historyScrollMessageIndex,
                    opaqueData: state.opaqueData
                )) else {
                    return
                }

                #if DEBUG
                let _ = try! AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data)
                #endif

                let storedState = StoredPeerChatInterfaceState(
                    overrideChatTimestamp: state.synchronizeableInputState?.timestamp,
                    historyScrollMessageIndex: state.historyScrollMessageIndex,
                    associatedMessageIds: (state.synchronizeableInputState?.replySubject?.messageId).flatMap({ [$0] }) ?? [],
                    data: data
                )

                if let threadId = threadId {
                    var currentInputState: SynchronizeableChatInputState?
                    if let peerChatInterfaceState = transaction.getPeerChatThreadInterfaceState(peerId, threadId: threadId), let data = peerChatInterfaceState.data {
                        currentInputState = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))?.synchronizeableInputState
                    }
                    let updatedInputState = state.synchronizeableInputState

                    if currentInputState != updatedInputState {
                        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
                            addSynchronizeChatInputStateOperation(transaction: transaction, peerId: peerId, threadId: threadId)
                        }
                    }
                    transaction.setPeerChatThreadInterfaceState(peerId, threadId: threadId, state: storedState)
                } else {
                    var currentInputState: SynchronizeableChatInputState?
                    if let peerChatInterfaceState = transaction.getPeerChatInterfaceState(peerId), let data = peerChatInterfaceState.data {
                        currentInputState = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))?.synchronizeableInputState
                    }
                    let updatedInputState = state.synchronizeableInputState

                    if currentInputState != updatedInputState {
                        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
                            addSynchronizeChatInputStateOperation(transaction: transaction, peerId: peerId, threadId: nil)
                        }
                    }
                    transaction.setPeerChatInterfaceState(
                        peerId,
                        state: storedState
                    )
                }
            }
            |> ignoreValues
        }
        
        public func sendAsAvailablePeers(peerId: PeerId) -> Signal<[SendAsPeer], NoError> {
            return _internal_cachedPeerSendAsAvailablePeers(account: self.account, peerId: peerId)
        }
        
        public func updatePeerSendAsPeer(peerId: PeerId, sendAs: PeerId) -> Signal<Never, UpdatePeerSendAsPeerError> {
            return _internal_updatePeerSendAsPeer(account: self.account, peerId: peerId, sendAs: sendAs)
        }
        
        public func updatePeerAllowedReactions(peerId: PeerId, allowedReactions: PeerAllowedReactions) -> Signal<Never, UpdatePeerAllowedReactionsError> {
            return _internal_updatePeerAllowedReactions(account: account, peerId: peerId, allowedReactions: allowedReactions)
        }
        
        public func notificationSoundList() -> Signal<NotificationSoundList?, NoError> {
            let key = PostboxViewKey.cachedItem(_internal_cachedNotificationSoundListCacheKey())
            return self.account.postbox.combinedView(keys: [key])
            |> map { views -> NotificationSoundList? in
                guard let view = views.views[key] as? CachedItemView else {
                    return nil
                }
                return view.value?.get(NotificationSoundList.self)
            }
        }
        
        public func saveNotificationSound(file: FileMediaReference) -> Signal<Never, UploadNotificationSoundError> {
            return _internal_saveNotificationSound(account: self.account, file: file)
        }
        public func removeNotificationSound(file: FileMediaReference) -> Signal<Never, UploadNotificationSoundError> {
            return _internal_saveNotificationSound(account: self.account, file: file, unsave: true)
        }
        
        public func uploadNotificationSound(title: String, data: Data) -> Signal<NotificationSoundList.NotificationSound, UploadNotificationSoundError> {
            return _internal_uploadNotificationSound(account: self.account, title: title, data: data)
        }
        
        public func deleteNotificationSound(fileId: Int64) -> Signal<Never, DeleteNotificationSoundError> {
            return _internal_deleteNotificationSound(account: self.account, fileId: fileId)
        }
        
        public func ensurePeerIsLocallyAvailable(peer: EnginePeer) -> Signal<EnginePeer, NoError> {
            return _internal_storedMessageFromSearchPeer(postbox: self.account.postbox, peer: peer._asPeer())
            |> map { result -> EnginePeer in
                return EnginePeer(result)
            }
        }
        
        public func ensurePeersAreLocallyAvailable(peers: [EnginePeer]) -> Signal<Never, NoError> {
            return _internal_storedMessageFromSearchPeers(account: self.account, peers: peers.map { $0._asPeer() })
        }
        
        public func mostRecentSecretChat(id: EnginePeer.Id) -> Signal<EnginePeer.Id?, NoError> {
            return self.account.postbox.transaction { transaction -> EnginePeer.Id? in
                let filteredPeerIds = Array(transaction.getAssociatedPeerIds(id)).filter { $0.namespace == Namespaces.Peer.SecretChat }
                var activeIndices: [ChatListIndex] = []
                for associatedId in filteredPeerIds {
                    if let state = (transaction.getPeer(associatedId) as? TelegramSecretChat)?.embeddedState {
                        switch state {
                        case .active, .handshake:
                            if let (_, index) = transaction.getPeerChatListIndex(associatedId) {
                                activeIndices.append(index)
                            }
                        default:
                            break
                        }
                    }
                }
                activeIndices.sort()
                if let index = activeIndices.last {
                    return index.messageIndex.id.peerId
                } else {
                    return nil
                }
            }
        }
        
        public func updatePeersGroupIdInteractively(peerIds: [EnginePeer.Id], groupId: EngineChatList.Group) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_updatePeerGroupIdInteractively(transaction: transaction, peerId: peerId, groupId: groupId._asGroup())
                }
            }
            |> ignoreValues
        }
        
        public func resetAllPeerNotificationSettings() -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                transaction.resetAllPeerNotificationSettings(TelegramPeerNotificationSettings.defaultSettings)
            }
            |> ignoreValues
        }
        
        public func setChannelForumMode(id: EnginePeer.Id, isForum: Bool) -> Signal<Never, NoError> {
            return _internal_setChannelForumMode(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, peerId: id, isForum: isForum)
        }
        
        public func createForumChannelTopic(id: EnginePeer.Id, title: String, iconColor: Int32, iconFileId: Int64?) -> Signal<Int64, CreateForumChannelTopicError> {
            return _internal_createForumChannelTopic(account: self.account, peerId: id, title: title, iconColor: iconColor, iconFileId: iconFileId)
        }
        
        public func fetchForumChannelTopic(id: EnginePeer.Id, threadId: Int64) -> Signal<FetchForumChannelTopicResult, NoError> {
            return _internal_fetchForumChannelTopic(account: self.account, peerId: id, threadId: threadId)
        }
        
        public func editForumChannelTopic(id: EnginePeer.Id, threadId: Int64, title: String, iconFileId: Int64?) -> Signal<Never, EditForumChannelTopicError> {
            return _internal_editForumChannelTopic(account: self.account, peerId: id, threadId: threadId, title: title, iconFileId: iconFileId)
        }
        
        public func setForumChannelTopicClosed(id: EnginePeer.Id, threadId: Int64, isClosed: Bool) -> Signal<Never, EditForumChannelTopicError> {
            return _internal_setForumChannelTopicClosed(account: self.account, id: id, threadId: threadId, isClosed: isClosed)
        }
        
        public func setForumChannelTopicHidden(id: EnginePeer.Id, threadId: Int64, isHidden: Bool) -> Signal<Never, EditForumChannelTopicError> {
            return _internal_setForumChannelTopicHidden(account: self.account, id: id, threadId: threadId, isHidden: isHidden)
        }
        
        public func removeForumChannelThread(id: EnginePeer.Id, threadId: Int64) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                cloudChatAddClearHistoryOperation(transaction: transaction, peerId: id, threadId: threadId, explicitTopMessageId: nil, minTimestamp: nil, maxTimestamp: nil, type: CloudChatClearHistoryType(.forEveryone))
                
                transaction.setMessageHistoryThreadInfo(peerId: id, threadId: threadId, info: nil)
                
                _internal_clearHistory(transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: id, threadId: threadId, namespaces: .not(Namespaces.Message.allScheduled))
            }
            |> ignoreValues
        }
        
        public func removeForumChannelThreads(id: EnginePeer.Id, threadIds: [Int64]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for threadId in threadIds {
                    cloudChatAddClearHistoryOperation(transaction: transaction, peerId: id, threadId: threadId, explicitTopMessageId: nil, minTimestamp: nil, maxTimestamp: nil, type: CloudChatClearHistoryType(.forEveryone))
                    
                    transaction.setMessageHistoryThreadInfo(peerId: id, threadId: threadId, info: nil)
                    
                    _internal_clearHistory(transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: id, threadId: threadId, namespaces: .not(Namespaces.Message.allScheduled))
                }
            }
            |> ignoreValues
        }
        
        public func toggleForumChannelTopicPinned(id: EnginePeer.Id, threadId: Int64) -> Signal<Never, SetForumChannelTopicPinnedError> {
            return self.account.postbox.transaction { transaction -> ([Int64], Int) in
                var limit = 5
                let appConfiguration: AppConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
                if let data = appConfiguration.data, let value = data["topics_pinned_limit"] as? Double {
                    limit = Int(value)
                }
                
                return (transaction.getPeerPinnedThreads(peerId: id), limit)
            }
            |> castError(SetForumChannelTopicPinnedError.self)
            |> mapToSignal { threadIds, limit -> Signal<Never, SetForumChannelTopicPinnedError> in
                var threadIds = threadIds
                if threadIds.contains(threadId) {
                    threadIds.removeAll(where: { $0 == threadId })
                } else {
                    if threadIds.count + 1 > limit {
                        return .fail(.limitReached(limit))
                    }
                    threadIds.insert(threadId, at: 0)
                }
                
                return _internal_setForumChannelPinnedTopics(account: self.account, id: id, threadIds: threadIds)
            }
        }
        
        public func getForumChannelPinnedTopics(id: EnginePeer.Id) -> Signal<[Int64], NoError> {
            return self.account.postbox.transaction { transcation -> [Int64] in
                return transcation.getPeerPinnedThreads(peerId: id)
            }
        }
        
        public func setForumChannelPinnedTopics(id: EnginePeer.Id, threadIds: [Int64]) -> Signal<Never, SetForumChannelTopicPinnedError> {
            return _internal_setForumChannelPinnedTopics(account: self.account, id: id, threadIds: threadIds)
        }
        
        public func forumChannelTopicNotificationExceptions(id: EnginePeer.Id) -> Signal<[EngineMessageHistoryThread.NotificationException], NoError> {
            return _internal_forumChannelTopicNotificationExceptions(account: self.account, id: id)
        }
        
        public func importContactToken(token: String) -> Signal<EnginePeer?, NoError> {
            return _internal_importContactToken(account: self.account, token: token)
        }
        
        public func exportContactToken() -> Signal<ExportedContactToken?, NoError> {
            return _internal_exportContactToken(account: self.account)
        }
        
        public func updateChannelMembersHidden(peerId: EnginePeer.Id, value: Bool) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Api.InputChannel? in
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                    if let current = current as? CachedChannelData {
                        return current.withUpdatedMembersHidden(.known(PeerMembersHidden(value: value)))
                    } else {
                        return current
                    }
                })
                
                return transaction.getPeer(peerId).flatMap(apiInputChannel)
            }
            |> mapToSignal { inputChannel -> Signal<Never, NoError> in
                guard let inputChannel = inputChannel else {
                    return .complete()
                }
                
                return self.account.network.request(Api.functions.channels.toggleParticipantsHidden(channel: inputChannel, enabled: value ? .boolTrue : .boolFalse))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                    return .single(nil)
                }
                |> beforeNext { updates in
                    if let updates = updates {
                        self.account.stateManager.addUpdates(updates)
                    }
                }
                |> ignoreValues
            }
        }
        
        public func exportChatFolder(filterId: Int32, title: String, peerIds: [PeerId]) -> Signal<ExportedChatFolderLink, ExportChatFolderError> {
            return _internal_exportChatFolder(account: self.account, filterId: filterId, title: title, peerIds: peerIds)
        }
        
        public func getExportedChatFolderLinks(id: Int32) -> Signal<[ExportedChatFolderLink]?, NoError> {
            return _internal_getExportedChatFolderLinks(account: self.account, id: id)
        }
        
        public func editChatFolderLink(filterId: Int32, link: ExportedChatFolderLink, title: String?, peerIds: [EnginePeer.Id]?, revoke: Bool) -> Signal<ExportedChatFolderLink, EditChatFolderLinkError> {
            return _internal_editChatFolderLink(account: self.account, filterId: filterId, link: link, title: title, peerIds: peerIds, revoke: revoke)
        }
        
        public func deleteChatFolderLink(filterId: Int32, link: ExportedChatFolderLink) -> Signal<Never, RevokeChatFolderLinkError> {
            return _internal_deleteChatFolderLink(account: self.account, filterId: filterId, link: link)
        }
        
        public func checkChatFolderLink(slug: String) -> Signal<ChatFolderLinkContents, CheckChatFolderLinkError> {
            return _internal_checkChatFolderLink(account: self.account, slug: slug)
        }
        
        public func joinChatFolderLink(slug: String, peerIds: [EnginePeer.Id]) -> Signal<JoinChatFolderResult, JoinChatFolderLinkError> {
            return _internal_joinChatFolderLink(account: self.account, slug: slug, peerIds: peerIds)
        }
        
        public func pollChatFolderUpdates(folderId: Int32) -> Signal<Never, NoError> {
            let signal = _internal_pollChatFolderUpdatesOnce(account: self.account, folderId: folderId)
            return (
                signal
                |> then(
                    Signal<Never, NoError>.complete()
                    |> delay(10.0, queue: .concurrentDefaultQueue())
                )
            )
            |> restart
        }
        
        public func subscribedChatFolderUpdates(folderId: Int32) -> Signal<ChatFolderUpdates?, NoError> {
            return _internal_subscribedChatFolderUpdates(account: self.account, folderId: folderId)
        }

        public func joinAvailableChatsInFolder(updates: ChatFolderUpdates, peerIds: [EnginePeer.Id]) -> Signal<Never, JoinChatFolderLinkError> {
            return _internal_joinAvailableChatsInFolder(account: self.account, updates: updates, peerIds: peerIds)
        }
        
        public func hideChatFolderUpdates(folderId: Int32) -> Signal<Never, NoError> {
            return _internal_hideChatFolderUpdates(account: self.account, folderId: folderId)
        }
        
        public func leaveChatFolder(folderId: Int32, removePeerIds: [EnginePeer.Id]) -> Signal<Never, NoError> {
            return _internal_leaveChatFolder(account: self.account, folderId: folderId, removePeerIds: removePeerIds)
        }
        
        public func requestLeaveChatFolderSuggestions(folderId: Int32) -> Signal<[EnginePeer.Id], NoError> {
            return _internal_requestLeaveChatFolderSuggestions(account: self.account, folderId: folderId)
        }
        
        public func keepPeerUpdated(id: EnginePeer.Id, forceUpdate: Bool) -> Signal<Never, NoError> {
            return self.account.viewTracker.peerView(id, updateData: forceUpdate)
            |> ignoreValues
        }
        
        public func tokenizeSearchString(string: String, transliteration: EngineStringIndexTokenTransliteration) -> [EngineDataBuffer] {
            return stringIndexTokens(string, transliteration: transliteration)
        }
        
        public func updatePeerStoriesHidden(id: PeerId, isHidden: Bool) {
            let _ = _internal_updatePeerStoriesHidden(account: self.account, id: id, isHidden: isHidden).start()
        }
        
        public func getChannelBoostStatus(peerId: EnginePeer.Id) -> Signal<ChannelBoostStatus?, NoError> {
            return _internal_getChannelBoostStatus(account: self.account, peerId: peerId)
        }
        
        public func getMyBoostStatus() -> Signal<MyBoostStatus?, NoError> {
            return _internal_getMyBoostStatus(account: self.account)
        }

        public func applyChannelBoost(peerId: EnginePeer.Id, slots: [Int32]) -> Signal<MyBoostStatus?, NoError> {
            return _internal_applyChannelBoost(account: self.account, peerId: peerId, slots: slots)
        }
    }
}

public func _internal_decodeStoredChatInterfaceState(state: StoredPeerChatInterfaceState) -> OpaqueChatInterfaceState? {
    guard let data = state.data else {
        return nil
    }
    guard let internalState = try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data) else {
        return nil
    }
    return OpaqueChatInterfaceState(
        opaqueData: internalState.opaqueData,
        historyScrollMessageIndex: internalState.historyScrollMessageIndex,
        synchronizeableInputState: internalState.synchronizeableInputState
    )
}
