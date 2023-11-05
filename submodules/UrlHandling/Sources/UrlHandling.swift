import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import MtProtoKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramNotices
import AccountContext

private let baseTelegramMePaths = ["telegram.me", "t.me", "telegram.dog"]
private let baseTelegraPhPaths = [
    "telegra.ph/",
    "te.legra.ph/",
    "graph.org/",
    "t.me/iv?",
    "telegram.org/blog/",
    "telegram.org/tour/"
]

extension ResolvedBotAdminRights {
    init?(_ string: String) {
        var rawValue: UInt32 = 0
        
        let components = string.lowercased().components(separatedBy: "+")
        if components.contains("change_info") {
            rawValue |= ResolvedBotAdminRights.changeInfo.rawValue
        }
        if components.contains("post_messages") {
            rawValue |= ResolvedBotAdminRights.postMessages.rawValue
        }
        if components.contains("delete_messages") {
            rawValue |= ResolvedBotAdminRights.deleteMessages.rawValue
        }
        if components.contains("restrict_members") {
            rawValue |= ResolvedBotAdminRights.restrictMembers.rawValue
        }
        if components.contains("invite_users") {
            rawValue |= ResolvedBotAdminRights.inviteUsers.rawValue
        }
        if components.contains("pin_messages") {
            rawValue |= ResolvedBotAdminRights.pinMessages.rawValue
        }
        if components.contains("promote_members") {
            rawValue |= ResolvedBotAdminRights.promoteMembers.rawValue
        }
        if components.contains("manage_video_chats") {
            rawValue |= ResolvedBotAdminRights.manageVideoChats.rawValue
        }
        if components.contains("manage_chat") {
            rawValue |= ResolvedBotAdminRights.manageChat.rawValue
        }
        if components.contains("anonymous") {
            rawValue |= ResolvedBotAdminRights.canBeAnonymous.rawValue
        }
                
        if rawValue != 0 {
            self.init(rawValue: rawValue)
        } else {
            return nil
        }
    }
}

public enum ParsedInternalPeerUrlParameter {
    case botStart(String)
    case groupBotStart(String, ResolvedBotAdminRights?)
    case attachBotStart(String, String?)
    case gameStart(String)
    case channelMessage(Int32, Double?)
    case replyThread(Int32, Int32)
    case voiceChat(String?)
    case appStart(String, String?)
    case story(Int32)
    case boost
}

public enum ParsedInternalUrl {
    public enum UrlPeerReference {
        case name(String)
        case id(PeerId)
    }
    
    case peer(UrlPeerReference, ParsedInternalPeerUrlParameter?)
    case peerId(PeerId)
    case privateMessage(messageId: MessageId, threadId: Int32?, timecode: Double?)
    case stickerPack(name: String, type: StickerPackUrlType)
    case invoice(String)
    case join(String)
    case localization(String)
    case proxy(host: String, port: Int32, username: String?, password: String?, secret: Data?)
    case internalInstantView(url: String)
    case confirmationCode(Int)
    case cancelAccountReset(phone: String, hash: String)
    case share(url: String?, text: String?, to: String?)
    case wallpaper(WallpaperUrlParameter)
    case theme(String)
    case phone(String, String?, String?)
    case startAttach(String, String?, String?)
    case contactToken(String)
    case chatFolder(slug: String)
    case premiumGiftCode(slug: String)
}

private enum ParsedUrl {
    case externalUrl(String)
    case internalUrl(ParsedInternalUrl)
}

