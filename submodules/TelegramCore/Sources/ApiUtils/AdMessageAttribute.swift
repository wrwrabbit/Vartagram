import Foundation
import Postbox

public final class AdMessageAttribute: MessageAttribute {
    public enum MessageType {
        case sponsored
        case recommended
    }
    
    public enum MessageTarget {
        case peer(id: EnginePeer.Id, message: EngineMessage.Id?, startParam: String?)
        case join(title: String, joinHash: String)
        case webPage(title: String, url: String)
        case botApp(peerId: EnginePeer.Id, app: BotApp, startParam: String?)
    }
    
    public let opaqueId: Data
    public let messageType: MessageType
    public let displayAvatar: Bool
    public let target: MessageTarget
    public let buttonText: String?
    public let sponsorInfo: String?
    public let additionalInfo: String?

    public init(opaqueId: Data, messageType: MessageType, displayAvatar: Bool, target: MessageTarget, buttonText: String?, sponsorInfo: String?, additionalInfo: String?) {
        self.opaqueId = opaqueId
        self.messageType = messageType
        self.displayAvatar = displayAvatar
        self.target = target
        self.buttonText = buttonText
        self.sponsorInfo = sponsorInfo
        self.additionalInfo = additionalInfo
    }

    public init(decoder: PostboxDecoder) {
        preconditionFailure()
    }

    public func encode(_ encoder: PostboxEncoder) {
        preconditionFailure()
    }
}
