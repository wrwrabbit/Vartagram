import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum StandaloneMedia {
    case image(Data)
    case file(data: Data, mimeType: String, attributes: [TelegramMediaFileAttribute])
}

private enum StandaloneMessageContent {
    case text(String)
    case media(Api.InputMedia, String)
}

private enum StandaloneSendMessageEvent {
    case result(StandaloneMessageContent)
    case progress(Float)
}

public enum StandaloneSendMessageError {
    case generic
}

public enum StandaloneSendMessageStatus {
    case progress(Float)
    case done
}

public struct StandaloneSendMessagesError {
    public var peerId: PeerId
    public var reason: PendingMessageFailureReason?
    
    init(
        peerId: PeerId,
        reason: PendingMessageFailureReason?
    ) {
        self.peerId = peerId
        self.reason = reason
    }
}

public struct StandaloneSendEnqueueMessage {
    public struct Text {
        public var string: String
        public var entities: [MessageTextEntity]
        
        public init(
            string: String,
            entities: [MessageTextEntity]
        ) {
            self.string = string
            self.entities = entities
        }
    }
    
    public struct Image {
        public var representation: TelegramMediaImageRepresentation
        
        public init(
            representation: TelegramMediaImageRepresentation
        ) {
            self.representation = representation
        }
    }
    
    public struct Forward {
        public var sourceId: MessageId
        public var threadId: Int64?
        
        public init(
            sourceId: MessageId,
            threadId: Int64?
        ) {
            self.sourceId = sourceId
            self.threadId = threadId
        }
    }
    
    public struct ForwardOptions {
        public var hideNames: Bool
        public var hideCaptions: Bool
        
        public init(
            hideNames: Bool,
            hideCaptions: Bool
        ) {
            self.hideNames = hideNames
            self.hideCaptions = hideCaptions
        }
    }
    
    public enum Content {
        case text(text: Text)
        case image(image: Image, text: Text)
        case map(map: TelegramMediaMap)
        case arbitraryMedia(media: AnyMediaReference, text: Text)
        case forward(forward: Forward)
    }
    
    public var content: Content
    public var replyToMessageId: MessageId?
    public var forwardOptions: ForwardOptions?
    public var isSilent: Bool = false
    public var groupingKey: Int64? = nil
    
    public init(
        content: Content,
        replyToMessageId: MessageId?
    ) {
        self.content = content
        self.replyToMessageId = replyToMessageId
    }
}