public func parseInternalUrl(query: String) -> ParsedInternalUrl? {
    var query = query
    if query.hasPrefix("s/") {
        query = String(query[query.index(query.startIndex, offsetBy: 2)...])
    }
    if query.hasSuffix("/") {
        query.removeLast()
    }
    if let components = URLComponents(string: "/" + query) {
        var pathComponents = components.path.components(separatedBy: "/")
        if !pathComponents.isEmpty {
            pathComponents.removeFirst()
        }
        if let lastComponent = pathComponents.last, lastComponent.isEmpty {
            pathComponents.removeLast()
        }
        if !pathComponents.isEmpty && !pathComponents[0].isEmpty {
            let peerName: String = pathComponents[0]
            if pathComponents.count == 1 {
                if let queryItems = components.queryItems {
                    if peerName == "socks" || peerName == "proxy" {
                        var server: String?
                        var port: String?
                        var user: String?
                        var pass: String?
                        var secret: Data?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "server" || queryItem.name == "proxy" {
                                        server = value
                                    } else if queryItem.name == "port" {
                                        port = value
                                    } else if queryItem.name == "user" {
                                        user = value
                                    } else if queryItem.name == "pass" {
                                        pass = value
                                    } else if queryItem.name == "secret" {
                                        let parsedSecret = MTProxySecret.parse(value)
                                        if let parsedSecret = parsedSecret {
                                            secret = parsedSecret.serialize()
                                        }
                                    }
                                }
                            }
                        }
                        
                        if let server = server, !server.isEmpty, let port = port, let portValue = Int32(port) {
                            return .proxy(host: server, port: portValue, username: user, password: pass, secret: secret)
                        }
                    } else if peerName == "iv" {
                        var url: String?
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "url" {
                                    url = value
                                }
                            }
                        }
                        if let _ = url {
                            return .internalInstantView(url: "https://t.me/\(query)")
                        }
                    } else if peerName == "contact" {
                        var code: String?
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "code" {
                                    code = value
                                }
                            }
                        }
                        if let code = code, let codeValue = Int(code) {
                            return .confirmationCode(codeValue)
                        }
                    } else if peerName == "confirmphone" {
                        var phone: String?
                        var hash: String?
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "phone" {
                                    phone = value
                                } else if queryItem.name == "hash" {
                                    hash = value
                                }
                            }
                        }
                        if let phone = phone, let hash = hash {
                            return .cancelAccountReset(phone: phone, hash: hash)
                        }
                    } else if peerName == "msg" {
                        var url: String?
                        var text: String?
                        var to: String?
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "url" {
                                    url = value
                                } else if queryItem.name == "text" {
                                    text = value
                                } else if queryItem.name == "to" {
                                    to = value
                                }
                            }
                        }
                        return .share(url: url, text: text, to: to)
                    } else if peerName == "boost" {
                        for queryItem in queryItems {
                            if queryItem.name == "c", let value = queryItem.value, let channelId = Int64(value) {
                                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                                return .peer(.id(peerId), .boost)
                            }
                        }
                    } else {
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "attach" {
                                    var startAttach: String?
                                    for queryItem in queryItems {
                                        if queryItem.name == "startattach", let value = queryItem.value {
                                            startAttach = value
                                            break
                                        }
                                    }
                                    return .peer(.name(peerName), .attachBotStart(value, startAttach))
                                } else if queryItem.name == "start" {
                                    return .peer(.name(peerName), .botStart(value))
                                } else if queryItem.name == "startgroup" {
                                    var botAdminRights: ResolvedBotAdminRights?
                                    for queryItem in queryItems {
                                        if queryItem.name == "admin", let value = queryItem.value {
                                            botAdminRights = ResolvedBotAdminRights(value)
                                            break
                                        }
                                    }
                                    return .peer(.name(peerName), .groupBotStart(value, botAdminRights))
                                } else if queryItem.name == "game" {
                                    return .peer(.name(peerName), .gameStart(value))
                                } else if ["voicechat", "videochat", "livestream"].contains(queryItem.name) {
                                    return .peer(.name(peerName), .voiceChat(value))
                                } else if queryItem.name == "startattach" {
                                    var choose: String?
                                    for queryItem in queryItems {
                                        if queryItem.name == "choose", let value = queryItem.value {
                                            choose = value
                                            break
                                        }
                                    }
                                    return .startAttach(peerName, value, choose)
                                } else if queryItem.name == "story" {
                                    if let id = Int32(value) {
                                        return .peer(.name(peerName), .story(id))
                                    }
                                }
                            } else if ["voicechat", "videochat", "livestream"].contains(queryItem.name)  {
                                return .peer(.name(peerName), .voiceChat(nil))
                            } else if queryItem.name == "startattach" {
                                var choose: String?
                                for queryItem in queryItems {
                                    if queryItem.name == "choose", let value = queryItem.value {
                                        choose = value
                                        break
                                    }
                                }
                                return .startAttach(peerName, nil, choose)
                            } else if queryItem.name == "startgroup" || queryItem.name == "startchannel" {
                                var botAdminRights: ResolvedBotAdminRights?
                                for queryItem in queryItems {
                                    if queryItem.name == "admin", let value = queryItem.value {
                                        botAdminRights = ResolvedBotAdminRights(value)
                                        break
                                    }
                                }
                                return .peer(.name(peerName), .groupBotStart("", botAdminRights))
                            } else if queryItem.name == "boost" {
                                return .peer(.name(peerName), .boost)
                            }
                        }
                    }
                } else if pathComponents[0].hasPrefix(phonebookUsernamePathPrefix), let idValue = Int64(String(pathComponents[0][pathComponents[0].index(pathComponents[0].startIndex, offsetBy: phonebookUsernamePathPrefix.count)...])) {
                    return .peerId(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(idValue)))
                } else if pathComponents[0].hasPrefix("+") || pathComponents[0].hasPrefix("%20") {
                    let component = pathComponents[0].replacingOccurrences(of: "%20", with: "+")
                    if component.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789+").inverted) == nil {
                        var attach: String?
                        var startAttach: String?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "attach" {
                                        attach = value
                                    } else if queryItem.name == "startattach" {
                                        startAttach = value
                                    }
                                }
                            }
                        }
                        
                        return .phone(component.replacingOccurrences(of: "+", with: ""), attach, startAttach)
                    } else {
                        return .join(String(component.dropFirst()))
                    }
                } else if pathComponents[0].hasPrefix("$") || pathComponents[0].hasPrefix("%24") {
                    var component = pathComponents[0].replacingOccurrences(of: "%24", with: "$")
                    if component.hasPrefix("$") {
                        component = String(component[component.index(after: component.startIndex)...])
                    }
                    return .invoice(component)
                }
                return .peer(.name(peerName), nil)
            } else if pathComponents.count == 2 || pathComponents.count == 3 || pathComponents.count == 4 {
                if pathComponents[0] == "addstickers" {
                    return .stickerPack(name: pathComponents[1], type: .stickers)
                } else if pathComponents[0] == "addemoji" {
                    return .stickerPack(name: pathComponents[1], type: .emoji)
                } else if pathComponents[0] == "invoice" {
                    return .invoice(pathComponents[1])
                } else if pathComponents[0] == "joinchat" || pathComponents[0] == "joinchannel" {
                    return .join(pathComponents[1])
                } else if pathComponents[0] == "setlanguage" {
                    return .localization(pathComponents[1])
                } else if pathComponents[0] == "login" {
                    if let code = Int(pathComponents[1]) {
                        return .confirmationCode(code)
                    }
                } else if peerName == "contact" {
                    return .contactToken(pathComponents[1])
                } else if pathComponents[0] == "share" && pathComponents[1] == "url" {
                    if let queryItems = components.queryItems {
                        var url: String?
                        var text: String?
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "url" {
                                    url = value
                                } else if queryItem.name == "text" {
                                    text = value
                                }
                            }
                        }
                        
                        if let url = url {
                            return .share(url: url, text: text, to: nil)
                        }
                    }
                    return nil
                } else if pathComponents[0] == "bg" {
                    let component = pathComponents[1]
                    let parameter: WallpaperUrlParameter
                    if [6, 8].contains(component.count), component.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted) == nil, let color = UIColor(hexString: component) {
                        parameter = .color(color)
                    } else if [13, 15, 17].contains(component.count), component.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF-~").inverted) == nil {
                        var rotation: Int32?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "rotation" {
                                        rotation = Int32(value)
                                    }
                                }
                            }
                        }
                        if component.contains("~") {
                            let components = component.components(separatedBy: "~")

                            var colors: [UInt32] = []
                            if components.count >= 2 && components.count <= 4 {
                                colors = components.compactMap { component in
                                    return UIColor(hexString: component)?.rgb
                                }
                            }

                            if !colors.isEmpty {
                                parameter = .gradient(colors, rotation)
                            } else {
                                return nil
                            }
                        } else {
                            let components = component.components(separatedBy: "-")
                            if components.count == 2, let topColor = UIColor(hexString: components[0]), let bottomColor = UIColor(hexString: components[1])  {
                                parameter = .gradient([topColor.rgb, bottomColor.rgb], rotation)
                            } else {
                                return nil
                            }
                        }
                    } else if component.contains("~") {
                        let components = component.components(separatedBy: "~")
                        if components.count >= 1 && components.count <= 4 {
                            let colors = components.compactMap { component in
                                return UIColor(hexString: component)?.rgb
                            }
                            parameter = .gradient(colors, nil)
                        } else {
                            parameter = .color(UIColor(rgb: 0xffffff))
                        }
                    } else {
                        var options: WallpaperPresentationOptions = []
                        var intensity: Int32?
                        var colors: [UInt32] = []
                        var rotation: Int32?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "mode" {
                                        for option in value.components(separatedBy: "+") {
                                            switch option.lowercased() {
                                                case "motion":
                                                    options.insert(.motion)
                                                case "blur":
                                                    options.insert(.blur)
                                                default:
                                                    break
                                            }
                                        }
                                    } else if queryItem.name == "bg_color" {
                                        if [6, 8].contains(value.count), value.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted) == nil, let color = UIColor(hexString: value) {
                                            colors = [color.rgb]
                                        } else if [13, 15, 17].contains(value.count), value.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789abcdefABCDEF-").inverted) == nil {
                                            let components = value.components(separatedBy: "-")
                                            if components.count == 2, let topColorValue = UIColor(hexString: components[0]), let bottomColorValue = UIColor(hexString: components[1]) {
                                                colors = [topColorValue.rgb, bottomColorValue.rgb]
                                            }
                                        } else if value.contains("~") {
                                            let components = value.components(separatedBy: "~")
                                            if components.count >= 2 && components.count <= 4 {
                                                colors = components.compactMap { component in
                                                    return UIColor(hexString: component)?.rgb
                                                }
                                            }
                                        }
                                    } else if queryItem.name == "intensity" {
                                        intensity = Int32(value)
                                    } else if queryItem.name == "rotation" {
                                        rotation = Int32(value)
                                    }
                                }
                            }
                        }
                        parameter = .slug(component, options, colors, intensity, rotation)
                    }
                    return .wallpaper(parameter)
                } else if pathComponents[0] == "addtheme" {
                    return .theme(pathComponents[1])
                } else if pathComponents[0] == "addlist" || pathComponents[0] == "folder" || pathComponents[0] == "list" {
                    return .chatFolder(slug: pathComponents[1])
                } else if pathComponents[0] == "boost", pathComponents.count == 2 {
                    return .peer(.name(pathComponents[1]), .boost)
                } else if pathComponents[0] == "giftcode", pathComponents.count == 2 {
                    return .premiumGiftCode(slug: pathComponents[1])
                } else if pathComponents.count == 3 && pathComponents[0] == "c" {
                    if let channelId = Int64(pathComponents[1]), let messageId = Int32(pathComponents[2]) {
                        var threadId: Int32?
                        var timecode: Double?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "thread" || queryItem.name == "topic" {
                                        if let intValue = Int32(value) {
                                            threadId = intValue
                                        }
                                    } else if queryItem.name == "t" {
                                        if let doubleValue = Double(value) {
                                            timecode = doubleValue
                                        }
                                    }
                                }
                            }
                        }
                        return .privateMessage(messageId: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, id: messageId), threadId: threadId, timecode: timecode)
                    } else {
                        return nil
                    }
                } else if pathComponents.count >= 3 && pathComponents[1] == "s" {
                    if let storyId = Int32(pathComponents[2]) {
                        return .peer(.name(pathComponents[0]), .story(storyId))
                    } else {
                        return nil
                    }
                } else if pathComponents.count == 4 && pathComponents[0] == "c" {
                    if let channelId = Int64(pathComponents[1]), let threadId = Int32(pathComponents[2]), let messageId = Int32(pathComponents[3]) {
                        var timecode: Double?
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "t" {
                                        if let doubleValue = Double(value) {
                                            timecode = doubleValue
                                        }
                                    }
                                }
                            }
                        }
                        return .privateMessage(messageId: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, id: messageId), threadId: threadId, timecode: timecode)
                    } else {
                        return nil
                    }
                } else if pathComponents.count == 2 && pathComponents[0] == "c" {
                    if let channelId = Int64(pathComponents[1]) {
                        var threadId: Int32?
                        var boost: Bool = false
                        if let queryItems = components.queryItems {
                            for queryItem in queryItems {
                                if let value = queryItem.value {
                                    if queryItem.name == "thread" || queryItem.name == "topic" {
                                        if let intValue = Int32(value) {
                                            threadId = intValue
                                        }
                                    }
                                } else {
                                    if queryItem.name == "boost" {
                                        boost = true
                                    }
                                }
                            }
                        }
                        
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                        if boost {
                            return .peer(.id(peerId), .boost)
                        } else if let threadId = threadId {
                            return .peer(.id(peerId), .replyThread(threadId, threadId))
                        } else {
                            return nil
                        }
                    } else {
                        return nil
                    }
                } else if let value = Int32(pathComponents[1]) {
                    var threadId: Int32?
                    var commentId: Int32?
                    var timecode: Double?
                    if let queryItems = components.queryItems {
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "thread" || queryItem.name == "topic" {
                                    if let intValue = Int32(value) {
                                        threadId = intValue
                                    }
                                } else if queryItem.name == "comment" {
                                    if let intValue = Int32(value) {
                                        commentId = intValue
                                    }
                                } else if queryItem.name == "t" {
                                    if let doubleValue = Double(value) {
                                        timecode = doubleValue
                                    }
                                }
                            }
                        }
                    }
                    
                    if pathComponents.count >= 3, let subMessageId = Int32(pathComponents[2]) {
                        return .peer(.name(peerName), .replyThread(value, subMessageId))
                    } else if let threadId = threadId {
                        return .peer(.name(peerName), .replyThread(threadId, value))
                    } else if let commentId = commentId {
                        return .peer(.name(peerName), .replyThread(value, commentId))
                    } else {
                        return .peer(.name(peerName), .channelMessage(value, timecode))
                    }
                } else if pathComponents.count == 2 {
                    let appName = pathComponents[1]
                    var startApp: String?
                    if let queryItems = components.queryItems {
                        for queryItem in queryItems {
                            if let value = queryItem.value {
                                if queryItem.name == "startapp" {
                                    startApp = value
                                }
                            }
                        }
                    }
                    return .peer(.name(peerName), .appStart(appName, startApp))
                } else {
                    return nil
                }
            }
        } else {
            return nil
        }
    }
    return nil
}

