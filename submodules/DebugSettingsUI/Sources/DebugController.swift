import PtgSettingsUI

import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import MtProtoKit
import MessageUI
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import AppBundle
import ZipArchive
import WebKit
import InAppPurchaseManager

@objc private final class DebugControllerMailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}

private final class DebugControllerArguments {
    let sharedContext: SharedAccountContext
    let context: AccountContext?
    let mailComposeDelegate: DebugControllerMailComposeDelegate
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let pushController: (ViewController) -> Void
    let getRootController: () -> UIViewController?
    let getNavigationController: () -> NavigationController?
    
    init(sharedContext: SharedAccountContext, context: AccountContext?, mailComposeDelegate: DebugControllerMailComposeDelegate, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping (ViewController) -> Void, getRootController: @escaping () -> UIViewController?, getNavigationController: @escaping () -> NavigationController?) {
        self.sharedContext = sharedContext
        self.context = context
        self.mailComposeDelegate = mailComposeDelegate
        self.presentController = presentController
        self.pushController = pushController
        self.getRootController = getRootController
        self.getNavigationController = getNavigationController
    }
}

private enum DebugControllerSection: Int32 {
    case sticker
    case logs
    case logging
    case web
    case experiments
    case translation
    case videoExperiments
    case videoExperiments2
    case info
    case ptg
}

private enum DebugControllerEntry: ItemListNodeEntry {
    case testStickerImport(PresentationTheme)
    #if TEST_BUILD
    case sendLogs(PresentationTheme)
    case sendOneLog(PresentationTheme)
    case sendShareLogs
    case sendGroupCallLogs
    case sendStorageStats
    case sendNotificationLogs(PresentationTheme)
    case sendCriticalLogs(PresentationTheme)
    case sendAllLogs
    case sendDatabaseStats
    case sendChatMessagesStats
    case accounts(PresentationTheme)
    case logToFile(PresentationTheme, Bool)
    case logToConsole(PresentationTheme, Bool)
    case redactSensitiveData(PresentationTheme, Bool)
    #endif
    case keepChatNavigationStack(PresentationTheme, Bool)
    case skipReadHistory(PresentationTheme, Bool)
    case skipSetTyping(Bool)
    case unidirectionalSwipeToReply(Bool)
    case dustEffect(Bool)
    case callUIV2(Bool)
    #if TEST_BUILD
    case crashOnSlowQueries(PresentationTheme, Bool)
    case crashOnMemoryPressure(PresentationTheme, Bool)
    #endif
    case clearTips(PresentationTheme)
    case resetNotifications
    #if TEST_BUILD
    case crash(PresentationTheme)
    case resetData(PresentationTheme)
    case resetDatabase(PresentationTheme)
    case resetDatabaseAndCache(PresentationTheme)
    #endif
    case resetHoles(PresentationTheme)
    case reindexUnread(PresentationTheme)
    #if TEST_BUILD
    case resetCacheIndex
    #endif
    case reindexCache
    case resetBiometricsData(PresentationTheme)
    case webViewInspection(Bool)
    case resetWebViewCache(PresentationTheme)
    #if TEST_BUILD
    case optimizeDatabase(PresentationTheme)
    #endif
    case photoPreview(PresentationTheme, Bool)
    case knockoutWallpaper(PresentationTheme, Bool)
    case experimentalCompatibility(Bool)
    case enableDebugDataDisplay(Bool)
    case acceleratedStickers(Bool)
    case inlineForums(Bool)
    case localTranscription(Bool)
    case enableReactionOverrides(Bool)
    case storiesExperiment(Bool)
    case storiesJpegExperiment(Bool)
    case playlistPlayback(Bool)
    case enableQuickReactionSwitch(Bool)
    case voiceConference
    case preferredVideoCodec(Int, String, String?, Bool)
    case disableVideoAspectScaling(Bool)
    case enableNetworkFramework(Bool)
    case enableNetworkExperiments(Bool)
    case restorePurchases(PresentationTheme)
    #if TEST_BUILD
    case logTranslationRecognition(Bool)
    #endif
    case resetTranslationStates
    case hostInfo(PresentationTheme, String)
    case versionInfo(PresentationTheme)
    #if TEST_BUILD
    case ptgResetPasscodeAttempts
    #endif
    
    var section: ItemListSectionId {
        switch self {
        case .testStickerImport:
            return DebugControllerSection.sticker.rawValue
        #if TEST_BUILD
        case .sendLogs, .sendOneLog, .sendShareLogs, .sendGroupCallLogs, .sendStorageStats, .sendNotificationLogs, .sendCriticalLogs, .sendAllLogs:
            return DebugControllerSection.logs.rawValue
        case .sendDatabaseStats, .sendChatMessagesStats:
            return DebugControllerSection.logs.rawValue
        case .accounts:
            return DebugControllerSection.logs.rawValue
        case .logToFile, .logToConsole, .redactSensitiveData:
            return DebugControllerSection.logging.rawValue
        #endif
        case .webViewInspection, .resetWebViewCache:
            return DebugControllerSection.web.rawValue
        case .keepChatNavigationStack, .skipReadHistory, .skipSetTyping, .unidirectionalSwipeToReply, .dustEffect, .callUIV2:
            return DebugControllerSection.experiments.rawValue
        case .clearTips, .resetNotifications, .resetHoles, .reindexUnread, .reindexCache, .resetBiometricsData, .photoPreview, .knockoutWallpaper, .storiesExperiment, .storiesJpegExperiment, .playlistPlayback, .enableQuickReactionSwitch, .voiceConference, .experimentalCompatibility, .enableDebugDataDisplay, .acceleratedStickers, .inlineForums, .localTranscription, .enableReactionOverrides, .restorePurchases:
            return DebugControllerSection.experiments.rawValue
        #if TEST_BUILD
        case .crashOnSlowQueries, .crashOnMemoryPressure, .crash, .resetData, .resetDatabase, .resetDatabaseAndCache, .resetCacheIndex, .optimizeDatabase:
            return DebugControllerSection.experiments.rawValue
        case .logTranslationRecognition:
            return DebugControllerSection.translation.rawValue
        #endif
        case .resetTranslationStates:
            return DebugControllerSection.translation.rawValue
        case .preferredVideoCodec:
            return DebugControllerSection.videoExperiments.rawValue
        case .disableVideoAspectScaling, .enableNetworkFramework, .enableNetworkExperiments:
            return DebugControllerSection.videoExperiments2.rawValue
        case .hostInfo, .versionInfo:
            return DebugControllerSection.info.rawValue
        #if TEST_BUILD
        case .ptgResetPasscodeAttempts:
            return DebugControllerSection.ptg.rawValue
        #endif
        }
    }
    
