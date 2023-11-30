import Foundation

public struct NotificationsPresentationData: Codable, Equatable {
    public var applicationLockedMessageString: String
    public var incomingCallString: String
    public let messagePhoto: String
    public let messageVideo: String
    public let messageSticker: String
    public let messageVideoMessage: String
    public let messageVoice: String
    public let messageAnimation: String
    public let messageFile: String
    
    public init(applicationLockedMessageString: String, incomingCallString: String, messagePhoto: String, messageVideo: String, messageSticker: String, messageVideoMessage: String, messageVoice: String, messageAnimation: String, messageFile: String) {
        self.applicationLockedMessageString = applicationLockedMessageString
        self.incomingCallString = incomingCallString
        self.messagePhoto = messagePhoto
        self.messageVideo = messageVideo
        self.messageSticker = messageSticker
        self.messageVideoMessage = messageVideoMessage
        self.messageVoice = messageVoice
        self.messageAnimation = messageAnimation
        self.messageFile = messageFile
    }
}

public func notificationsPresentationDataPath(rootPath: String) -> String {
    return rootPath + "/notificationsPresentationData.json"
}