private enum ResolveInternalUrlResult {
    case progress
    case result(ResolvedUrl?)
}

private func resolveInternalUrl(context: AccountContext, url: ParsedInternalUrl) -> Signal<ResolveInternalUrlResult, NoError> {
    switch url {
        case let .phone(phone, attach, startAttach):
            return context.engine.peers.resolvePeerByPhone(phone: phone)
            |> mapToSignal { peer -> Signal<ResolveInternalUrlResult, NoError> in
                if let peer = peer?._asPeer() {
                    if let attach = attach {
                        return context.engine.peers.resolvePeerByName(name: attach)
                        |> map { result -> ResolveInternalUrlResult in
                            switch result {
                            case .progress:
                                return .progress
                            case let .result(botPeer):
                                if let botPeer = botPeer?._asPeer() {
                                    return .result(.peer(peer, .withAttachBot(ChatControllerInitialAttachBotStart(botId: botPeer.id, payload: startAttach, justInstalled: false))))
                                } else {
                                    return .result(.peer(peer, .chat(textInputState: nil, subject: nil, peekData: nil)))
                                }
                            }
                        }
                    } else {
                        return .single(.result(.peer(peer, .chat(textInputState: nil, subject: nil, peekData: nil))))
                    }
                } else {
                    return .single(.result(.peer(nil, .info)))
                }
            }
        case let .peer(reference, parameter):
            let resolvedPeer: Signal<ResolvePeerResult, NoError>
            switch reference {
            case let .name(name):
                resolvedPeer = context.engine.peers.resolvePeerByName(name: name)
                |> mapToSignal { result -> Signal<ResolvePeerResult, NoError> in
                    switch result {
                    case .progress:
                        return .single(.progress)
                    case let .result(peer):
                        return .single(.result(peer))
                    }
                }
            case let .id(id):
                if id.namespace == Namespaces.Peer.CloudChannel {
                    resolvedPeer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: id))
                    |> mapToSignal { peer -> Signal<ResolvePeerResult, NoError> in
                        let foundPeer: Signal<ResolvePeerResult, NoError>
                        if let peer = peer {
                            foundPeer = .single(.result(peer))
                        } else {
                            foundPeer = .single(.progress) |> then(context.engine.peers.findChannelById(channelId: id.id._internalGetInt64Value())
                            |> map { peer -> ResolvePeerResult in
                                return .result(peer)
                            })
                        }
                        return foundPeer
                    }
                } else {
                    resolvedPeer = .single(.result(nil))
                }
            }
        
            return resolvedPeer
            |> mapToSignal { result -> Signal<ResolveInternalUrlResult, NoError> in
                guard case let .result(peer) = result else {
                    return .single(.progress)
                }
                
                if let peer = peer {
                    if let parameter = parameter {
                        switch parameter {
                            case let .botStart(payload):
                                return .single(.result(.botStart(peer: peer._asPeer(), payload: payload)))
                            case let .groupBotStart(payload, adminRights):
                                return .single(.result(.groupBotStart(peerId: peer.id, payload: payload, adminRights: adminRights)))
                            case let .gameStart(game):
                                return .single(.result(.gameStart(peerId: peer.id, game: game)))
                            case let .attachBotStart(name, payload):
                                return context.engine.peers.resolvePeerByName(name: name)
                                |> mapToSignal { botPeerResult -> Signal<ResolveInternalUrlResult, NoError> in
                                    switch botPeerResult {
                                    case .progress:
                                        return .single(.progress)
                                    case let .result(botPeer):
                                        if let botPeer = botPeer {
                                            return .single(.result(.peer(peer._asPeer(), .withAttachBot(ChatControllerInitialAttachBotStart(botId: botPeer.id, payload: payload, justInstalled: false)))))
                                        } else {
                                            return .single(.result(.peer(peer._asPeer(), .chat(textInputState: nil, subject: nil, peekData: nil))))
                                        }
                                    }
                                }
                            case let .appStart(name, payload):
                                return .single(.progress) |> then(context.engine.messages.getBotApp(botId: peer.id, shortName: name, cached: false)
                                |> map(Optional.init)
                                |> `catch` { _ -> Signal<BotApp?, NoError> in
                                    return .single(nil)
                                }
                                |> mapToSignal { botApp -> Signal<ResolveInternalUrlResult, NoError> in
                                    if let botApp {
                                        return .single(.result(.peer(peer._asPeer(), .withBotApp(ChatControllerInitialBotAppStart(botApp: botApp, payload: payload, justInstalled: false)))))
                                    } else {
                                        return .single(.result(.peer(peer._asPeer(), .chat(textInputState: nil, subject: nil, peekData: nil))))
                                    }
                                })
                            case let .channelMessage(id, timecode):
                                if case let .channel(channel) = peer, channel.flags.contains(.isForum) {
                                    let messageId = MessageId(peerId: channel.id, namespace: Namespaces.Message.Cloud, id: id)
                                    return context.engine.messages.getMessagesLoadIfNecessary([messageId], strategy: .cloud(skipLocal: false))
                                    |> take(1)
                                    |> mapToSignal { result -> Signal<ResolveInternalUrlResult, NoError> in
                                        switch result {
                                        case .progress:
                                            return .single(.progress)
                                        case let .result(messages):
                                            if let threadId = messages.first?.threadId {
                                                return context.engine.peers.fetchForumChannelTopic(id: channel.id, threadId: threadId)
                                                |> map { result -> ResolveInternalUrlResult in
                                                    switch result {
                                                    case .progress:
                                                        return .progress
                                                    case let .result(info):
                                                        if let _ = info {
                                                            return .result(.replyThreadMessage(replyThreadMessage: ChatReplyThreadMessage(messageId: MessageId(peerId: channel.id, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId)), channelMessageId: nil, isChannelPost: false, isForumPost: true, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false), messageId: messageId))
                                                        } else {
                                                            return .result(.peer(peer._asPeer(), .chat(textInputState: nil, subject: nil, peekData: nil)))
                                                        }
                                                    }
                                                }
                                            } else {
                                                return .single(.result(.peer(peer._asPeer(), .chat(textInputState: nil, subject: nil, peekData: nil))))
                                            }
                                        }
                                    }
                                } else {
                                    return .single(.result(.channelMessage(peer: peer._asPeer(), messageId: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: id), timecode: timecode)))
                                }
                            case let .replyThread(id, replyId):
                                let replyThreadMessageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: id)
                            
                                if case let .channel(channel) = peer, channel.flags.contains(.isForum) {
                                    return context.engine.peers.fetchForumChannelTopic(id: channel.id, threadId: Int64(replyThreadMessageId.id))
                                    |> map { result -> ResolveInternalUrlResult in
                                        switch result {
                                        case .progress:
                                            return .progress
                                        case let .result(info):
                                            if let _ = info {
                                                return .result(.replyThreadMessage(replyThreadMessage: ChatReplyThreadMessage(messageId: MessageId(peerId: channel.id, namespace: Namespaces.Message.Cloud, id: Int32(clamping: replyThreadMessageId.id)), channelMessageId: nil, isChannelPost: false, isForumPost: true, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false), messageId: MessageId(peerId: channel.id, namespace: Namespaces.Message.Cloud, id: replyId)))
                                            } else {
                                                return .result(.peer(peer._asPeer(), .chat(textInputState: nil, subject: nil, peekData: nil)))
                                            }
                                        }
                                    }
                                } else {
                                    return .single(.progress) |> then(context.engine.messages.fetchChannelReplyThreadMessage(messageId: replyThreadMessageId, atMessageId: nil)
                                    |> map(Optional.init)
                                    |> `catch` { _ -> Signal<ChatReplyThreadMessage?, NoError> in
                                        return .single(nil)
                                    }
                                    |> map { result -> ResolveInternalUrlResult in
                                        guard let result = result else {
                                            return .result(.channelMessage(peer: peer._asPeer(), messageId: replyThreadMessageId, timecode: nil))
                                        }
                                        return .result(.replyThreadMessage(replyThreadMessage: result, messageId: MessageId(peerId: result.messageId.peerId, namespace: Namespaces.Message.Cloud, id: replyId)))
                                    })
                                }
                            case let .voiceChat(invite):
                                return .single(.result(.joinVoiceChat(peer.id, invite)))
                            case let .story(id):
                                return .single(.progress) |> then(context.engine.messages.refreshStories(peerId: peer.id, ids: [id])
                                |> map { _ -> ResolveInternalUrlResult in
                                }
                                |> then(.single(.result(.story(peerId: peer.id, id: id)))))
                            case .boost:
                                return .single(.progress) |> then(combineLatest(
                                    context.engine.peers.getChannelBoostStatus(peerId: peer.id),
                                    context.engine.peers.getMyBoostStatus()
                                )
                                |> map { boostStatus, myBoostStatus -> ResolveInternalUrlResult in
                                    return .result(.boost(peerId: peer.id, status: boostStatus, myBoostStatus: myBoostStatus))
                                })
                        }
                    } else {
                        return .single(.result(.peer(peer._asPeer(), .chat(textInputState: nil, subject: nil, peekData: nil))))
                    }
                } else {
                    return .single(.result(.peer(nil, .info)))
                }
            }
        case let .peerId(peerId):
            return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> mapToSignal { peer -> Signal<ResolveInternalUrlResult, NoError> in
                if let peer = peer {
                    return .single(.result(.peer(peer._asPeer(), .chat(textInputState: nil, subject: nil, peekData: nil))))
                } else {
                    return .single(.result(.inaccessiblePeer))
                }
            }
        case let .contactToken(token):
        return .single(.progress) |> then(context.engine.peers.importContactToken(token: token)
            |> mapToSignal { peer -> Signal<ResolveInternalUrlResult, NoError> in
                if let peer = peer {
                    return .single(.result(.peer(peer._asPeer(), .info)))
                } else {
                    return .single(.result(.peer(nil, .info)))
                }
            })
        case let .privateMessage(messageId, threadId, timecode):
            return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId))
            |> mapToSignal { peer -> Signal<ResolveInternalUrlResult, NoError> in
                let foundPeer: Signal<EnginePeer?, NoError>
                if let peer = peer {
                    foundPeer = .single(peer)
                } else {
                    foundPeer = context.engine.peers.findChannelById(channelId: messageId.peerId.id._internalGetInt64Value())
                }
                return .single(.progress) |> then(foundPeer
                |> mapToSignal { foundPeer -> Signal<ResolveInternalUrlResult, NoError> in
                    if let foundPeer = foundPeer {
                        if case let .channel(channel) = foundPeer, channel.flags.contains(.isForum) {
                            if let threadId = threadId {
                                return context.engine.peers.fetchForumChannelTopic(id: channel.id, threadId: Int64(threadId))
                                |> map { result -> ResolveInternalUrlResult in
                                    switch result {
                                    case .progress:
                                        return .progress
                                    case let .result(info):
                                        if let _ = info {
                                            return .result(.replyThreadMessage(replyThreadMessage: ChatReplyThreadMessage(messageId: MessageId(peerId: channel.id, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId)), channelMessageId: nil, isChannelPost: false, isForumPost: true, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false), messageId: messageId))
                                        } else {
                                            return .result(.peer(peer?._asPeer(), .chat(textInputState: nil, subject: nil, peekData: nil)))
                                        }
                                    }
                                }
                            } else {
                                return context.engine.messages.getMessagesLoadIfNecessary([messageId], strategy: .cloud(skipLocal: false))
                                |> mapToSignal { result -> Signal<ResolveInternalUrlResult, NoError> in
                                    switch result {
                                    case .progress:
                                        return .single(.progress)
                                    case let .result(messages):
                                        if let threadId = messages.first?.threadId {
                                            return context.engine.peers.fetchForumChannelTopic(id: channel.id, threadId: threadId)
                                            |> map { result -> ResolveInternalUrlResult in
                                                switch result {
                                                case .progress:
                                                    return .progress
                                                case let .result(info):
                                                    if let _ = info {
                                                        return .result(.replyThreadMessage(replyThreadMessage: ChatReplyThreadMessage(messageId: MessageId(peerId: channel.id, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId)), channelMessageId: nil, isChannelPost: false, isForumPost: true, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false), messageId: messageId))
                                                    } else {
                                                        return .result(.peer(peer?._asPeer(), .chat(textInputState: nil, subject: nil, peekData: nil)))
                                                    }
                                                }
                                            }
                                        } else {
                                            return context.engine.peers.fetchForumChannelTopic(id: channel.id, threadId: Int64(messageId.id))
                                            |> map { result -> ResolveInternalUrlResult in
                                                switch result {
                                                case .progress:
                                                    return .progress
                                                case let .result(info):
                                                    if let _ = info {
                                                        return .result(.replyThread(messageId: messageId))
                                                    } else {
                                                        return .result(.peer(foundPeer._asPeer(), .chat(textInputState: nil, subject: nil, peekData: nil)))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else if let threadId = threadId {
                            let replyThreadMessageId = MessageId(peerId: foundPeer.id, namespace: Namespaces.Message.Cloud, id: threadId)
                            return .single(.progress) |> then(context.engine.messages.fetchChannelReplyThreadMessage(messageId: replyThreadMessageId, atMessageId: nil)
                            |> map(Optional.init)
                            |> `catch` { _ -> Signal<ChatReplyThreadMessage?, NoError> in
                                return .single(nil)
                            }
                            |> map { result -> ResolveInternalUrlResult in
                                guard let result = result else {
                                    return .result(.channelMessage(peer: foundPeer._asPeer(), messageId: replyThreadMessageId, timecode: timecode))
                                }
                                return .result(.replyThreadMessage(replyThreadMessage: result, messageId: messageId))
                            })
                        } else {
                            return .single(.result(.peer(foundPeer._asPeer(), .chat(textInputState: nil, subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: timecode), peekData: nil))))
                        }
                    } else {
                        return .single(.result(.inaccessiblePeer))
                    }
                })
            }
        case let .stickerPack(name, type):
            return .single(.result(.stickerPack(name: name, type: type)))
        case let .chatFolder(slug):
            return .single(.result(.chatFolder(slug: slug)))
        case let .invoice(slug):
            return .single(.progress) |> then(context.engine.payments.fetchBotPaymentInvoice(source: .slug(slug))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<TelegramMediaInvoice?, NoError> in
                return .single(nil)
            }
            |> map { invoice -> ResolveInternalUrlResult in
                guard let invoice = invoice else {
                    return .result(.invoice(slug: slug, invoice: nil))
                }
                return .result(.invoice(slug: slug, invoice: invoice))
            })
        case let .join(link):
            return .single(.result(.join(link)))
        case let .localization(identifier):
            return .single(.result(.localization(identifier)))
        case let .proxy(host, port, username, password, secret):
            return .single(.result(.proxy(host: host, port: port, username: username, password: password, secret: secret)))
        case let .internalInstantView(url):
            return resolveInstantViewUrl(account: context.account, url: url)
            |> map { result in
                switch result {
                case .progress:
                    return .progress
                case let .result(result):
                    return .result(result)
                }
            }
        case let .confirmationCode(code):
            return .single(.result(.confirmationCode(code)))
        case let .cancelAccountReset(phone, hash):
            return .single(.result(.cancelAccountReset(phone: phone, hash: hash)))
        case let .share(url, text, to):
            return .single(.result(.share(url: url, text: text, to: to)))
        case let .wallpaper(parameter):
            return .single(.result(.wallpaper(parameter)))
        case let .theme(slug):
            return .single(.result(.theme(slug)))
        case let .startAttach(name, payload, chooseValue):
            var choose: ResolvedBotChoosePeerTypes = []
            if let chooseValue = chooseValue?.lowercased() {
                let components = chooseValue.components(separatedBy: "+")
                if components.contains("users") {
                    choose.insert(.users)
                }
                if components.contains("bots") {
                    choose.insert(.bots)
                }
                if components.contains("groups") {
                    choose.insert(.groups)
                }
                if components.contains("channels") {
                    choose.insert(.channels)
                }
            }
            return context.engine.peers.resolvePeerByName(name: name)
            |> mapToSignal { result -> Signal<ResolveInternalUrlResult, NoError> in
                switch result {
                case .progress:
                    return .single(.progress)
                case let .result(peer):
                    if let peer = peer {
                        return .single(.result(.startAttach(peerId: peer.id, payload: payload, choose: !choose.isEmpty ? choose : nil)))
                    } else {
                        return .single(.result(.inaccessiblePeer))
                    }
                }
            }
        case let .premiumGiftCode(slug):
            return .single(.result(.premiumGiftCode(slug: slug)))
    }
}

public func isTelegramMeLink(_ url: String) -> Bool {
    let schemes = ["http://", "https://", ""]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                return true
            }
        }
    }
    return false
}