public func standaloneSendEnqueueMessages(
    accountPeerId: PeerId,
    postbox: Postbox,
    network: Network,
    stateManager: AccountStateManager,
    auxiliaryMethods: AccountAuxiliaryMethods,
    peerId: PeerId,
    threadId: Int64?,
    messages: [StandaloneSendEnqueueMessage]
) -> Signal<StandaloneSendMessageStatus, StandaloneSendMessagesError> {
    let signals: [Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>] = messages.map { message in
        var attributes: [MessageAttribute] = []
        var text: String = ""
        var media: [Media] = []
        
        switch message.content {
        case let .text(textValue):
            text = textValue.string
            if !textValue.entities.isEmpty {
                attributes.append(TextEntitiesMessageAttribute(entities: textValue.entities))
            }
        case let .image(image, textValue):
            media.append(TelegramMediaImage(
                imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: MediaId.Id.random(in: Int64.min ... Int64.max)),
                representations: [image.representation],
                immediateThumbnailData: nil,
                reference: nil,
                partialReference: nil,
                flags: []
            ))
            
            text = textValue.string
            if !textValue.entities.isEmpty {
                attributes.append(TextEntitiesMessageAttribute(entities: textValue.entities))
            }
        case let .map(mapValue):
            media.append(mapValue)
        case let .arbitraryMedia(mediaValue, textValue):
            media.append(mediaValue.media)
            
            text = textValue.string
            if !textValue.entities.isEmpty {
                attributes.append(TextEntitiesMessageAttribute(entities: textValue.entities))
            }
        case let .forward(forwardValue):
            attributes.append(ForwardSourceInfoAttribute(messageId: forwardValue.sourceId))
        }
        
        if let replyToMessageId = message.replyToMessageId {
            attributes.append(ReplyMessageAttribute(messageId: replyToMessageId, threadMessageId: nil))
        }
        if let forwardOptions = message.forwardOptions {
            attributes.append(ForwardOptionsMessageAttribute(hideNames: forwardOptions.hideNames, hideCaptions: forwardOptions.hideCaptions))
        }
        if message.isSilent {
            attributes.append(NotificationInfoMessageAttribute(flags: .muted))
        }
        
        let content = messageContentToUpload(accountPeerId: accountPeerId, network: network, postbox: postbox, auxiliaryMethods: auxiliaryMethods, transformOutgoingMessageMedia: { _, _, _, _ in
            return .single(nil)
        }, messageMediaPreuploadManager: MessageMediaPreuploadManager(), revalidationContext: MediaReferenceRevalidationContext(), forceReupload: false, isGrouped: false, passFetchProgress: true, forceNoBigParts: false, peerId: peerId, messageId: nil, attributes: attributes, text: text, media: media)
        let contentResult: Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>
        switch content {
        case let .signal(value, _):
            contentResult = value
        case let .immediate(value, _):
            contentResult = .single(value)
        }
        return contentResult
    }
    
    return combineLatest(signals)
    |> mapError { _ -> StandaloneSendMessagesError in
        return StandaloneSendMessagesError(peerId: peerId, reason: nil)
    }
    |> mapToSignal { contentResults -> Signal<StandaloneSendMessageStatus, StandaloneSendMessagesError> in
        var progressSum: Float = 0.0
        var allResults: [PendingMessageUploadedContentAndReuploadInfo] = []
        var allDone = true
        for status in contentResults {
            switch status {
            case let .progress(value):
                allDone = false
                progressSum += value
            case let .content(content):
                allResults.append(content)
            }
        }
        if allDone {
            var sendSignals: [Signal<Never, StandaloneSendMessagesError>] = []
            
            for content in allResults {
                var text: String = ""
                switch content.content {
                case let .text(textValue):
                    text = textValue
                case let .media(_, textValue):
                    text = textValue
                default:
                    break
                }
                
                sendSignals.append(sendUploadedMessageContent(
                    postbox: postbox,
                    network: network,
                    stateManager: stateManager,
                    accountPeerId: stateManager.accountPeerId,
                    peerId: peerId,
                    content: content,
                    text: text,
                    attributes: [],
                    threadId: threadId
                ))
            }
            
            return combineLatest(sendSignals)
            |> ignoreValues
            |> map { _ -> StandaloneSendMessageStatus in
            }
            |> then(.single(.done))
        } else {
            return .single(.progress(progressSum / max(1.0, Float(contentResults.count))))
        }
    }
}