    var stableId: Double {
        switch self {
        case .testStickerImport:
            return 0
        #if TEST_BUILD
        case .sendLogs:
            return 1
        case .sendOneLog:
            return 2
        case .sendShareLogs:
            return 3
        case .sendGroupCallLogs:
            return 4
        case .sendNotificationLogs:
            return 5
        case .sendCriticalLogs:
            return 6
        case .sendAllLogs:
            return 7
        case .sendStorageStats:
            return 8
        case .sendDatabaseStats:
            return 8.1
        case .sendChatMessagesStats:
            return 8.2
        case .accounts:
            return 9
        case .logToFile:
            return 10
        case .logToConsole:
            return 11
        case .redactSensitiveData:
            return 12
        #endif
        case .webViewInspection:
            return 13
        case .resetWebViewCache:
            return 14
        case .keepChatNavigationStack:
            return 15
        case .skipReadHistory:
            return 16
        case .skipSetTyping:
            return 16.5
        case .unidirectionalSwipeToReply:
            return 17
        case .dustEffect:
            return 18
        case .callUIV2:
            return 19
        #if TEST_BUILD
        case .crashOnSlowQueries:
            return 20
        case .crashOnMemoryPressure:
            return 21
        #endif
        case .clearTips:
            return 22
        case .resetNotifications:
            return 23
        #if TEST_BUILD
        case .crash:
            return 24
        case .resetData:
            return 25
        case .resetDatabase:
            return 26
        case .resetDatabaseAndCache:
            return 27
        #endif
        case .resetHoles:
            return 28
        case .reindexUnread:
            return 29
        #if TEST_BUILD
        case .resetCacheIndex:
            return 30
        #endif
        case .reindexCache:
            return 31
        case .resetBiometricsData:
            return 32
        #if TEST_BUILD
        case .optimizeDatabase:
            return 33
        #endif
        case .photoPreview:
            return 34
        case .knockoutWallpaper:
            return 35
        case .experimentalCompatibility:
            return 36
        case .enableDebugDataDisplay:
            return 37
        case .acceleratedStickers:
            return 38
        case .inlineForums:
            return 39
        case .localTranscription:
            return 40
        case .enableReactionOverrides:
            return 41
        case .restorePurchases:
            return 42
        #if TEST_BUILD
        case .logTranslationRecognition:
            return 43
        #endif
        case .resetTranslationStates:
            return 44
        case .storiesExperiment:
            return 45
        case .storiesJpegExperiment:
            return 46
        case .playlistPlayback:
            return 47
        case .enableQuickReactionSwitch:
            return 48
        case .voiceConference:
            return 49
        case let .preferredVideoCodec(index, _, _, _):
            return Double(50 + index)
        case .disableVideoAspectScaling:
            return 100
        case .enableNetworkFramework:
            return 101
        case .enableNetworkExperiments:
            return 102
        case .hostInfo:
            return 103
        case .versionInfo:
            return 104
        #if TEST_BUILD
        case .ptgResetPasscodeAttempts:
            return 1001
        #endif
        }
    }
    