public func isTelegraPhLink(_ url: String) -> Bool {
    let schemes = ["http://", "https://", ""]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                return true
            }
        }
    }
    return false
}

public func parseProxyUrl(_ url: String) -> (host: String, port: Int32, username: String?, password: String?, secret: Data?)? {
    let schemes = ["http://", "https://", ""]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                if let internalUrl = parseInternalUrl(query: String(url[basePrefix.endIndex...])), case let .proxy(host, port, username, password, secret) = internalUrl {
                    return (host, port, username, password, secret)
                }
            }
        }
    }
    if let parsedUrl = URL(string: url), parsedUrl.scheme == "tg", let host = parsedUrl.host, let query = parsedUrl.query {
        if let internalUrl = parseInternalUrl(query: host + "?" + query), case let .proxy(host, port, username, password, secret) = internalUrl {
            return (host, port, username, password, secret)
        }
    }
    
    return nil
}

public func parseStickerPackUrl(_ url: String) -> String? {
    let schemes = ["http://", "https://", ""]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                if let internalUrl = parseInternalUrl(query: String(url[basePrefix.endIndex...])), case let .stickerPack(name, _) = internalUrl {
                    return name
                }
            }
        }
    }
    if let parsedUrl = URL(string: url), parsedUrl.scheme == "tg", let host = parsedUrl.host, let query = parsedUrl.query {
        if let internalUrl = parseInternalUrl(query: host + "?" + query), case let .stickerPack(name, _) = internalUrl {
            return name
        }
    }
    
    return nil
}