private func sendUploadedMessageContent(postbox: Postbox, network: Network, stateManager: AccountStateManager, accountPeerId: PeerId, peerId: PeerId, content: PendingMessageUploadedContentAndReuploadInfo, text: String, attributes: [MessageAttribute], threadId: Int64?) -> Signal<Never, StandaloneSendMessagesError> {
    return postbox.transaction { transaction -> Signal<Never, StandaloneSendMessagesError> in
        if peerId.namespace == Namespaces.Peer.SecretChat {
            assertionFailure()
            //PendingMessageManager.sendSecretMessageContent(transaction: transaction, message: message, content: content)
            return .complete()
        } else if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var uniqueId: Int64 = 0
            var forwardSourceInfoAttribute: ForwardSourceInfoAttribute?
            var messageEntities: [Api.MessageEntity]?
            var replyMessageId: Int32? = threadId.flatMap { threadId in
                makeThreadIdMessageId(peerId: peerId, threadId: threadId).id
            }
            var replyToStoryId: StoryId?
            var scheduleTime: Int32?
            var sendAsPeerId: PeerId?
            var bubbleUpEmojiOrStickersets = false
            
            var flags: Int32 = 0

            for attribute in attributes {
                if let replyAttribute = attribute as? ReplyMessageAttribute {
                    replyMessageId = replyAttribute.messageId.id
                } else if let attribute = attribute as? ReplyStoryAttribute {
                    replyToStoryId = attribute.storyId
                } else if let outgoingInfo = attribute as? OutgoingMessageInfoAttribute {
                    uniqueId = outgoingInfo.uniqueId
                    bubbleUpEmojiOrStickersets = !outgoingInfo.bubbleUpEmojiOrStickersets.isEmpty
                } else if let attribute = attribute as? ForwardSourceInfoAttribute {
                    forwardSourceInfoAttribute = attribute
                } else if let attribute = attribute as? TextEntitiesMessageAttribute {
                    var associatedPeers = SimpleDictionary<PeerId, Peer>()
                    for attributePeerId in attribute.associatedPeerIds {
                        if let peer = transaction.getPeer(attributePeerId) {
                            associatedPeers[peer.id] = peer
                        }
                    }
                    messageEntities = apiTextAttributeEntities(attribute, associatedPeers: associatedPeers)
                } else if let attribute = attribute as? OutgoingContentInfoMessageAttribute {
                    if attribute.flags.contains(.disableLinkPreviews) {
                        flags |= Int32(1 << 1)
                    }
                } else if let attribute = attribute as? NotificationInfoMessageAttribute {
                    if attribute.flags.contains(.muted) {
                        flags |= Int32(1 << 5)
                    }
                } else if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                    flags |= Int32(1 << 10)
                    scheduleTime = attribute.scheduleTime
                } else if let attribute = attribute as? SendAsMessageAttribute {
                    sendAsPeerId = attribute.peerId
                }
            }
            
            if uniqueId == 0 {
                uniqueId = Int64.random(in: Int64.min ... Int64.max)
            }
            
            if case .forward = content.content {
            } else {
                flags |= (1 << 7)
                
                if let _ = replyMessageId {
                    flags |= Int32(1 << 0)
                }
                if let _ = messageEntities {
                    flags |= Int32(1 << 3)
                }
            }
            
            var sendAsInputPeer: Api.InputPeer?
            if let sendAsPeerId = sendAsPeerId, let sendAsPeer = transaction.getPeer(sendAsPeerId), let inputPeer = apiInputPeerOrSelf(sendAsPeer, accountPeerId: accountPeerId) {
                sendAsInputPeer = inputPeer
                flags |= (1 << 13)
            }
            
            let dependencyTag: PendingMessageRequestDependencyTag? = nil//(messageId: messageId)
            
            let sendMessageRequest: Signal<NetworkRequestResult<Api.Updates>, MTRpcError>
            switch content.content {
                case .text:
                    if bubbleUpEmojiOrStickersets {
                        flags |= Int32(1 << 15)
                    }
                
                    var replyTo: Api.InputReplyTo?
                    if let replyMessageId = replyMessageId {
                        flags |= 1 << 0
                        
                        var replyFlags: Int32 = 0
                        if threadId != nil {
                            replyFlags |= 1 << 0
                        }
                        replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyMessageId, topMsgId: threadId.flatMap(Int32.init(clamping:)))
                    } else if let replyToStoryId = replyToStoryId {
                        if let inputUser = transaction.getPeer(replyToStoryId.peerId).flatMap(apiInputUser) {
                            flags |= 1 << 0
                            replyTo = .inputReplyToStory(userId: inputUser, storyId: replyToStoryId.id)
                        }
                    }
                
                    sendMessageRequest = network.requestWithAdditionalInfo(Api.functions.messages.sendMessage(flags: flags, peer: inputPeer, replyTo: replyTo, message: text, randomId: uniqueId, replyMarkup: nil, entities: messageEntities, scheduleDate: scheduleTime, sendAs: sendAsInputPeer), info: .acknowledgement, tag: dependencyTag)
                case let .media(inputMedia, text):
                    if bubbleUpEmojiOrStickersets {
                        flags |= Int32(1 << 15)
                    }
                
                    var replyTo: Api.InputReplyTo?
                    if let replyMessageId = replyMessageId {
                        flags |= 1 << 0
                        
                        var replyFlags: Int32 = 0
                        if threadId != nil {
                            replyFlags |= 1 << 0
                        }
                        replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyMessageId, topMsgId: threadId.flatMap(Int32.init(clamping:)))
                    } else if let replyToStoryId = replyToStoryId {
                        if let inputUser = transaction.getPeer(replyToStoryId.peerId).flatMap(apiInputUser) {
                            flags |= 1 << 0
                            replyTo = .inputReplyToStory(userId: inputUser, storyId: replyToStoryId.id)
                        }
                    }
                    
                    sendMessageRequest = network.request(Api.functions.messages.sendMedia(flags: flags, peer: inputPeer, replyTo: replyTo, media: inputMedia, message: text, randomId: uniqueId, replyMarkup: nil, entities: messageEntities, scheduleDate: scheduleTime, sendAs: sendAsInputPeer), tag: dependencyTag)
                    |> map(NetworkRequestResult.result)
                case let .forward(sourceInfo):
                    var topMsgId: Int32?
                    if let threadId = threadId {
                        flags |= Int32(1 << 9)
                        topMsgId = Int32(clamping: threadId)
                    }
                
                    if let forwardSourceInfoAttribute = forwardSourceInfoAttribute, let sourcePeer = transaction.getPeer(forwardSourceInfoAttribute.messageId.peerId), let sourceInputPeer = apiInputPeer(sourcePeer) {
                        sendMessageRequest = network.request(Api.functions.messages.forwardMessages(flags: flags, fromPeer: sourceInputPeer, id: [sourceInfo.messageId.id], randomId: [uniqueId], toPeer: inputPeer, topMsgId: topMsgId, scheduleDate: scheduleTime, sendAs: sendAsInputPeer), tag: dependencyTag)
                        |> map(NetworkRequestResult.result)
                    } else {
                        sendMessageRequest = .fail(MTRpcError(errorCode: 400, errorDescription: "internal"))
                    }
                case let .chatContextResult(chatContextResult):
                    if chatContextResult.hideVia {
                        flags |= Int32(1 << 11)
                    }
                
                    var replyTo: Api.InputReplyTo?
                    if let replyMessageId = replyMessageId {
                        flags |= 1 << 0
                        
                        var replyFlags: Int32 = 0
                        if threadId != nil {
                            replyFlags |= 1 << 0
                        }
                        replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyMessageId, topMsgId: threadId.flatMap(Int32.init(clamping:)))
                    } else if let replyToStoryId = replyToStoryId {
                        if let inputUser = transaction.getPeer(replyToStoryId.peerId).flatMap(apiInputUser) {
                            flags |= 1 << 0
                            replyTo = .inputReplyToStory(userId: inputUser, storyId: replyToStoryId.id)
                        }
                    }
                
                    sendMessageRequest = network.request(Api.functions.messages.sendInlineBotResult(flags: flags, peer: inputPeer, replyTo: replyTo, randomId: uniqueId, queryId: chatContextResult.queryId, id: chatContextResult.id, scheduleDate: scheduleTime, sendAs: sendAsInputPeer))
                    |> map(NetworkRequestResult.result)
                case .messageScreenshot:
                    let replyTo: Api.InputReplyTo
                
                    if let replyMessageId = replyMessageId {
                        let replyFlags: Int32 = 0
                        replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyMessageId, topMsgId: nil)
                    } else if let replyToStoryId = replyToStoryId {
                        if let inputUser = transaction.getPeer(replyToStoryId.peerId).flatMap(apiInputUser) {
                            flags |= 1 << 0
                            replyTo = .inputReplyToStory(userId: inputUser, storyId: replyToStoryId.id)
                        } else {
                            let replyFlags: Int32 = 0
                            replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: 0, topMsgId: nil)
                        }
                    } else {
                        let replyFlags: Int32 = 0
                        replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: 0, topMsgId: nil)
                    }
                
                    sendMessageRequest = network.request(Api.functions.messages.sendScreenshotNotification(peer: inputPeer, replyTo: replyTo, randomId: uniqueId))
                    |> map(NetworkRequestResult.result)
                case .secretMedia:
                    assertionFailure()
                    sendMessageRequest = .fail(MTRpcError(errorCode: 400, errorDescription: "internal"))
            }
            
            return sendMessageRequest
            |> mapToSignal { result -> Signal<Never, MTRpcError> in
                switch result {
                case .progress:
                    return .complete()
                case .acknowledged:
                    return .complete()
                case let .result(result):
                    stateManager.addUpdates(result)
                    return .complete()
                }
            }
            |> mapError { error -> StandaloneSendMessagesError in
                if error.errorDescription.hasPrefix("FILEREF_INVALID") || error.errorDescription.hasPrefix("FILE_REFERENCE_") {
                    return StandaloneSendMessagesError(peerId: peerId, reason: nil)
                } else if let failureReason = sendMessageReasonForError(error.errorDescription) {
                    return StandaloneSendMessagesError(peerId: peerId, reason: failureReason)
                }
                return StandaloneSendMessagesError(peerId: peerId, reason: nil)
            }
        } else {
            return .complete()
        }
    }
    |> castError(StandaloneSendMessagesError.self)
    |> switchToLatest
}