    static func <(lhs: DebugControllerEntry, rhs: DebugControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DebugControllerArguments
        switch self {
        case .testStickerImport:
            return ItemListActionItem(presentationData: presentationData, title: "Simulate Stickers Import", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                if let url = getAppBundle().url(forResource: "importstickers", withExtension: "json"), let data = try? Data(contentsOf: url) {
                    let dataType = "org.telegram.third-party.stickerset"
                    if #available(iOS 10.0, *) {
                        UIPasteboard.general.setItems([[dataType: data]], options: [UIPasteboard.OptionsKey.localOnly: true, UIPasteboard.OptionsKey.expirationDate: NSDate(timeIntervalSinceNow: 60)])
                    } else {
                        UIPasteboard.general.setData(data, forPasteboardType: dataType)
                    }
                    context.sharedContext.openResolvedUrl(.importStickers, context: context, urlContext: .generic, navigationController: arguments.getNavigationController(), forceExternal: false, openPeer: { _, _ in }, sendFile: nil, sendSticker: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { c, a in arguments.presentController(c, a as? ViewControllerPresentationArguments) }, dismissInput: {}, contentContext: nil, progress: nil, completion: nil)
                }
            })
        #if TEST_BUILD
        case .sendLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Logs (Up to 40 MB)", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectLogs()
                |> deliverOnMainQueue).start(next: { logs in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer, _ in
                                let peerId = peer.id

                                if let strongController = controller {
                                    strongController.dismiss()

                                    let lineFeed = "\n".data(using: .utf8)!
                                    var rawLogData: Data = Data()
                                    for (name, path) in logs {
                                        if !rawLogData.isEmpty {
                                            rawLogData.append(lineFeed)
                                            rawLogData.append(lineFeed)
                                        }

                                        rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                            rawLogData.append(data)
                                        }
                                    }

                                    let tempSource = TempBox.shared.tempFile(fileName: "Log.txt")
                                    let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                                    
                                    let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                                    
                                    SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                                    guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                        return
                                    }
                                    
                                    TempBox.shared.dispose(tempSource)
                                    TempBox.shared.dispose(tempZip)

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                                    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                                    let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                                }
                            }
                            arguments.pushController(controller)
                        }))
                    }
                    items.append(ActionSheetButtonItem(title: "Via Email", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()

                        let composeController = MFMailComposeViewController()
                        composeController.mailComposeDelegate = arguments.mailComposeDelegate
                        composeController.setSubject("Telegram Logs")
                        for (name, path) in logs {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                            }
                        }
                        arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                    }))

                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    arguments.presentController(actionSheet, nil)
                })
            })
        case .sendOneLog:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Latest Logs (Up to 4 MB)", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectLogs()
                    |> deliverOnMainQueue).start(next: { logs in
                        let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        
                        var items: [ActionSheetButtonItem] = []
                        
                        if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                            items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                                controller.peerSelected = { [weak controller] peer, _ in
                                    let peerId = peer.id
                                    
                                    if let strongController = controller {
                                        strongController.dismiss()
                                        
                                        let lineFeed = "\n".data(using: .utf8)!
                                        var logData: Data = Data()
                                        
                                        var latestLogs: [(String, String)] = []
                                        if logs.count < 2 {
                                            latestLogs = logs
                                        } else {
                                            for i in (logs.count - 2) ..< logs.count {
                                                latestLogs.append(logs[i])
                                            }
                                        }
                                        
                                        for (name, path) in latestLogs {
                                            if !logData.isEmpty {
                                                logData.append(lineFeed)
                                                logData.append(lineFeed)
                                            }
                                            
                                            logData.append("------ File: \(name) ------\n".data(using: .utf8)!)
                                            
                                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                                logData.append(data)
                                            }
                                        }
                                        
                                        let id = Int64.random(in: Int64.min ... Int64.max)
                                        let fileResource = LocalFileMediaResource(fileId: id, size: Int64(logData.count), isSecretRelated: false)
                                        context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: logData)
                                        
                                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(logData.count), attributes: [.FileName(fileName: "Log-iOS-Short.txt")])
                                        let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                        
                                        let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                                    }
                                }
                                arguments.pushController(controller)
                            }))
                        }
                        
                        items.append(ActionSheetButtonItem(title: "Via Email", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            let composeController = MFMailComposeViewController()
                            composeController.mailComposeDelegate = arguments.mailComposeDelegate
                            composeController.setSubject("Telegram Logs")
                            for (name, path) in logs {
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                    composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                                }
                            }
                            arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                        }))
                        
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                            ])
                            ])
                        arguments.presentController(actionSheet, nil)
                    })
            })
        case .sendShareLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Share Logs (Up to 40 MB)", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectLogs(prefix: "/logs/share-logs")
                |> deliverOnMainQueue).start(next: { logs in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer, _ in
                                let peerId = peer.id

                                if let strongController = controller {
                                    strongController.dismiss()

                                    let lineFeed = "\n".data(using: .utf8)!
                                    var rawLogData: Data = Data()
                                    for (name, path) in logs {
                                        if !rawLogData.isEmpty {
                                            rawLogData.append(lineFeed)
                                            rawLogData.append(lineFeed)
                                        }

                                        rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                            rawLogData.append(data)
                                        }
                                    }

                                    let tempSource = TempBox.shared.tempFile(fileName: "Log.txt")
                                    let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                                    
                                    let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                                    
                                    SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                                    guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                        return
                                    }
                                    
                                    TempBox.shared.dispose(tempSource)
                                    TempBox.shared.dispose(tempZip)

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                                    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                                    let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                                }
                            }
                            arguments.pushController(controller)
                        }))
                    }
                    items.append(ActionSheetButtonItem(title: "Via Email", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()

                        let composeController = MFMailComposeViewController()
                        composeController.mailComposeDelegate = arguments.mailComposeDelegate
                        composeController.setSubject("Telegram Logs")
                        for (name, path) in logs {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                            }
                        }
                        arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                    }))

                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    arguments.presentController(actionSheet, nil)
                })
            })
        case .sendGroupCallLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Group Call Logs (Up to 40 MB)", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectLogs(basePath: arguments.context!.account.basePath + "/group-calls")
                |> deliverOnMainQueue).start(next: { logs in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer, _ in
                                let peerId = peer.id

                                if let strongController = controller {
                                    strongController.dismiss()

                                    let lineFeed = "\n".data(using: .utf8)!
                                    var rawLogData: Data = Data()
                                    for (name, path) in logs {
                                        if !rawLogData.isEmpty {
                                            rawLogData.append(lineFeed)
                                            rawLogData.append(lineFeed)
                                        }

                                        rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                            rawLogData.append(data)
                                        }
                                    }

                                    let tempSource = TempBox.shared.tempFile(fileName: "Log.txt")
                                    let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                                    
                                    let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                                    
                                    SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                                    guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                        return
                                    }
                                    
                                    TempBox.shared.dispose(tempSource)
                                    TempBox.shared.dispose(tempZip)

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                                    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                                    let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                                }
                            }
                            arguments.pushController(controller)
                        }))
                    }
                    items.append(ActionSheetButtonItem(title: "Via Email", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()

                        let composeController = MFMailComposeViewController()
                        composeController.mailComposeDelegate = arguments.mailComposeDelegate
                        composeController.setSubject("Telegram Logs")
                        for (name, path) in logs {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                            }
                        }
                        arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                    }))

                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    arguments.presentController(actionSheet, nil)
                })
            })
        case .sendNotificationLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Notification Logs (Up to 40 MB)", label: "", sectionId: self.section, style: .blocks, action: {
                let logsPath = arguments.sharedContext.basePath + "/logs/notification-logs"
                let _ = (Logger(rootPath: logsPath, basePath: logsPath).collectLogs()
                    |> deliverOnMainQueue).start(next: { logs in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer, _ in
                                let peerId = peer.id

                                if let strongController = controller {
                                    strongController.dismiss()

                                    let lineFeed = "\n".data(using: .utf8)!
                                    var rawLogData: Data = Data()
                                    for (name, path) in logs {
                                        if !rawLogData.isEmpty {
                                            rawLogData.append(lineFeed)
                                            rawLogData.append(lineFeed)
                                        }

                                        rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                            rawLogData.append(data)
                                        }
                                    }

                                    let tempSource = TempBox.shared.tempFile(fileName: "Log.txt")
                                    let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                                    
                                    let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                                    
                                    SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                                    guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                        return
                                    }
                                    
                                    TempBox.shared.dispose(tempSource)
                                    TempBox.shared.dispose(tempZip)

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                                    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                                    let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                                }
                            }
                            arguments.pushController(controller)
                        }))
                    }
                    items.append(ActionSheetButtonItem(title: "Via Email", color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()

                        let composeController = MFMailComposeViewController()
                        composeController.mailComposeDelegate = arguments.mailComposeDelegate
                        composeController.setSubject("Telegram Logs")
                        for (name, path) in logs {
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                            }
                        }
                        arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                    }))

                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    arguments.presentController(actionSheet, nil)
                })
            })
        case .sendCriticalLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Critical Logs", label: "", sectionId: self.section, style: .blocks, action: {
                let _ = (Logger.shared.collectShortLogFiles()
                    |> deliverOnMainQueue).start(next: { logs in
                        let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                        let actionSheet = ActionSheetController(presentationData: presentationData)
                        
                        var items: [ActionSheetButtonItem] = []
                        
                        if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                            items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                                controller.peerSelected = { [weak controller] peer, _ in
                                    let peerId = peer.id
                                    
                                    if let strongController = controller {
                                        strongController.dismiss()
                                        
                                        let messages = logs.map { (name, path) -> EnqueueMessage in
                                            let id = Int64.random(in: Int64.min ... Int64.max)
                                            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)])
                                            return .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                        }
                                        let _ = enqueueMessages(account: context.account, peerId: peerId, messages: messages).start()
                                    }
                                }
                                arguments.pushController(controller)
                            }))
                        }
                        
                        items.append(ActionSheetButtonItem(title: "Via Email", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            let composeController = MFMailComposeViewController()
                            composeController.mailComposeDelegate = arguments.mailComposeDelegate
                            composeController.setSubject("Telegram Logs")
                            for (name, path) in logs {
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) {
                                    composeController.addAttachmentData(data, mimeType: "application/text", fileName: name)
                                }
                            }
                            arguments.getRootController()?.present(composeController, animated: true, completion: nil)
                        }))
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                            })
                            ])])
                        arguments.presentController(actionSheet, nil)
                    })
            })
        case .sendAllLogs:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send All Logs", label: "", sectionId: self.section, style: .blocks, action: {
                let logTypes: [String] = [
                    "app-logs",
                    "broadcast-logs",
                    "siri-logs",
                    "widget-logs",
                    "notificationcontent-logs",
                    "notification-logs",
                    "share-logs"
                ]
                
                var logByType: [Signal<(type: String, logs: [(String, String)]), NoError>] = []
                for type in logTypes {
                    let logsPath = arguments.sharedContext.basePath + "/logs/\(type)"
                    logByType.append(Logger(rootPath: logsPath, basePath: logsPath).collectLogs()
                    |> map { result -> (type: String, logs: [(String, String)]) in
                        return (type, result)
                    })
                }
                
                let allLogs = combineLatest(logByType)
                
                let _ = (allLogs
                |> deliverOnMainQueue).start(next: { allLogs in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer, _ in
                                let peerId = peer.id

                                if let strongController = controller {
                                    strongController.dismiss()

                                    let lineFeed = "\n".data(using: .utf8)!
                                    
                                    var tempSources: [TempBoxFile] = []
                                    for (type, logItems) in allLogs {
                                        let tempSource = TempBox.shared.tempFile(fileName: "Log-\(type).txt")
                                        
                                        var rawLogData: Data = Data()
                                        for (name, path) in logItems {
                                            if !rawLogData.isEmpty {
                                                rawLogData.append(lineFeed)
                                                rawLogData.append(lineFeed)
                                            }

                                            rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                                            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                                rawLogData.append(data)
                                            }
                                        }
                                        
                                        let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                                        tempSources.append(tempSource)
                                    }

                                    let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                                    SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: tempSources.map(\.path))

                                    guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                                        return
                                    }
                                    
                                    tempSources.forEach(TempBox.shared.dispose)
                                    TempBox.shared.dispose(tempZip)

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                                    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/zip", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-All.txt.zip")])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                                    let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                                }
                            }
                            arguments.pushController(controller)
                        }))
                    }

                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    arguments.presentController(actionSheet, nil)
                })
            })
        case .sendStorageStats:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Storage Stats", label: "", sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context, context.sharedContext.applicationBindings.isMainApp else {
                    return
                }
                
                let allStats: Signal<Data, NoError> = Signal { subscriber in
                    DispatchQueue.global().async {
                        let log = collectRawStorageUsageReport(containerPath: context.sharedContext.applicationBindings.containerPath)
                        subscriber.putNext(log.data(using: .utf8) ?? Data())
                    }
                    
                    return EmptyDisposable
                }
                
                let _ = (allStats
                |> deliverOnMainQueue).start(next: { allStatsData in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)

                    var items: [ActionSheetButtonItem] = []

                    if let context = arguments.context, context.sharedContext.applicationBindings.isMainApp {
                        items.append(ActionSheetButtonItem(title: "Via Telegram", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()

                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
                            controller.peerSelected = { [weak controller] peer, _ in
                                let peerId = peer.id

                                if let strongController = controller {
                                    strongController.dismiss()

                                    let id = Int64.random(in: Int64.min ... Int64.max)
                                    let fileResource = LocalFileMediaResource(fileId: id, size: Int64(allStatsData.count), isSecretRelated: false)
                                    context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: allStatsData)

                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/zip", size: Int64(allStatsData.count), attributes: [.FileName(fileName: "StorageReport.txt")])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                                    let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                                }
                            }
                            arguments.pushController(controller)
                        }))
                    }

                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    arguments.presentController(actionSheet, nil)
                })
            })
        case .sendDatabaseStats:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Database Stats", label: "", sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                
                let fillerPath = context.sharedContext.basePath + "/filler.data"
                let fillerSize = fileSize(fillerPath, useTotalFileAllocatedSize: true) ?? 0
                
                let allStats: Signal<Data, NoError> = context.sharedContext.activeAccountContexts
                |> take(1)
                |> mapToSignal { activeAccountContexts in
                    let contexts = activeAccountContexts.accounts.map({ $0.1 }) + activeAccountContexts.inactiveAccounts.map({ $0.1 })
                    return combineLatest(
                        [context.sharedContext.accountManager.debugDumpAllDbStats() |> reduceLeft(value: "", f: +)] +
                        contexts.map { context in
                            return (
                                context.account.postbox.transaction { transaction in
                                    let accountName = transaction.getPeer(context.account.peerId)?.debugDisplayTitle ?? ""
                                    return "Account: \(accountName)\n\n"
                                }
                                |> then (context.account.debugDumpAllDbStats())
                            )
                            |> reduceLeft(value: "", f: +)
                        }
                    )
                    |> map { stats in
                        return ("Filler file size: \(fillerSize / (1024 * 1024)) MB\n\n" + stats.reduce("", +)).data(using: .utf8) ?? Data()
                    }
                }
                
                let _ = (allStats
                |> deliverOnMainQueue).start(next: { allStatsData in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)
                    
                    var items: [ActionSheetButtonItem] = []
                    
                    if let context = arguments.context {
                        items.append(ActionSheetButtonItem(title: "Add to Saved Messages", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            let peerId = context.account.peerId
                            
                            let id = Int64.random(in: Int64.min ... Int64.max)
                            let fileResource = LocalFileMediaResource(fileId: id, size: Int64(allStatsData.count), isSecretRelated: false)
                            context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: allStatsData)
                            
                            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/zip", size: Int64(allStatsData.count), attributes: [.FileName(fileName: "DatabaseReport.txt")])
                            let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                            
                            let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                        }))
                    }
                    
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    arguments.presentController(actionSheet, nil)
                })
            })
        case .sendChatMessagesStats:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Send Chat Messages Stats", label: "", sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                
                let allStats: Signal<Data, NoError> = context.account.debugChatMessagesStat()
                |> map { stats in
                    return stats.data(using: .utf8) ?? Data()
                }
                
                let _ = (allStats
                |> deliverOnMainQueue).start(next: { allStatsData in
                    let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(presentationData: presentationData)
                    
                    var items: [ActionSheetButtonItem] = []
                    
                    if let context = arguments.context {
                        items.append(ActionSheetButtonItem(title: "Add to Saved Messages", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            let peerId = context.account.peerId
                            
                            let id = Int64.random(in: Int64.min ... Int64.max)
                            let fileResource = LocalFileMediaResource(fileId: id, size: Int64(allStatsData.count), isSecretRelated: false)
                            context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: allStatsData)
                            
                            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/zip", size: Int64(allStatsData.count), attributes: [.FileName(fileName: "ChatMessagesReport.txt")])
                            let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                            
                            let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
                        }))
                    }
                    
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    arguments.presentController(actionSheet, nil)
                })
            })
        case .accounts:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Accounts", label: "", sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                arguments.pushController(debugAccountsController(context: context, accountManager: arguments.sharedContext.accountManager))
            })
        case let .logToFile(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Log to File", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedLogToFile(value)
                }).start()
            })
        case let .logToConsole(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Log to Console", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedLogToConsole(value)
                }).start()
            })
        case let .redactSensitiveData(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Remove Sensitive Data", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateLoggingSettings(accountManager: arguments.sharedContext.accountManager, {
                    $0.withUpdatedRedactSensitiveData(value)
                }).start()
            })
        #endif
        case let .keepChatNavigationStack(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Keep Chat Stack", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.keepChatNavigationStack = value
                    return settings
                }).start()
            })
        case let .skipReadHistory(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Skip read history", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.skipReadHistory = value
                    return settings
                }).start()
            })
        case let .skipSetTyping(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Skip set typing (per account)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                if let context = arguments.context {
                    let _ = updatePtgAccountSettings(engine: context.engine, { settings in
                        return settings.withUpdated(skipSetTyping: value)
                    }).start()
                }
            })
        case let .unidirectionalSwipeToReply(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Legacy swipe to reply", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.unidirectionalSwipeToReply = value
                    return settings
                }).start()
            })
        case let .dustEffect(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Dust Effect", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.dustEffect = value
                    return settings
                }).start()
            })
        case let .callUIV2(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Call UI V2", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.callUIV2 = value
                    return settings
                }).start()
            })
        #if TEST_BUILD
        case let .crashOnSlowQueries(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Crash when slow", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.crashOnLongQueries = value
                    return settings
                }).start()
            })
        case let .crashOnMemoryPressure(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Crash on memory pressure", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.crashOnMemoryPressure = value
                    return settings
                }).start()
            })
        #endif
        case .clearTips:
            return ItemListActionItem(presentationData: presentationData, title: "Clear Tips", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let _ = (arguments.sharedContext.accountManager.transaction { transaction -> Void in
                    transaction.clearNotices()
                }).start()
                if let context = arguments.context {
                    let _ = context.engine.itemCache.clear(collectionIds: [
                        Namespaces.CachedItemCollection.cachedPollResults,
                        Namespaces.CachedItemCollection.cachedStickerPacks
                    ]).start()

                    let _ = context.engine.peers.unmarkChatListFeaturedFiltersAsSeen()
                }
            })
        #if TEST_BUILD
        case let .logTranslationRecognition(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Log Language Recognition", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.logLanguageRecognition = value
                    return settings
                }).start()
            })
        #endif
        case .resetTranslationStates:
            return ItemListActionItem(presentationData: presentationData, title: "Reset Translation States", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if let context = arguments.context {
                    let _ = context.engine.itemCache.clear(collectionIds: [
                        ApplicationSpecificItemCacheCollectionId.translationState
                    ]).start()
                }
            })
        case .resetNotifications:
            return ItemListActionItem(presentationData: presentationData, title: "Reset Notifications", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                UIApplication.shared.unregisterForRemoteNotifications()
                
                if let context = arguments.context {
                    let controller = textAlertController(context: context, title: nil, text: "Now restart the app", actions: [TextAlertAction(type: .genericAction, title: "OK", action: {})])
                    arguments.presentController(controller, nil)
                }
            })
        #if TEST_BUILD
        case .crash:
            return ItemListActionItem(presentationData: presentationData, title: "Crash", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                preconditionFailure()
            })
        case .resetData:
            return ItemListActionItem(presentationData: presentationData, title: "Reset Data", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: "All data will be lost."),
                    ActionSheetButtonItem(title: "Reset Data", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let databasePath = arguments.sharedContext.accountManager.basePath + "/db"
                        let _ = try? FileManager.default.removeItem(atPath: databasePath)
                        preconditionFailure()
                    }),
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                        ])])
                arguments.presentController(actionSheet, nil)
            })
        case .resetDatabase:
            return ItemListActionItem(presentationData: presentationData, title: "Clear Database", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: "All secret chats will be lost."),
                    ActionSheetButtonItem(title: "Clear Database", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let databasePath = context.account.basePath + "/postbox/db"
                        let _ = try? FileManager.default.removeItem(atPath: databasePath)
                        exit(0)
                    }),
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                arguments.presentController(actionSheet, nil)
            })
        case .resetDatabaseAndCache:
            return ItemListActionItem(presentationData: presentationData, title: "Clear Database and Cache", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: "All secret chats will be lost."),
                    ActionSheetButtonItem(title: "Clear Database", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let databasePath = context.account.basePath + "/postbox"
                        let _ = try? FileManager.default.removeItem(atPath: databasePath)
                        exit(0)
                    }),
                    ]), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                arguments.presentController(actionSheet, nil)
            })
        #endif
        case .resetHoles:
            return ItemListActionItem(presentationData: presentationData, title: "Reset Holes", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                arguments.presentController(controller, nil)
                let _ = (context.engine.messages.debugAddHoles()
                |> deliverOnMainQueue).start(completed: {
                    controller.dismiss()
                })
            })
        case .reindexUnread:
            return ItemListActionItem(presentationData: presentationData, title: "Reindex Unread Counters", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                arguments.presentController(controller, nil)
                let _ = (context.engine.messages.debugReindexUnreadCounters()
                |> deliverOnMainQueue).start(completed: {
                    controller.dismiss()
                })
            })
        #if TEST_BUILD
        case .resetCacheIndex:
            return ItemListActionItem(presentationData: presentationData, title: "Reset Cache Index [!]", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                
                context.account.postbox.mediaBox.storageBox.reset()
            })
        #endif
        case .reindexCache:
            return ItemListActionItem(presentationData: presentationData, title: "Reindex Cache", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                
                var signal = context.engine.resources.reindexCacheInBackground(lowImpact: false)
                
                var cancelImpl: (() -> Void)?
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let progressSignal = Signal<Never, NoError> { subscriber in
                    let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    arguments.presentController(controller, nil)
                    return ActionDisposable { [weak controller] in
                        Queue.mainQueue().async() {
                            controller?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.15, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.start()
                
                let reindexDisposable = MetaDisposable()
                
                signal = signal
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                cancelImpl = {
                    reindexDisposable.set(nil)
                }
                reindexDisposable.set((signal
                |> deliverOnMainQueue).start(completed: {
                }))
            })
        case .resetBiometricsData:
            return ItemListActionItem(presentationData: presentationData, title: "Reset Biometrics Data", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                let _ = updatePresentationPasscodeSettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    return settings.withUpdatedBiometricsDomainState(nil).withUpdatedShareBiometricsDomainState(nil)
                }).start()
            })
        case let .webViewInspection(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Allow Web View Inspection", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = updateExperimentalUISettingsInteractively(accountManager: arguments.sharedContext.accountManager, { settings in
                    var settings = settings
                    settings.allowWebViewInspection = value
                    return settings
                }).start()
            })
        case .resetWebViewCache:
            return ItemListActionItem(presentationData: presentationData, title: "Clear Web View Cache", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler:{ })
            })
        #if TEST_BUILD
        case .optimizeDatabase:
            return ItemListActionItem(presentationData: presentationData, title: "Optimize Database", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let context = arguments.context else {
                    return
                }
                let presentationData = arguments.sharedContext.currentPresentationData.with { $0 }
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                arguments.presentController(controller, nil)
                let _ = (context.account.postbox.optimizeStorage(minFreePagesFraction: 0.0)
                    |> deliverOnMainQueue).start(completed: {
                        controller.dismiss()
                        
                        let controller = OverlayStatusController(theme: presentationData.theme, type: .success)
                        arguments.presentController(controller, nil)
                    })
            })
        #endif
        case let .photoPreview(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Media Preview (Updated)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.chatListPhotos = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .knockoutWallpaper(_, value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Knockout Wallpaper", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.knockoutWallpaper = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .experimentalCompatibility(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Experimental Compatibility", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.experimentalCompatibility = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableDebugDataDisplay(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Debug Data Display", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.enableDebugDataDisplay = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .acceleratedStickers(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Accelerated Stickers", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.acceleratedStickers = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .inlineForums(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Inline Forums", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.inlineForums = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .localTranscription(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Local Transcription", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.localTranscription = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableReactionOverrides(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Effect Overrides", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.enableReactionOverrides = value
                        if !value {
                            settings.accountReactionEffectOverrides.removeAll()
                            settings.accountStickerEffectOverrides.removeAll()
                        }
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .storiesExperiment(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Story Search Debug", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.storiesExperiment = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .storiesJpegExperiment(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "JPEG X", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.storiesJpegExperiment = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .playlistPlayback(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Playlist Playback", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.playlistPlayback = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableQuickReactionSwitch(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Enable Quick Reaction", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.disableQuickReaction = !value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case .voiceConference:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Voice Conference (Test)", label: "", sectionId: self.section, style: .blocks, action: {
                guard let _ = arguments.context else {
                    return
                }
            })
        case let .preferredVideoCodec(_, title, value, isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .right, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.preferredVideoCodec = value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .disableVideoAspectScaling(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Video Cropping Optimization", value: !value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.disableVideoAspectScaling = !value
                        return PreferencesEntry(settings)
                    })
                }).start()
            })
        case let .enableNetworkFramework(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Network X [Restart App]", value: value, sectionId: self.section, style: .blocks, updated: { value in
                if let context = arguments.context {
                    let _ = updateNetworkSettingsInteractively(postbox: context.account.postbox, network: context.account.network, { settings in
                        var settings = settings
                        settings.useNetworkFramework = value
                        return settings
                    }).start()
                }
            })
        case let .enableNetworkExperiments(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Download X [Restart App]", value: value, sectionId: self.section, style: .blocks, updated: { value in
                if let context = arguments.context {
                    let _ = updateNetworkSettingsInteractively(postbox: context.account.postbox, network: context.account.network, { settings in
                        var settings = settings
                        settings.useExperimentalDownload = value
                        return settings
                    }).start()
                }
            })
        case .restorePurchases:
            return ItemListActionItem(presentationData: presentationData, title: "Restore Purchases", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.context?.inAppPurchaseManager?.restorePurchases(completion: { state in
                    let text: String
                    switch state {
                        case .succeed:
                            text = "Done"
                        case .failed:
                            text = "Failed"
                    }
                    if let context = arguments.context {
                        let controller = textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: "OK", action: {})])
                        arguments.presentController(controller, nil)
                    }
                })
            })
        case let .hostInfo(_, string):
            return ItemListTextItem(presentationData: presentationData, text: .plain(string), sectionId: self.section)
        case .versionInfo:
            let bundle = Bundle.main
            let bundleId = bundle.bundleIdentifier ?? ""
            let bundleVersion = bundle.infoDictionary?["CFBundleShortVersionString"] ?? ""
            let bundleBuild = bundle.infoDictionary?[kCFBundleVersionKey as String] ?? ""
            return ItemListTextItem(presentationData: presentationData, text: .plain("\(bundleId)\n\(bundleVersion) (\(bundleBuild))"), sectionId: self.section)
        #if TEST_BUILD
        case .ptgResetPasscodeAttempts:
            return ItemListActionItem(presentationData: presentationData, title: "Reset Secret Code Attempts", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                guard let passcodeAttemptAccounter = arguments.context?.sharedContext.passcodeAttemptAccounter else {
                    return
                }
                passcodeAttemptAccounter.debugResetAllCounters()
            })
        #endif
        }
    }
}