public func parseWallpaperUrl(_ url: String) -> WallpaperUrlParameter? {
    let schemes = ["http://", "https://", ""]
    for basePath in baseTelegramMePaths {
        for scheme in schemes {
            let basePrefix = scheme + basePath + "/"
            if url.lowercased().hasPrefix(basePrefix) {
                if let internalUrl = parseInternalUrl(query: String(url[basePrefix.endIndex...])), case let .wallpaper(wallpaper) = internalUrl {
                    return wallpaper
                }
            }
        }
    }
    if let parsedUrl = URL(string: url), parsedUrl.scheme == "tg", let host = parsedUrl.host, let query = parsedUrl.query {
        if let internalUrl = parseInternalUrl(query: host + "?" + query), case let .wallpaper(wallpaper) = internalUrl {
            return wallpaper
        }
    }
    
    return nil
}

private struct UrlHandlingConfiguration {
    static var defaultValue: UrlHandlingConfiguration {
        return UrlHandlingConfiguration(domains: [], urlAuthDomains: [])
    }
    
    public let domains: [String]
    public let urlAuthDomains: [String]
    
    fileprivate init(domains: [String], urlAuthDomains: [String]) {
        self.domains = domains
        self.urlAuthDomains = urlAuthDomains
    }
    
    static func with(appConfiguration: AppConfiguration) -> UrlHandlingConfiguration {
        if let data = appConfiguration.data {
            let urlAuthDomains = data["url_auth_domains"] as? [String] ?? []
            if let domains = data["autologin_domains"] as? [String] {
                return UrlHandlingConfiguration(domains: domains, urlAuthDomains: urlAuthDomains)
            }
        }
        return .defaultValue
    }
}