public func standaloneSendMessage(account: Account, peerId: PeerId, text: String, attributes: [MessageAttribute], media: StandaloneMedia?, replyToMessageId: MessageId?) -> Signal<Float, StandaloneSendMessageError> {
    let content: Signal<StandaloneSendMessageEvent, StandaloneSendMessageError>
    if let media = media {
        switch media {
            case let .image(data):
                content = uploadedImage(account: account, data: data)
                    |> mapError { _ -> StandaloneSendMessageError in return .generic }
                    |> map { next -> StandaloneSendMessageEvent in
                        switch next {
                            case let .progress(progress):
                                return .progress(progress)
                            case let .result(media):
                                return .result(.media(media, text))
                        }
                    }
            case let .file(data, mimeType, attributes):
                content = uploadedFile(account: account, data: data, mimeType: mimeType, attributes: attributes)
                    |> mapError { _ -> StandaloneSendMessageError in return .generic }
                    |> map { next -> StandaloneSendMessageEvent in
                        switch next {
                            case let .progress(progress):
                                return .progress(progress)
                            case let .result(media):
                                return .result(.media(media, text))
                        }
                    }
        }
    } else {
        content = .single(.result(.text(text)))
    }
    
    return content
        |> mapToSignal { event -> Signal<Float, StandaloneSendMessageError> in
            switch event {
                case let .progress(progress):
                    return .single(progress)
                case let .result(result):
                    let sendContent = sendMessageContent(account: account, peerId: peerId, attributes: attributes, content: result) |> map({ _ -> Float in return 1.0 })
                    return .single(1.0) |> then(sendContent |> mapError { _ -> StandaloneSendMessageError in })
                
            }
        }
}