private func debugControllerEntries(sharedContext: SharedAccountContext, presentationData: PresentationData, loggingSettings: LoggingSettings, mediaInputSettings: MediaInputSettings, experimentalSettings: ExperimentalUISettings, networkSettings: NetworkSettings?, ptgAccountSettings: PtgAccountSettings?, hasLegacyAppData: Bool, useBetaFeatures: Bool) -> [DebugControllerEntry] {
    var entries: [DebugControllerEntry] = []

    let isMainApp = sharedContext.applicationBindings.isMainApp
    let testToolsEnabled = sharedContext.currentPtgSettings.with({ $0.testToolsEnabled == true })
    
    #if TEST_BUILD
    if testToolsEnabled {
        //    entries.append(.testStickerImport(presentationData.theme))
        entries.append(.sendLogs(presentationData.theme))
        //entries.append(.sendOneLog(presentationData.theme))
        entries.append(.sendShareLogs)
        entries.append(.sendGroupCallLogs)
        entries.append(.sendNotificationLogs(presentationData.theme))
        entries.append(.sendCriticalLogs(presentationData.theme))
        entries.append(.sendAllLogs)
        entries.append(.sendStorageStats)
        entries.append(.sendDatabaseStats)
        entries.append(.sendChatMessagesStats)
        if isMainApp {
            entries.append(.accounts(presentationData.theme))
        }
        
        entries.append(.logToFile(presentationData.theme, loggingSettings.logToFile))
        entries.append(.logToConsole(presentationData.theme, loggingSettings.logToConsole))
        entries.append(.redactSensitiveData(presentationData.theme, loggingSettings.redactSensitiveData))
    }
    #endif

    if isMainApp {
        #if DEBUG
        entries.append(.webViewInspection(experimentalSettings.allowWebViewInspection))
        #endif
        entries.append(.resetWebViewCache(presentationData.theme))
        
        entries.append(.keepChatNavigationStack(presentationData.theme, experimentalSettings.keepChatNavigationStack))
        #if TEST_BUILD
        entries.append(.skipReadHistory(presentationData.theme, experimentalSettings.skipReadHistory))
        if let ptgAccountSettings {
            entries.append(.skipSetTyping(ptgAccountSettings.skipSetTyping))
        }
        #endif
        entries.append(.unidirectionalSwipeToReply(experimentalSettings.unidirectionalSwipeToReply))
        entries.append(.dustEffect(experimentalSettings.dustEffect))
        entries.append(.callUIV2(experimentalSettings.callUIV2))
    }
    #if TEST_BUILD
    entries.append(.crashOnSlowQueries(presentationData.theme, experimentalSettings.crashOnLongQueries))
    entries.append(.crashOnMemoryPressure(presentationData.theme, experimentalSettings.crashOnMemoryPressure))
    #endif
    if isMainApp {
        entries.append(.clearTips(presentationData.theme))
        entries.append(.resetNotifications)
    }
    #if TEST_BUILD
    if testToolsEnabled {
        entries.append(.crash(presentationData.theme))
        entries.append(.resetData(presentationData.theme))
        entries.append(.resetDatabase(presentationData.theme))
        entries.append(.resetDatabaseAndCache(presentationData.theme))
    }
    #endif
    entries.append(.resetHoles(presentationData.theme))
    if isMainApp {
        entries.append(.reindexUnread(presentationData.theme))
        #if TEST_BUILD
        if testToolsEnabled {
            entries.append(.resetCacheIndex)
        }
        #endif
        entries.append(.reindexCache)
    }
    #if TEST_BUILD
    if testToolsEnabled {
        entries.append(.optimizeDatabase(presentationData.theme))
    }
    #endif
    if isMainApp {
        entries.append(.knockoutWallpaper(presentationData.theme, experimentalSettings.knockoutWallpaper))
        entries.append(.experimentalCompatibility(experimentalSettings.experimentalCompatibility))
        entries.append(.enableDebugDataDisplay(experimentalSettings.enableDebugDataDisplay))
        entries.append(.acceleratedStickers(experimentalSettings.acceleratedStickers))
        entries.append(.inlineForums(experimentalSettings.inlineForums))
        entries.append(.localTranscription(experimentalSettings.localTranscription))
        if case .internal = sharedContext.applicationBindings.appBuildType {
            entries.append(.enableReactionOverrides(experimentalSettings.enableReactionOverrides))
        }
//        entries.append(.restorePurchases(presentationData.theme))
        
        #if TEST_BUILD
        if testToolsEnabled {
            entries.append(.logTranslationRecognition(experimentalSettings.logLanguageRecognition))
        }
        #endif
        entries.append(.resetTranslationStates)
        
        if case .internal = sharedContext.applicationBindings.appBuildType {
            entries.append(.storiesExperiment(experimentalSettings.storiesExperiment))
            entries.append(.storiesJpegExperiment(experimentalSettings.storiesJpegExperiment))
        }
        entries.append(.playlistPlayback(experimentalSettings.playlistPlayback))
        entries.append(.enableQuickReactionSwitch(!experimentalSettings.disableQuickReaction))
    }
    
    let codecs: [(String, String?)] = [
        ("No Preference", nil),
        ("H265", "H265"),
        ("H264", "H264"),
        ("VP8", "VP8"),
        ("VP9", "VP9")
    ]
    
    for i in 0 ..< codecs.count {
        entries.append(.preferredVideoCodec(i, codecs[i].0, codecs[i].1, experimentalSettings.preferredVideoCodec == codecs[i].1))
    }

    if isMainApp {
        entries.append(.disableVideoAspectScaling(experimentalSettings.disableVideoAspectScaling))
        entries.append(.enableNetworkFramework(networkSettings?.useNetworkFramework ?? useBetaFeatures))
        entries.append(.enableNetworkExperiments(networkSettings?.useExperimentalDownload ?? false))
    }

    if let backupHostOverride = networkSettings?.backupHostOverride {
        entries.append(.hostInfo(presentationData.theme, "Host: \(backupHostOverride)"))
    }
//    entries.append(.versionInfo(presentationData.theme))
    
    #if TEST_BUILD
    if testToolsEnabled {
        entries.append(.ptgResetPasscodeAttempts)
    }
    #endif
    
    return entries
}