public func resolveUrlImpl(context: AccountContext, peerId: PeerId?, url: String, skipUrlAuth: Bool) -> Signal<ResolveUrlResult, NoError> {
    let schemes = ["http://", "https://", ""]
    
    return ApplicationSpecificNotice.getSecretChatLinkPreviews(accountManager: context.sharedContext.accountManager)
    |> mapToSignal { linkPreviews -> Signal<ResolveUrlResult, NoError> in
        return context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.App(), TelegramEngine.EngineData.Item.Configuration.Links())
        |> mapToSignal { appConfiguration, linksConfiguration -> Signal<ResolveUrlResult, NoError> in
            let urlHandlingConfiguration = UrlHandlingConfiguration.with(appConfiguration: appConfiguration)
            
            var skipUrlAuth = skipUrlAuth
            if let peerId = peerId, peerId.namespace == Namespaces.Peer.SecretChat {
                if let linkPreviews = linkPreviews, linkPreviews {
                } else {
                    skipUrlAuth = true
                }
            }
            
            var url = url
            if !url.contains("://") && !url.hasPrefix("tel:") && !url.hasPrefix("mailto:") && !url.hasPrefix("calshow:") {
                if !(url.hasPrefix("http") || url.hasPrefix("https")) {
                    url = "http://\(url)"
                }
            }
            
            if let urlValue = URL(string: url), let host = urlValue.host?.lowercased() {
                if urlHandlingConfiguration.domains.contains(host), var components = URLComponents(string: url) {
                    components.scheme = "https"
                    var queryItems = components.queryItems ?? []
                    queryItems.append(URLQueryItem(name: "autologin_token", value: linksConfiguration.autologinToken))
                    components.queryItems = queryItems
                    url = components.url?.absoluteString ?? url
                } else if !skipUrlAuth && urlHandlingConfiguration.urlAuthDomains.contains(host) {
                    return .single(.result(.urlAuth(url)))
                }
            }
            
            for basePath in baseTelegramMePaths {
                for scheme in schemes {
                    let basePrefix = scheme + basePath + "/"
                    var url = url
                    let lowercasedUrl = url.lowercased()
                    if (lowercasedUrl.hasPrefix(scheme) && (lowercasedUrl.hasSuffix(".\(basePath)") || lowercasedUrl.contains(".\(basePath)/") || lowercasedUrl.contains(".\(basePath)?"))) {
                        url = basePrefix + String(url[scheme.endIndex...]).replacingOccurrences(of: ".\(basePath)/", with: "").replacingOccurrences(of: ".\(basePath)", with: "")
                    }
                    if url.lowercased().hasPrefix(basePrefix) {
                        if let internalUrl = parseInternalUrl(query: String(url[basePrefix.endIndex...])) {
                            return resolveInternalUrl(context: context, url: internalUrl)
                            |> map { result -> ResolveUrlResult in
                                switch result {
                                case .progress:
                                    return .progress
                                case let .result(resolved):
                                    if let resolved = resolved {
                                        return .result(resolved)
                                    } else {
                                        return .result(.externalUrl(url))
                                    }
                                }
                            }
                        } else {
                            return .single(.result(.externalUrl(url)))
                        }
                    }
                }
            }
            for basePath in baseTelegraPhPaths {
                for scheme in schemes {
                    let basePrefix = scheme + basePath
                    if url.lowercased().hasPrefix(basePrefix) {
                        return resolveInstantViewUrl(account: context.account, url: url)
                    }
                }
            }
            return .single(.result(.externalUrl(url)))
        }
    }
}

public func resolveInstantViewUrl(account: Account, url: String) -> Signal<ResolveUrlResult, NoError> {
    return webpagePreview(account: account, urls: [url])
    |> mapToSignal { result -> Signal<ResolveUrlResult, NoError> in
        switch result {
        case .progress:
            return .single(.progress)
        case let .result(webpageResult):
            if let webpageResult = webpageResult {
                if case let .Loaded(content) = webpageResult.webpage.content {
                    if content.instantPage != nil {
                        var anchorValue: String?
                        if let anchorRange = url.range(of: "#") {
                            let anchor = url[anchorRange.upperBound...]
                            if !anchor.isEmpty {
                                anchorValue = String(anchor)
                            }
                        }
                        return .single(.result(.instantView(webpageResult.webpage, anchorValue)))
                    } else {
                        return .single(.result(.externalUrl(url)))
                    }
                } else {
                    return .complete()
                }
            } else {
                return .single(.result(.externalUrl(url)))
            }
        }
    }
}