private func sendMessageContent(account: Account, peerId: PeerId, attributes: [MessageAttribute], content: StandaloneMessageContent) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if peerId.namespace == Namespaces.Peer.SecretChat {
            return .complete()
        } else if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var uniqueId: Int64 = Int64.random(in: Int64.min ... Int64.max)
            //var forwardSourceInfoAttribute: ForwardSourceInfoAttribute?
            var messageEntities: [Api.MessageEntity]?
            var replyMessageId: Int32?
            var replyToStoryId: StoryId?
            var scheduleTime: Int32?
            var sendAsPeerId: PeerId?
            
            var flags: Int32 = 0
            flags |= (1 << 7)
            
            for attribute in attributes {
                if let replyAttribute = attribute as? ReplyMessageAttribute {
                    replyMessageId = replyAttribute.messageId.id
                } else if let attribute = attribute as? ReplyStoryAttribute {
                    replyToStoryId = attribute.storyId
                } else if let outgoingInfo = attribute as? OutgoingMessageInfoAttribute {
                    uniqueId = outgoingInfo.uniqueId
                } else if let _ = attribute as? ForwardSourceInfoAttribute {
                    //forwardSourceInfoAttribute = attribute
                } else if let attribute = attribute as? TextEntitiesMessageAttribute {
                    messageEntities = apiTextAttributeEntities(attribute, associatedPeers: SimpleDictionary())
                } else if let attribute = attribute as? OutgoingContentInfoMessageAttribute {
                    if attribute.flags.contains(.disableLinkPreviews) {
                        flags |= Int32(1 << 1)
                    }
                } else if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                    flags |= Int32(1 << 10)
                    scheduleTime = attribute.scheduleTime
                } else if let attribute = attribute as? SendAsMessageAttribute {
                    sendAsPeerId = attribute.peerId
                }
            }
            
            if let _ = messageEntities {
                flags |= Int32(1 << 3)
            }
            
            var sendAsInputPeer: Api.InputPeer?
            if let sendAsPeerId = sendAsPeerId, let sendAsPeer = transaction.getPeer(sendAsPeerId), let inputPeer = apiInputPeerOrSelf(sendAsPeer, accountPeerId: account.peerId) {
                sendAsInputPeer = inputPeer
                flags |= (1 << 13)
            }
            
            let sendMessageRequest: Signal<Api.Updates, NoError>
            switch content {
                case let .text(text):
                    var replyTo: Api.InputReplyTo?
                    if let replyMessageId = replyMessageId {
                        flags |= 1 << 0
                        
                        let replyFlags: Int32 = 0
                        replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyMessageId, topMsgId: nil)
                    } else if let replyToStoryId = replyToStoryId {
                        if let inputUser = transaction.getPeer(replyToStoryId.peerId).flatMap(apiInputUser) {
                            flags |= 1 << 0
                            replyTo = .inputReplyToStory(userId: inputUser, storyId: replyToStoryId.id)
                        }
                    }
                
                    sendMessageRequest = account.network.request(Api.functions.messages.sendMessage(flags: flags, peer: inputPeer, replyTo: replyTo, message: text, randomId: uniqueId, replyMarkup: nil, entities: messageEntities, scheduleDate: scheduleTime, sendAs: sendAsInputPeer))
                    |> `catch` { _ -> Signal<Api.Updates, NoError> in
                        return .complete()
                    }
                case let .media(inputMedia, text):
                    var replyTo: Api.InputReplyTo?
                    if let replyMessageId = replyMessageId {
                        flags |= 1 << 0
                        
                        let replyFlags: Int32 = 0
                        replyTo = .inputReplyToMessage(flags: replyFlags, replyToMsgId: replyMessageId, topMsgId: nil)
                    } else if let replyToStoryId = replyToStoryId {
                        if let inputUser = transaction.getPeer(replyToStoryId.peerId).flatMap(apiInputUser) {
                            flags |= 1 << 0
                            replyTo = .inputReplyToStory(userId: inputUser, storyId: replyToStoryId.id)
                        }
                    }
                
                    sendMessageRequest = account.network.request(Api.functions.messages.sendMedia(flags: flags, peer: inputPeer, replyTo: replyTo, media: inputMedia, message: text, randomId: uniqueId, replyMarkup: nil, entities: messageEntities, scheduleDate: scheduleTime, sendAs: sendAsInputPeer))
                    |> `catch` { _ -> Signal<Api.Updates, NoError> in
                        return .complete()
                    }
            }
            
            return sendMessageRequest
            |> mapToSignal { result -> Signal<Void, NoError> in
                return .complete()
            }
            |> `catch` { _ -> Signal<Void, NoError> in
            }
        } else {
            return .complete()
        }
    }
    |> switchToLatest
}