public func debugController(sharedContext: SharedAccountContext, context: AccountContext?, modal: Bool = false) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var getRootControllerImpl: (() -> UIViewController?)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    
    let arguments = DebugControllerArguments(sharedContext: sharedContext, context: context, mailComposeDelegate: DebugControllerMailComposeDelegate(), presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, getRootController: {
        return getRootControllerImpl?()
    }, getNavigationController: {
        return getNavigationControllerImpl?()
    })
    
    let appGroupName = "group.\(Bundle.main.bundleIdentifier!)"
    let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
    
    var hasLegacyAppData = false
    if let appGroupUrl = maybeAppGroupUrl {
        let statusPath = appGroupUrl.path + "/Documents/importcompleted"
        hasLegacyAppData = FileManager.default.fileExists(atPath: statusPath)
    }
    
    let preferencesSignal: Signal<PreferencesView?, NoError>
    if let context = context {
        preferencesSignal = context.account.postbox.preferencesView(keys: [PreferencesKeys.networkSettings, ApplicationSpecificPreferencesKeys.ptgAccountSettings])
        |> map(Optional.init)
    } else {
        preferencesSignal = .single(nil)
    }
    
    let signal = combineLatest(sharedContext.presentationData, sharedContext.accountManager.sharedData(keys: Set([SharedDataKeys.loggingSettings, ApplicationSpecificSharedDataKeys.mediaInputSettings, ApplicationSpecificSharedDataKeys.experimentalUISettings])), preferencesSignal)
    |> map { presentationData, sharedData, preferences -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let loggingSettings: LoggingSettings
        if let value = sharedData.entries[SharedDataKeys.loggingSettings]?.get(LoggingSettings.self) {
            loggingSettings = value
        } else {
            loggingSettings = LoggingSettings.defaultSettings
        }
        
        let mediaInputSettings: MediaInputSettings
        if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.mediaInputSettings]?.get(MediaInputSettings.self) {
            mediaInputSettings = value
        } else {
            mediaInputSettings = MediaInputSettings.defaultSettings
        }
        
        let experimentalSettings: ExperimentalUISettings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
        
        let networkSettings: NetworkSettings? = preferences?.values[PreferencesKeys.networkSettings]?.get(NetworkSettings.self)
        
        var leftNavigationButton: ItemListNavigationButton?
        if modal {
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
        }
        
        var useBetaFeatures: Bool = false
        if let context {
            useBetaFeatures = context.account.network.useBetaFeatures
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Debug"), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: debugControllerEntries(sharedContext: sharedContext, presentationData: presentationData, loggingSettings: loggingSettings, mediaInputSettings: mediaInputSettings, experimentalSettings: experimentalSettings, networkSettings: networkSettings, ptgAccountSettings: preferences.flatMap { PtgAccountSettings($0.values[ApplicationSpecificPreferencesKeys.ptgAccountSettings]) }, hasLegacyAppData: hasLegacyAppData, useBetaFeatures: useBetaFeatures), style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    
    let controller = ItemListController(sharedContext: sharedContext, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    getRootControllerImpl = { [weak controller] in
        return controller?.view.window?.rootViewController
    }
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}

/*
public func triggerDebugSendLogsUI(context: AccountContext, additionalInfo: String = "", pushController: @escaping (ViewController) -> Void) {
    let _ = (Logger.shared.collectLogs()
    |> deliverOnMainQueue).start(next: { logs in
        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
        controller.peerSelected = { [weak controller] peer, _ in
            let peerId = peer.id

            if let strongController = controller {
                strongController.dismiss()

                let lineFeed = "\n".data(using: .utf8)!
                var rawLogData: Data = Data()
                for (name, path) in logs {
                    if !rawLogData.isEmpty {
                        rawLogData.append(lineFeed)
                        rawLogData.append(lineFeed)
                    }

                    rawLogData.append("------ File: \(name) ------\n".data(using: .utf8)!)

                    if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                        rawLogData.append(data)
                    }
                }
                
                if !additionalInfo.isEmpty {
                    rawLogData.append("------ Additional Info ------\n".data(using: .utf8)!)
                    rawLogData.append("\(additionalInfo)".data(using: .utf8)!)
                }
                
                let tempSource = TempBox.shared.tempFile(fileName: "Log.txt")
                let tempZip = TempBox.shared.tempFile(fileName: "destination.zip")
                
                let _ = try? rawLogData.write(to: URL(fileURLWithPath: tempSource.path))
                
                SSZipArchive.createZipFile(atPath: tempZip.path, withFilesAtPaths: [tempSource.path])

                guard let gzippedData = try? Data(contentsOf: URL(fileURLWithPath: tempZip.path)) else {
                    return
                }
                
                TempBox.shared.dispose(tempSource)
                TempBox.shared.dispose(tempZip)

                let id = Int64.random(in: Int64.min ... Int64.max)
                let fileResource = LocalFileMediaResource(fileId: id, size: Int64(gzippedData.count), isSecretRelated: false)
                context.account.postbox.mediaBox.storeResourceData(fileResource.id, data: gzippedData)

                let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: fileResource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/text", size: Int64(gzippedData.count), attributes: [.FileName(fileName: "Log-iOS-Full.txt.zip")])
                let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])

                let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [message]).start()
            }
        }
        pushController(controller)
    })
}
*/