private enum UploadMediaEvent {
    case progress(Float)
    case result(Api.InputMedia)
}

private func uploadedImage(account: Account, data: Data) -> Signal<UploadMediaEvent, StandaloneSendMessageError> {
    return multipartUpload(network: account.network, postbox: account.postbox, source: .data(data), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .image, userContentType: .image), hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false)
        |> mapError { _ -> StandaloneSendMessageError in return .generic }
        |> map { next -> UploadMediaEvent in
            switch next {
                case let .inputFile(inputFile):
                    return .result(Api.InputMedia.inputMediaUploadedPhoto(flags: 0, file: inputFile, stickers: nil, ttlSeconds: nil))
                case .inputSecretFile:
                        preconditionFailure()
                case let .progress(progress):
                    return .progress(progress)
            }
        }
}

private func uploadedFile(account: Account, data: Data, mimeType: String, attributes: [TelegramMediaFileAttribute]) -> Signal<UploadMediaEvent, PendingMessageUploadError> {
    return multipartUpload(network: account.network, postbox: account.postbox, source: .data(data), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: statsCategoryForFileWithAttributes(attributes), userContentType: nil), hintFileSize: Int64(data.count), hintFileIsLarge: false, forceNoBigParts: false)
        |> mapError { _ -> PendingMessageUploadError in return .generic }
        |> map { next -> UploadMediaEvent in
            switch next {
                case let .inputFile(inputFile):
                    return .result(Api.InputMedia.inputMediaUploadedDocument(flags: 0, file: inputFile, thumb: nil, mimeType: mimeType, attributes: inputDocumentAttributesFromFileAttributes(attributes), stickers: nil, ttlSeconds: nil))
                case .inputSecretFile:
                    preconditionFailure()
                case let .progress(progress):
                    return .progress(progress)
            }
        }
}
