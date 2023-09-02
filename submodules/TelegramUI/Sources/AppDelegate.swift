import ItemListUI
import MonotonicTime
import AppLockState
import PtgSecretPasscodes
import PtgSecretPasscodesUI

import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import UserNotifications
import Intents
import Postbox
import PushKit
import AsyncDisplayKit
import TelegramUIPreferences
import TelegramPresentationData
import TelegramCallsUI
import TelegramVoip
import BuildConfig
import BuildConfigExtra
import DeviceCheck
import AccountContext
import OverlayStatusController
import UndoUI
import LegacyUI
import PassportUI
import WatchBridge
import SettingsUI
import AppBundle
import UrlHandling
import OpenSSLEncryptionProvider
import AppLock
import PresentationDataUtils
import TelegramIntents
import AccountUtils
import CoreSpotlight
import TelegramAudio
import DebugSettingsUI
import BackgroundTasks
import UIKitRuntimeUtils
import StoreKit
import PhoneNumberFormat
import AuthorizationUI
import ManagedFile
import DeviceProximity
import MediaEditor

#if canImport(AppCenter)
import AppCenter
import AppCenterCrashes
#endif

private let handleVoipNotifications = false

private var testIsLaunched = false

private func isKeyboardWindow(window: NSObject) -> Bool {
    let typeName = NSStringFromClass(type(of: window))
    if #available(iOS 9.0, *) {
        if typeName.hasPrefix("UI") && typeName.hasSuffix("RemoteKeyboardWindow") {
            return true
        }
    } else {
        if typeName.hasPrefix("UI") && typeName.hasSuffix("TextEffectsWindow") {
            return true
        }
    }
    return false
}

private func isKeyboardView(view: NSObject) -> Bool {
    let typeName = NSStringFromClass(type(of: view))
    if typeName.hasPrefix("UI") && typeName.hasSuffix("InputSetHostView") {
        return true
    }
    return false
}

private func isKeyboardViewContainer(view: NSObject) -> Bool {
    let typeName = NSStringFromClass(type(of: view))
    if typeName.hasPrefix("UI") && typeName.hasSuffix("InputSetContainerView") {
        return true
    }
    return false
}

private class ApplicationStatusBarHost: StatusBarHost {
    private let application = UIApplication.shared
    
    var isApplicationInForeground: Bool {
        switch self.application.applicationState {
        case .background:
            return false
        default:
            return true
        }
    }
    
    var statusBarFrame: CGRect {
        return self.application.statusBarFrame
    }
    var statusBarStyle: UIStatusBarStyle {
        get {
            return self.application.statusBarStyle
        } set(value) {
            self.setStatusBarStyle(value, animated: false)
        }
    }
    
    func setStatusBarStyle(_ style: UIStatusBarStyle, animated: Bool) {
        if self.shouldChangeStatusBarStyle?(style) ?? true {
            self.application.internalSetStatusBarStyle(style, animated: animated)
        }
    }
    
    var shouldChangeStatusBarStyle: ((UIStatusBarStyle) -> Bool)?
    
    func setStatusBarHidden(_ value: Bool, animated: Bool) {
        self.application.internalSetStatusBarHidden(value, animation: animated ? .fade : .none)
    }
    
    var keyboardWindow: UIWindow? {
        if #available(iOS 16.0, *) {
            return UIApplication.shared.internalGetKeyboard()
        }
        
        for window in UIApplication.shared.windows {
            if isKeyboardWindow(window: window) {
                return window
            }
        }
        return nil
    }
    
    var keyboardView: UIView? {
        guard let keyboardWindow = self.keyboardWindow else {
            return nil
        }
        
        for view in keyboardWindow.subviews {
            if isKeyboardViewContainer(view: view) {
                for subview in view.subviews {
                    if isKeyboardView(view: subview) {
                        return subview
                    }
                }
            }
        }
        return nil
    }
}

private func legacyDocumentsPath() -> String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/legacy"
}

protocol SupportedStartCallIntent {
    @available(iOS 10.0, *)
    var contacts: [INPerson]? { get }
}

@available(iOS 10.0, *)
extension INStartAudioCallIntent: SupportedStartCallIntent {}

protocol SupportedStartVideoCallIntent {
    @available(iOS 10.0, *)
    var contacts: [INPerson]? { get }
}

@available(iOS 10.0, *)
extension INStartVideoCallIntent: SupportedStartVideoCallIntent {}

private enum QueuedWakeup: Int32 {
    case call
    case backgroundLocation
}

final class SharedApplicationContext {
    let sharedContext: SharedAccountContextImpl
    let notificationManager: SharedNotificationManager
    let wakeupManager: SharedWakeupManager
    let overlayMediaController: ViewController & OverlayMediaController
    
    init(sharedContext: SharedAccountContextImpl, notificationManager: SharedNotificationManager, wakeupManager: SharedWakeupManager) {
        self.sharedContext = sharedContext
        self.notificationManager = notificationManager
        self.wakeupManager = wakeupManager
        self.overlayMediaController = OverlayMediaControllerImpl()
    }
}

private struct AccountManagerState {
    struct NotificationKey {
        var accountId: AccountRecordId
        var id: Data
        var key: Data
    }

    var notificationKeys: [NotificationKey]
}

private func extractAccountManagerState(records: AccountRecordsView<TelegramAccountManagerTypes>) -> AccountManagerState {
    return AccountManagerState(
        notificationKeys: records.records.compactMap { record -> AccountManagerState.NotificationKey? in
            for attribute in record.attributes {
                if case let .backupData(backupData) = attribute {
                    if let notificationEncryptionKeyId = backupData.data?.notificationEncryptionKeyId, let notificationEncryptionKey = backupData.data?.notificationEncryptionKey {
                        return AccountManagerState.NotificationKey(
                            accountId: record.id,
                            id: notificationEncryptionKeyId,
                            key: notificationEncryptionKey
                        )
                    }
                }
            }
            return nil
        }
    )
}

extension UserDefaults {
    @objc dynamic var suppressedNotificationForAccounId: String? {
        return string(forKey: "suppressedNotificationForAccounId")
    }
}

@objc(AppDelegate) class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate, UNUserNotificationCenterDelegate, URLSessionDelegate, URLSessionTaskDelegate {
    @objc var window: UIWindow?
    var nativeWindow: (UIWindow & WindowHost)?
    var mainWindow: Window1!
    private var dataImportSplash: LegacyDataImportSplash?
    
    private var buildConfig: BuildConfig?
    let episodeId = arc4random()
    
    private let isInForegroundPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var isInForegroundValue = false
    private let isActivePromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var isActiveValue = false
    let hasActiveAudioSession = Promise<Bool>(false)
    
    private let sharedContextPromise = Promise<SharedApplicationContext>()
    private let watchCommunicationManagerPromise = Promise<WatchCommunicationManager?>()

    private var accountManager: AccountManager<TelegramAccountManagerTypes>?
    private var accountManagerState: AccountManagerState?
    
    private var contextValue: AuthorizedApplicationContext?
    private let context = Promise<AuthorizedApplicationContext?>()
    private let contextDisposable = MetaDisposable()
    
    private var authContextValue: UnauthorizedApplicationContext?
    private let authContext = Promise<UnauthorizedApplicationContext?>()
    private let authContextDisposable = MetaDisposable()
    
    private let logoutDisposable = MetaDisposable()
    
    private let openNotificationSettingsWhenReadyDisposable = MetaDisposable()
    private let openChatWhenReadyDisposable = MetaDisposable()
    private let openUrlWhenReadyDisposable = MetaDisposable()
    
    private let badgeDisposable = MetaDisposable()
    private let quickActionsDisposable = MetaDisposable()
    
    private var pushRegistry: PKPushRegistry?
    
    private let notificationAuthorizationDisposable = MetaDisposable()
    
    private var replyFromNotificationsDisposables = DisposableSet()
    private var watchedCallsDisposables = DisposableSet()
    
    private var _notificationTokenPromise: Promise<Data>?
    private let voipTokenPromise = Promise<Data>()
    
    private var reindexCacheDisposable: Disposable?
    
    private var firebaseSecrets: [String: String] = [:] {
        didSet {
            if self.firebaseSecrets != oldValue {
                self.firebaseSecretStream.set(.single(self.firebaseSecrets))
            }
        }
    }
    private let firebaseSecretStream = Promise<[String: String]>([:])
    
    private var urlSessions: [URLSession] = []
    private func urlSession(identifier: String) -> URLSession {
        if let existingSession = self.urlSessions.first(where: { $0.configuration.identifier == identifier }) {
            return existingSession
        }
        
        let baseAppBundleId = Bundle.main.bundleIdentifier!
        let appGroupName = "group.\(baseAppBundleId)"

        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.sharedContainerIdentifier = appGroupName
        configuration.isDiscretionary = false
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        self.urlSessions.append(session)
        return session
    }
    
    private var pendingUrlSessionBackgroundEventsCompletion: (() -> Void)?
    
    private var notificationTokenPromise: Promise<Data> {
        if let current = self._notificationTokenPromise {
            return current
        } else {
            let promise = Promise<Data>()
            self._notificationTokenPromise = promise
            
            return promise
        }
    }
    
    private var clearNotificationsManager: ClearNotificationsManager?
    
    private let idleTimerExtensionSubscribers = Bag<Void>()
    
    private var alertActions: (primary: (() -> Void)?, other: (() -> Void)?)?
    
    private let deviceToken = Promise<Data?>(nil)
        
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        precondition(!testIsLaunched)
        testIsLaunched = true
        
        let _ = voipTokenPromise.get().start(next: { token in
            self.deviceToken.set(.single(token))
        })
        
        let launchStartTime = CFAbsoluteTimeGetCurrent()
        
        let statusBarHost = ApplicationStatusBarHost()
        let (window, hostView) = nativeWindowHostView()
        self.mainWindow = Window1(hostView: hostView, statusBarHost: statusBarHost)
        if let traitCollection = window.rootViewController?.traitCollection {
            if #available(iOS 13.0, *) {
                switch traitCollection.userInterfaceStyle {
                case .light, .unspecified:
                    hostView.containerView.backgroundColor = UIColor.white
                default:
                    hostView.containerView.backgroundColor = UIColor.black
                }
            } else {
                hostView.containerView.backgroundColor = UIColor.white
            }
        } else {
            hostView.containerView.backgroundColor = UIColor.white
        }
        self.window = window
        self.nativeWindow = window
        
        if !UIDevice.current.isBatteryMonitoringEnabled {
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
        
        let clearNotificationsManager = ClearNotificationsManager(getNotificationIds: { completion in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: { notifications in
                    var result: [(String, NotificationManagedNotificationRequestId)] = []
                    for notification in notifications {
                        if let requestId = NotificationManagedNotificationRequestId(string: notification.request.identifier) {
                            result.append((notification.request.identifier, requestId))
                        } else {
                            let payload = notification.request.content.userInfo
                            var notificationRequestId: NotificationManagedNotificationRequestId?
                            
                            var peerId: PeerId?
                            if let fromId = payload["from_id"] {
                                let fromIdValue = fromId as! NSString
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
                            } else if let fromId = payload["chat_id"] {
                                let fromIdValue = fromId as! NSString
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
                            } else if let fromId = payload["channel_id"] {
                                let fromIdValue = fromId as! NSString
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
                            }
                            
                            if let msgId = payload["msg_id"] {
                                let msgIdValue = msgId as! NSString
                                if let peerId = peerId {
                                    notificationRequestId = .messageId(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(msgIdValue.intValue)))
                                }
                            }
                            
                            if let notificationRequestId = notificationRequestId {
                                result.append((notification.request.identifier, notificationRequestId))
                            }
                        }
                    }
                    completion.f(result)
                })
            } else {
                var result: [(String, NotificationManagedNotificationRequestId)] = []
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if let requestId = NotificationManagedNotificationRequestId(string: id) {
                                result.append((id, requestId))
                            }
                        }
                    }
                }
                completion.f(result)
            }
        }, removeNotificationIds: { ids in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
            } else {
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if ids.contains(id) {
                                UIApplication.shared.cancelLocalNotification(notification)
                            }
                        }
                    }
                }
            }
        }, getPendingNotificationIds: { completion in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { requests in
                    var result: [(String, NotificationManagedNotificationRequestId)] = []
                    for request in requests {
                        if let requestId = NotificationManagedNotificationRequestId(string: request.identifier) {
                            result.append((request.identifier, requestId))
                        }
                    }
                    completion.f(result)
                })
            } else {
                var result: [(String, NotificationManagedNotificationRequestId)] = []
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if let requestId = NotificationManagedNotificationRequestId(string: id) {
                                result.append((id, requestId))
                            }
                        }
                    }
                }
                completion.f(result)
            }
        }, removePendingNotificationIds: { ids in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
            } else {
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if ids.contains(id) {
                                UIApplication.shared.cancelLocalNotification(notification)
                            }
                        }
                    }
                }
            }
        })
        self.clearNotificationsManager = clearNotificationsManager
        
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        
        let baseAppBundleId = Bundle.main.bundleIdentifier!
        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
        self.buildConfig = buildConfig
        let signatureDict = BuildConfigExtra.signatureDict()
        
        let apiId: Int32 = buildConfig.apiId
        let apiHash: String = buildConfig.apiHash
        let languagesCategory = "ios"
        
        let autolockDeadine: Signal<Int32?, NoError>
        if #available(iOS 10.0, *) {
            autolockDeadine = .single(nil)
        } else {
            autolockDeadine = self.context.get()
            |> mapToSignal { context -> Signal<Int32?, NoError> in
                guard let context = context else {
                    return .single(nil)
                }
                return context.context.sharedContext.appLockContext.autolockDeadline
            }
        }
        
        let networkArguments = NetworkInitializationArguments(apiId: apiId, apiHash: apiHash, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: PresentationCallManagerImpl.voipMaxLayer, voipVersions: PresentationCallManagerImpl.voipVersions(includeExperimental: true, includeReference: false).map { version, supportsVideo -> CallSessionManagerImplementationVersion in
            CallSessionManagerImplementationVersion(version: version, supportsVideo: supportsVideo)
        }, appData: self.deviceToken.get()
        |> map { token in
            let data = buildConfig.bundleData(withAppToken: token, signatureDict: signatureDict)
            if let data = data, let _ = String(data: data, encoding: .utf8) {
            } else {
                Logger.shared.log("data", "can't deserialize")
            }
            return data
        }, autolockDeadine: autolockDeadine, encryptionProvider: OpenSSLEncryptionProvider(), deviceModelName: nil, useBetaFeatures: !buildConfig.isAppStoreBuild, isICloudEnabled: buildConfig.isICloudEnabled)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            self.mainWindow?.presentNative(UIAlertController(title: nil, message: "Error 2", preferredStyle: .alert))
            return true
        }
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        performAppGroupUpgrades(appGroupPath: appGroupUrl.path, rootPath: rootPath)
        
        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
        let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
        
        TempBox.initializeShared(basePath: rootPath, processType: "app", launchSpecificId: Int64.random(in: Int64.min ... Int64.max))
        
        let writeAbilityTestFile = TempBox.shared.tempFile(fileName: "test.bin")
        var writeAbilityTestSuccess = true
        if let testFile = ManagedFile(queue: nil, path: writeAbilityTestFile.path, mode: .readwrite) {
            let bufferSize = 128 * 1024
            let randomBuffer = malloc(bufferSize)!
            defer {
                free(randomBuffer)
            }
            arc4random_buf(randomBuffer, bufferSize)
            var writtenBytes = 0
            while writtenBytes < 1024 * 1024 {
                let actualBytes = testFile.write(randomBuffer, count: bufferSize)
                writtenBytes += actualBytes
                if actualBytes != bufferSize {
                    writeAbilityTestSuccess = false
                    break
                }
            }
            testFile._unsafeClose()
            TempBox.shared.dispose(writeAbilityTestFile)
        } else {
            writeAbilityTestSuccess = false
        }
        
        if !writeAbilityTestSuccess {
            let alertController = UIAlertController(title: nil, message: "The device does not have sufficient free space.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                preconditionFailure()
            }))
            self.mainWindow?.presentNative(alertController)
            
            return true
        }
        
        let legacyLogs: [String] = [
            "broadcast-logs",
            "siri-logs",
            "widget-logs",
            "notificationcontent-logs",
            "notification-logs"
        ]
        for item in legacyLogs {
            let _ = try? FileManager.default.removeItem(atPath: "\(rootPath)/\(item)")
        }
        
        let logsPath = rootPath + "/logs/app-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        Logger.setSharedLogger(Logger(rootPath: rootPath, basePath: logsPath))

        setManagedAudioSessionLogger({ s in
            Logger.shared.log("ManagedAudioSession", s)
            Logger.shared.shortLog("ManagedAudioSession", s)
        })
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: rootPath + "/accounts-metadata"), includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
            for url in contents {
                Logger.shared.log("App \(self.episodeId)", "metadata: \(url.path)")
            }
        }
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: rootPath), includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
            for url in contents {
                Logger.shared.log("App \(self.episodeId)", "root: \(url.path)")
                if url.lastPathComponent.hasPrefix("account-") {
                    if let subcontents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
                        for suburl in subcontents {
                            Logger.shared.log("App \(self.episodeId)", "account \(url.lastPathComponent): \(suburl.path)")
                        }
                    }
                }
            }
        }
        
        //ASDisableLogging()
        
        initializeLegacyComponents(application: application, currentSizeClassGetter: {
            return UIUserInterfaceSizeClass.compact
        }, currentHorizontalClassGetter: {
            return UIUserInterfaceSizeClass.compact
        }, documentsPath: legacyDocumentsPath(), currentApplicationBounds: {
            return UIScreen.main.bounds
        }, canOpenUrl: { url in
            return UIApplication.shared.canOpenURL(url)
        }, openUrl: { url in
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        })
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }
        
        GlobalExperimentalSettings.isAppStoreBuild = buildConfig.isAppStoreBuild
        GlobalExperimentalSettings.enableFeed = false
        
        self.window?.makeKeyAndVisible()
        
        var hasActiveCalls: Signal<Bool, NoError> = .single(false)
        if CallKitIntegration.isAvailable, let callKitIntegration = CallKitIntegration.shared {
            hasActiveCalls = callKitIntegration.hasActiveCalls
        }
        self.hasActiveAudioSession.set(
            combineLatest(queue: .mainQueue(),
                hasActiveCalls,
                MediaManagerImpl.globalAudioSession.isActive()
            )
            |> map { hasActiveCalls, isActive -> Bool in
                return hasActiveCalls || isActive
            }
            |> distinctUntilChanged
        )
        
        let applicationBindings = TelegramApplicationBindings(isMainApp: true, appBundleId: baseAppBundleId, appBuildType: buildConfig.isAppStoreBuild ? .public : .internal, containerPath: appGroupUrl.path, appSpecificScheme: buildConfig.appSpecificUrlScheme, openUrl: { url in
            var parsedUrl = URL(string: url)
            if let parsed = parsedUrl {
                if parsed.scheme == nil || parsed.scheme!.isEmpty {
                    parsedUrl = URL(string: "https://\(url)")
                }
                if parsed.scheme == "tg" {
                    return
                }
            }
            
            if let parsedUrl = parsedUrl {
                UIApplication.shared.open(parsedUrl, options: [:], completionHandler: nil)
            } else if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let parsedUrl = URL(string: escapedUrl) {
                UIApplication.shared.open(parsedUrl, options: [:], completionHandler: nil)
            }
        }, openUniversalUrl: { url, completion in
            if #available(iOS 10.0, *) {
                var parsedUrl = URL(string: url)
                if let parsed = parsedUrl {
                    if parsed.scheme == nil || parsed.scheme!.isEmpty {
                        parsedUrl = URL(string: "https://\(url)")
                    }
                }
                
                if let parsedUrl = parsedUrl {
                    return UIApplication.shared.open(parsedUrl, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: true as NSNumber], completionHandler: { value in
                        completion.completion(value)
                    })
                } else if let escapedUrl = (url.removingPercentEncoding ?? url).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let parsedUrl = URL(string: escapedUrl) {
                    return UIApplication.shared.open(parsedUrl, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: true as NSNumber], completionHandler: { value in
                        completion.completion(value)
                    })
                } else {
                    completion.completion(false)
                }
            } else {
                completion.completion(false)
            }
        }, canOpenUrl: { url in
            var parsedUrl = URL(string: url)
            if let parsed = parsedUrl {
                if parsed.scheme == nil || parsed.scheme!.isEmpty {
                    parsedUrl = URL(string: "https://\(url)")
                }
            }
            if let parsedUrl = parsedUrl {
                return UIApplication.shared.canOpenURL(parsedUrl)
            } else if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let parsedUrl = URL(string: escapedUrl) {
                return UIApplication.shared.canOpenURL(parsedUrl)
            } else {
                return false
            }
        }, getTopWindow: {
            for window in application.windows.reversed() {
                if window === self.window || window === statusBarHost.keyboardWindow {
                    return window
                }
            }
            return application.windows.last
        }, displayNotification: { text in
        }, applicationInForeground: self.isInForegroundPromise.get(),
           applicationIsActive: self.isActivePromise.get(),
           clearMessageNotifications: { ids in
            for id in ids {
                self.clearNotificationsManager?.append(id)
            }
        }, clearAllNotifications: {
            self.clearNotificationsManager?.clearAll()
        }, clearPeerNotifications: { peerIds in
            self.clearNotificationsManager?.clearPeers(peerIds: peerIds)
        }, pushIdleTimerExtension: {
            let disposable = MetaDisposable()
            Queue.mainQueue().async {
                let wasEmpty = self.idleTimerExtensionSubscribers.isEmpty
                let index = self.idleTimerExtensionSubscribers.add(Void())
                
                if wasEmpty {
                    application.isIdleTimerDisabled = true
                }
                
                disposable.set(ActionDisposable {
                    Queue.mainQueue().async {
                        self.idleTimerExtensionSubscribers.remove(index)
                        if self.idleTimerExtensionSubscribers.isEmpty {
                            application.isIdleTimerDisabled = false
                        }
                    }
                })
            }
            
            return disposable
        }, openSettings: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }, openAppStorePage: {
            let appStoreId = buildConfig.appStoreId
            if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreId)") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }, openSubscriptions: {
            if #available(iOS 15, *), let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                Task {
                    try await AppStore.showManageSubscriptions(in: scene)
                }
            } else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }, registerForNotifications: { completion in
            Logger.shared.log("App \(self.episodeId)", "register for notifications begin")
            let _ = (self.context.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { context in
                if let context = context {
                    Logger.shared.log("App \(self.episodeId)", "register for notifications initiate")
                    self.registerForNotifications(context: context.context, authorize: true, completion: completion)
                }
            })
        }, requestSiriAuthorization: { completion in
            if #available(iOS 10, *) {
                INPreferences.requestSiriAuthorization { status in
                    if case .authorized = status {
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            } else {
                completion(false)
            }
        }, siriAuthorization: {
            if buildConfig.isSiriEnabled {
                if #available(iOS 10, *) {
                    switch INPreferences.siriAuthorizationStatus() {
                    case .authorized:
                        return .allowed
                    case .denied, .restricted:
                        return .denied
                    case .notDetermined:
                        return .notDetermined
                    @unknown default:
                        return .notDetermined
                    }
                } else {
                    return .denied
                }
            } else {
                return .denied
            }
        }, getWindowHost: {
            return self.nativeWindow
        }, presentNativeController: { controller in
            self.window?.rootViewController?.present(controller, animated: true, completion: nil)
        }, dismissNativeController: {
            self.window?.rootViewController?.dismiss(animated: true, completion: nil)
        }, getAvailableAlternateIcons: {
            if #available(iOS 10.3, *) {
                var icons = [
                    PresentationAppIcon(name: "PrimaryIcon", imageName: "AppIconLLC60x60", isDefault: true),
                    PresentationAppIcon(name: "YellowIcon", imageName: "YellowIcon"),
                    PresentationAppIcon(name: "OrangeIcon", imageName: "OrangeIcon"),
                    PresentationAppIcon(name: "RedIcon", imageName: "RedIcon"),
                ]
                
                // premium icons are used only in premium demo screens
                icons.append(PresentationAppIcon(name: "Premium", imageName: "Premium", isPremium: true))
                icons.append(PresentationAppIcon(name: "PremiumBlack", imageName: "PremiumBlack", isPremium: true))
                icons.append(PresentationAppIcon(name: "PremiumTurbo", imageName: "PremiumTurbo", isPremium: true))
                
                return icons
            } else {
                return []
            }
        }, getAlternateIconName: {
            if #available(iOS 10.3, *) {
                return application.alternateIconName
            } else {
                return nil
            }
        }, requestSetAlternateIconName: { name, completion in
            if #available(iOS 10.3, *) {
                application.setAlternateIconName(name, completionHandler: { error in
                    if let error = error {
                       Logger.shared.log("App \(self.episodeId)", "failed to set alternate icon with error \(error.localizedDescription)")
                    }
                    completion(error == nil)
                })
            } else {
                completion(false)
            }
        }, forceOrientation: { orientation in
            let value = orientation.rawValue
            if #available(iOSApplicationExtension 16.0, iOS 16.0, *) {
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                var interfaceOrientations: UIInterfaceOrientationMask = []
                switch orientation {
                case .portrait:
                    interfaceOrientations = .portrait
                case .landscapeLeft:
                    interfaceOrientations = .landscapeLeft
                case .landscapeRight:
                    interfaceOrientations = .landscapeRight
                case .portraitUpsideDown:
                    interfaceOrientations = .portraitUpsideDown
                case .unknown:
                    interfaceOrientations = .portrait
                @unknown default:
                    interfaceOrientations = .portrait
                }
                windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: interfaceOrientations))
            } else {
                UIDevice.current.setValue(value, forKey: "orientation")
                UINavigationController.attemptRotationToDeviceOrientation()
            }
        })
        
        let accountManager = AccountManager<TelegramAccountManagerTypes>(basePath: rootPath + "/accounts-metadata", isTemporary: false, isReadOnly: false, useCaches: true, removeDatabaseOnError: true)
        self.accountManager = accountManager

        telegramUIDeclareEncodables()
        initializeAccountManagement()
        
        let pushRegistry = PKPushRegistry(queue: .main)
        if #available(iOS 9.0, *) {
            pushRegistry.desiredPushTypes = Set([.voIP])
        }
        self.pushRegistry = pushRegistry
        pushRegistry.delegate = self

        self.accountManagerState = extractAccountManagerState(records: accountManager._internalAccountRecordsSync(excludeAccountIds: []))
        let _ = (accountManager.accountRecords(excludeAccountIds: .single([]))
        |> deliverOnMainQueue).start(next: { view in
            self.accountManagerState = extractAccountManagerState(records: view)
        })

        var systemUserInterfaceStyle: WindowUserInterfaceStyle = .light
        if #available(iOS 13.0, *) {
            if let traitCollection = window.rootViewController?.traitCollection {
                systemUserInterfaceStyle = WindowUserInterfaceStyle(style: traitCollection.userInterfaceStyle)
            }
        }
        
        let appContextIsReady = self.sharedContextPromise.get()
        |> take(1)
        |> mapToSignal { sharedApplicationContext in
            return combineLatest(self.context.get(), self.authContext.get(), sharedApplicationContext.sharedContext.inactiveAccountIds)
            |> mapToSignal { context, authContext, inactiveAccountIds -> Signal<Bool, NoError> in
                if let context {
                    if inactiveAccountIds.contains(context.context.account.id) {
                        return .single(false)
                    }
                    return context.isReadyAndPresented.get()
                }
                if let authContext {
                    return authContext.isReadyAndPresented.get()
                }
                return .single(false)
            }
            |> filter { $0 }
            |> take(1)
        }
        
        let checkTimeoutInPtgSecretPasscodes: Signal<Void, NoError>
        if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data) {
            checkTimeoutInPtgSecretPasscodes = updatePtgSecretPasscodes(accountManager, { current in
                return PtgSecretPasscodes(secretPasscodes: current.secretPasscodes.map { sp in
                    return sp.withUpdated(active: sp.active && (sp.timeout == nil || !isSecretPasscodeTimedout(timeout: sp.timeout!, state: state)))
                }, dbCoveringAccounts: current.dbCoveringAccounts, cacheCoveringAccounts: current.cacheCoveringAccounts)
            })
        } else {
            checkTimeoutInPtgSecretPasscodes = .complete()
        }
        
        let initialPresentationDataAndSettingsPromise = Promise<InitialPresentationDataAndSettings>()
        let _ = checkTimeoutInPtgSecretPasscodes.start(completed: {
            initialPresentationDataAndSettingsPromise.set(currentPresentationDataAndSettings(accountManager: accountManager, systemUserInterfaceStyle: systemUserInterfaceStyle))
        })
        
        let sharedContextSignal = initialPresentationDataAndSettingsPromise.get()
        |> map { initialPresentationDataAndSettings -> (AccountManager, InitialPresentationDataAndSettings) in
            return (accountManager, initialPresentationDataAndSettings)
        }
        |> deliverOnMainQueue
        |> mapToSignal { accountManager, initialPresentationDataAndSettings -> Signal<(SharedApplicationContext, LoggingSettings), NoError> in
            self.mainWindow?.hostView.containerView.backgroundColor =  initialPresentationDataAndSettings.presentationData.theme.chatList.backgroundColor
            
            let legacyBasePath = appGroupUrl.path
            
            let presentationDataPromise = Promise<PresentationData>()
            let appLockContext = AppLockContextImpl(rootPath: rootPath, window: self.mainWindow!, rootController: self.window?.rootViewController, applicationBindings: applicationBindings, accountManager: accountManager, presentationDataSignal: presentationDataPromise.get(), lockIconInitialFrame: {
                return (self.mainWindow?.viewController as? TelegramRootController)?.chatListController?.lockViewFrame
            }, appContextIsReady: appContextIsReady)
            
            var setPresentationCall: ((PresentationCall?) -> Void)?
            let sharedContext = SharedAccountContextImpl(mainWindow: self.mainWindow, sharedContainerPath: legacyBasePath, basePath: rootPath, encryptionParameters: encryptionParameters, accountManager: accountManager, appLockContext: appLockContext, applicationBindings: applicationBindings, initialPresentationDataAndSettings: initialPresentationDataAndSettings, networkArguments: networkArguments, hasInAppPurchases: buildConfig.isAppStoreBuild && buildConfig.apiId == 1, rootPath: rootPath, legacyBasePath: legacyBasePath, apsNotificationToken: self.notificationTokenPromise.get() |> map(Optional.init), voipNotificationToken: self.voipTokenPromise.get() |> map(Optional.init), firebaseSecretStream: self.firebaseSecretStream.get(), setNotificationCall: { call in
                setPresentationCall?(call)
            }, navigateToChat: { accountId, peerId, messageId in
                self.openChatWhenReady(accountId: accountId, peerId: peerId, threadId: nil, messageId: messageId, storyId: nil)
            }, displayUpgradeProgress: { progress in
                if let progress = progress {
                    if self.dataImportSplash == nil {
                        self.dataImportSplash = makeLegacyDataImportSplash(theme: initialPresentationDataAndSettings.presentationData.theme, strings: initialPresentationDataAndSettings.presentationData.strings)
                        self.dataImportSplash?.serviceAction = {
                            self.debugPressed()
                        }
                        self.mainWindow.coveringView = self.dataImportSplash
                    }
                    self.dataImportSplash?.progress = (.generic, progress)
                } else if let dataImportSplash = self.dataImportSplash {
                    self.dataImportSplash = nil
                    if self.mainWindow.coveringView === dataImportSplash {
                        self.mainWindow.coveringView = nil
                    }
                }
            }, appDelegate: self)
            
            appLockContext.sharedAccountContext = sharedContext
            
            presentationDataPromise.set(sharedContext.presentationData)
            
            sharedContext.presentGlobalController = { [weak self] c, a in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.mainWindow.present(c, on: .root)
            }
            sharedContext.presentCrossfadeController = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                var exists = false
                strongSelf.mainWindow.forEachViewController({ controller in
                    if controller is ThemeSettingsCrossfadeController || controller is ThemeSettingsController || controller is ThemePreviewController {
                        exists = true
                    }
                    return true
                })
                
                if !exists {
                    strongSelf.mainWindow.present(ThemeSettingsCrossfadeController(), on: .root)
                }
            }
            
            let notificationManager = SharedNotificationManager(episodeId: self.episodeId, application: application, clearNotificationsManager: clearNotificationsManager, inForeground: applicationBindings.applicationInForeground, accounts: sharedContext.activeAccountContexts |> map { primary, accounts, _, _ in accounts.map({ ($0.1.account, $0.1.account.id == primary?.account.id) }) }, pollLiveLocationOnce: { accountId in
                let _ = (self.context.get()
                |> filter {
                    return $0 != nil
                }
                |> take(1)
                |> deliverOnMainQueue).start(next: { context in
                    if let context = context, context.context.account.id == accountId {
                        context.context.liveLocationManager?.pollOnce()
                    }
                })
            })
            setPresentationCall = { call in
                notificationManager.setNotificationCall(call, strings: sharedContext.currentPresentationData.with({ $0 }).strings)
            }
            let liveLocationPolling = self.context.get()
            |> mapToSignal { context -> Signal<AccountRecordId?, NoError> in
                if let context = context, let liveLocationManager = context.context.liveLocationManager {
                    let accountId = context.context.account.id
                    return combineLatest(queue: .mainQueue(),
                        liveLocationManager.isPolling,
                        liveLocationManager.hasBackgroundTasks
                    )
                    |> map { isPolling, hasBackgroundTasks -> Bool in
                        return isPolling || hasBackgroundTasks
                    }
                    |> distinctUntilChanged
                    |> map { value -> AccountRecordId? in
                        if value {
                            return accountId
                        } else {
                            return nil
                        }
                    }
                } else {
                    return .single(nil)
                }
            }
            let watchTasks = self.context.get()
            |> mapToSignal { context -> Signal<AccountRecordId?, NoError> in
                if let context = context, let watchManager = context.context.watchManager {
                    let accountId = context.context.account.id
                    let runningTasks: Signal<WatchRunningTasks?, NoError> = .single(nil)
                    |> then(watchManager.runningTasks)
                    return runningTasks
                    |> distinctUntilChanged
                    |> map { value -> AccountRecordId? in
                        if let value = value, value.running {
                            return accountId
                        } else {
                            return nil
                        }
                    }
                    |> distinctUntilChanged
                } else {
                    return .single(nil)
                }
            }
            let wakeupManager = SharedWakeupManager(beginBackgroundTask: { name, expiration in
                let id = application.beginBackgroundTask(withName: name, expirationHandler: expiration)
                Logger.shared.log("App \(self.episodeId)", "Begin background task \(name): \(id)")
                print("App \(self.episodeId)", "Begin background task \(name): \(id)")
                return id
            }, endBackgroundTask: { id in
                print("App \(self.episodeId)", "End background task \(id)")
                Logger.shared.log("App \(self.episodeId)", "End background task \(id)")
                application.endBackgroundTask(id)
            }, backgroundTimeRemaining: { application.backgroundTimeRemaining }, acquireIdleExtension: {
                return applicationBindings.pushIdleTimerExtension()
            }, activeAccounts: sharedContext.activeAccountContexts |> map { ($0.0?.account, $0.1.map { ($0.0, $0.1.account) } + $0.inactiveAccounts.map { ($0.0, $0.1.account) }) }, liveLocationPolling: liveLocationPolling, watchTasks: watchTasks, inForeground: applicationBindings.applicationInForeground, hasActiveAudioSession: self.hasActiveAudioSession.get(), notificationManager: notificationManager, mediaManager: sharedContext.mediaManager, callManager: sharedContext.callManager, accountUserInterfaceInUse: { id in
                return sharedContext.accountUserInterfaceInUse(id)
            })
            let sharedApplicationContext = SharedApplicationContext(sharedContext: sharedContext, notificationManager: notificationManager, wakeupManager: wakeupManager)
            sharedApplicationContext.sharedContext.mediaManager.overlayMediaManager.attachOverlayMediaController(sharedApplicationContext.overlayMediaController)
            
            return accountManager.transaction { transaction -> (SharedApplicationContext, LoggingSettings) in
                return (sharedApplicationContext, transaction.getSharedData(SharedDataKeys.loggingSettings)?.get(LoggingSettings.self) ?? LoggingSettings.defaultSettings)
            }
        }
        self.sharedContextPromise.set(sharedContextSignal
        |> mapToSignal { sharedApplicationContext, loggingSettings -> Signal<SharedApplicationContext, NoError> in
            Logger.shared.logToFile = loggingSettings.logToFile
            Logger.shared.logToConsole = loggingSettings.logToConsole
            Logger.shared.redactSensitiveData = loggingSettings.redactSensitiveData
            
            return .single(sharedApplicationContext)
        })
        
        let watchManagerArgumentsPromise = Promise<WatchManagerArguments?>()
            
        self.context.set(self.sharedContextPromise.get()
        |> deliverOnMainQueue
        |> mapToSignal { sharedApplicationContext -> Signal<AuthorizedApplicationContext?, NoError> in
            return sharedApplicationContext.sharedContext.activeAccountContexts
            |> map { primary, _, _, _ -> AccountContext? in
                return primary
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs !== rhs {
                    return false
                }
                return true
            })
            |> mapToSignal { context -> Signal<(AccountContext, CallListSettings)?, NoError> in
                return sharedApplicationContext.sharedContext.accountManager.transaction { transaction -> CallListSettings? in
                    return transaction.getSharedData(ApplicationSpecificSharedDataKeys.callListSettings)?.get(CallListSettings.self)
                }
                |> reduceLeft(value: nil) { current, updated -> CallListSettings? in
                    var result: CallListSettings?
                    if let updated = updated {
                        result = updated
                    } else if let current = current {
                        result = current
                    }
                    return result
                }
                |> map { callListSettings -> (AccountContext, CallListSettings)? in
                    if let context = context {
                        return (context, callListSettings ?? .defaultSettings)
                    } else {
                        return nil
                    }
                }
            }
            |> deliverOnMainQueue
            |> map { accountAndSettings -> AuthorizedApplicationContext? in
                return accountAndSettings.flatMap { context, callListSettings in
                    return AuthorizedApplicationContext(sharedApplicationContext: sharedApplicationContext, mainWindow: self.mainWindow, watchManagerArguments: watchManagerArgumentsPromise.get(), context: context as! AccountContextImpl, accountManager: sharedApplicationContext.sharedContext.accountManager, showCallsTab: callListSettings.showTab, reinitializedNotificationSettings: {
                        let _ = (self.context.get()
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { context in
                            if let context = context {
                                self.registerForNotifications(context: context.context, authorize: false)
                            }
                        })
                    })
                }
            }
        })
        
        self.authContext.set(self.sharedContextPromise.get()
        |> deliverOnMainQueue
        |> mapToSignal { sharedApplicationContext -> Signal<UnauthorizedApplicationContext?, NoError> in
            return sharedApplicationContext.sharedContext.activeAccountContexts
            |> map { primary, accounts, auth, _ -> (AccountContext?, UnauthorizedAccount, [AccountContext])? in
                if let auth = auth {
                    return (primary, auth, Array(accounts.map({ $0.1 })))
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs?.1 !== rhs?.1 {
                    return false
                }
                return true
            })
            |> mapToSignal { authAndAccounts -> Signal<(UnauthorizedAccount, ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]))?, NoError> in
                if let (primary, auth, accounts) = authAndAccounts {
                    let phoneNumbers = combineLatest(accounts.map { context -> Signal<(AccountRecordId, String, Bool)?, NoError> in
                        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                        |> map { peer -> (AccountRecordId, String, Bool)? in
                            if case let .user(user) = peer, let phone = user.phone {
                                return (context.account.id, phone, context.account.testingEnvironment)
                            } else {
                                return nil
                            }
                        }
                    })
                    return phoneNumbers
                    |> map { phoneNumbers -> (UnauthorizedAccount, ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]))? in
                        var primaryNumber: (String, AccountRecordId, Bool)?
                        if let primary = primary {
                            for idAndNumber in phoneNumbers {
                                if let (id, number, testingEnvironment) = idAndNumber, id == primary.account.id {
                                    primaryNumber = (number, id, testingEnvironment)
                                    break
                                }
                            }
                        }
                        return (auth, (primaryNumber, phoneNumbers.compactMap({ $0.flatMap({ ($0.1, $0.0, $0.2) }) })))
                    }
                } else {
                    return .single(nil)
                }
            }
            |> deliverOnMainQueue
            |> map { accountAndSettings -> UnauthorizedApplicationContext? in
                return accountAndSettings.flatMap { account, otherAccountPhoneNumbers in
                    return UnauthorizedApplicationContext(apiId: buildConfig.apiId, apiHash: buildConfig.apiHash, sharedContext: sharedApplicationContext.sharedContext, account: account, otherAccountPhoneNumbers: otherAccountPhoneNumbers)
                }
            }
        })
        
        let contextReadyDisposable = MetaDisposable()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        self.contextDisposable.set((self.context.get()
        |> deliverOnMainQueue).start(next: { context in
            print("Application: context took \(CFAbsoluteTimeGetCurrent() - startTime) to become available")
            
            var network: Network?
            if let context = context {
                network = context.context.account.network
            }
            
            Logger.shared.log("App \(self.episodeId)", "received context \(String(describing: context)) account \(String(describing: context?.context.account.id)) network \(String(describing: network))")
            
            let firstTime = self.contextValue == nil
            if let contextValue = self.contextValue {
                contextValue.passcodeController?.dismiss()
                contextValue.context.account.shouldExplicitelyKeepWorkerConnections.set(.single(false))
                contextValue.context.account.shouldKeepBackgroundDownloadConnections.set(.single(false))
            }
            self.contextValue = context
            if let context = context {
                setupLegacyComponents(context: context.context)
                let isReady = context.context.sharedContext.appLockContext.isScreenCovered ? .single(true) : context.isReady.get()
                contextReadyDisposable.set((isReady
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { _ in
                    let readyTime = CFAbsoluteTimeGetCurrent() - startTime
                    if readyTime > 0.5 {
                        print("Application: context took \(readyTime) to become ready")
                    }
                    print("Launch to ready took \((CFAbsoluteTimeGetCurrent() - launchStartTime) * 1000.0) ms")

                    // if current account is added to non-activated secret passcode, it disappears immediately from UI
                    // to prevent secret passcode controller disappearing, we move it to new current account controllers
                    if let rootController = self.mainWindow.viewController as? TelegramRootController {
                        if (rootController.topViewController as? ItemListController)?.tag == "SecretPasscodeController" {
                            if let secretPasscodeController = rootController.popViewController(animated: false) {
                                context.rootController.pushViewController(secretPasscodeController, animated: false)
                            }
                        }
                    }
                    
                    self.mainWindow.debugAction = nil
                    if let previousViewController = self.mainWindow.viewController {
                        previousViewController.view.endEditingWithoutAnimation()
                    }
                    self.mainWindow.viewController = context.rootController
                    
                    context.isReadyAndPresented.set(context.isReady.get())
                    
                    if firstTime {
                        let layer = context.rootController.view.layer
                        layer.allowsGroupOpacity = true
                        layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak layer] _ in
                            if let layer = layer {
                                layer.allowsGroupOpacity = false
                            }
                        })
                    }
                    self.mainWindow.forEachViewController({ controller in
                        if let controller = controller as? TabBarAccountSwitchController {
                            if let rootController = self.mainWindow.viewController as? TelegramRootController {
                                if let tabsController = rootController.viewControllers.first as? TabBarController {
                                    for i in 0 ..< tabsController.controllers.count {
                                        if let _ = tabsController.controllers[i] as? (SettingsController & ViewController) {
                                            let sourceNodes = tabsController.sourceNodesForController(at: i)
                                            if let sourceNodes = sourceNodes {
                                                controller.dismiss(sourceNodes: sourceNodes)
                                            }
                                            return false
                                        }
                                    }
                                }
                            }
                        }
                        return true
                    })
                    self.mainWindow.topLevelOverlayControllers = [context.sharedApplicationContext.overlayMediaController, context.notificationController]
                    var authorizeNotifications = true
                    if #available(iOS 10.0, *) {
                        authorizeNotifications = false
                    }
                    self.registerForNotifications(context: context.context, authorize: authorizeNotifications)
                    
                    self.resetIntentsIfNeeded(context: context.context)
                }))
            } else {
                self.mainWindow.viewController = nil
                self.mainWindow.topLevelOverlayControllers = []
                contextReadyDisposable.set(nil)
            }
        }))
        
        let authContextReadyDisposable = MetaDisposable()
        
        self.authContextDisposable.set((self.authContext.get()
        |> deliverOnMainQueue).start(next: { context in
            var network: Network?
            if let context = context {
                network = context.account.network
            }
            
            Logger.shared.log("App \(self.episodeId)", "received auth context \(String(describing: context)) account \(String(describing: context?.account.id)) network \(String(describing: network))")
            
            if let authContextValue = self.authContextValue {
                authContextValue.account.shouldBeServiceTaskMaster.set(.single(.never))
                if authContextValue.authorizationCompleted {
                    let accountId = authContextValue.account.id
                    let _ = (self.context.get()
                    |> filter { context in
                        return context?.context.account.id == accountId
                    }
                    |> take(1)
                    |> timeout(4.0, queue: .mainQueue(), alternate: .complete())
                    |> deliverOnMainQueue).start(completed: {
                        Queue.mainQueue().after(0.75) {
                            authContextValue.rootController.view.endEditing(true)
                            authContextValue.rootController.dismiss()
                        }
                    })
                } else {
                    authContextValue.rootController.view.endEditing(true)
                    authContextValue.rootController.dismiss()
                }
            }
            self.authContextValue = context
            if let context = context {
                let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
                
                let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
                    let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                    self?.mainWindow.present(statusController, on: .root)
                    return ActionDisposable { [weak statusController] in
                        Queue.mainQueue().async() {
                            statusController?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.5, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.start()
                
                let isReady: Signal<Bool, NoError> = context.sharedContext.appLockContext.isScreenCovered ? .single(true) : context.isReady.get()
                authContextReadyDisposable.set((isReady
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { _ in
                    progressDisposable.dispose()
                    self.mainWindow.present(context.rootController, on: .root, completion: {
                        context.isReadyAndPresented.set(context.isReady.get())
                    })
                }))
            } else {
                authContextReadyDisposable.set(nil)
            }
        }))


        let logoutDataSignal: Signal<(AccountManager, Set<PeerId>), NoError> = self.sharedContextPromise.get()
        |> take(1)
        |> mapToSignal { sharedContext -> Signal<(AccountManager<TelegramAccountManagerTypes>, Set<PeerId>), NoError> in
            return sharedContext.sharedContext.activeAccountContexts
            |> map { _, accounts, _, _ -> Set<PeerId> in
                return Set(accounts.map { $0.1.account.peerId })
            }
            |> reduceLeft(value: Set<PeerId>()) { current, updated, emit in
                if !current.isEmpty {
                    emit(current.subtracting(current.intersection(updated)))
                }
                return updated
            }
            |> map { loggedOutAccountPeerIds -> (AccountManager<TelegramAccountManagerTypes>, Set<PeerId>) in
                return (sharedContext.sharedContext.accountManager, loggedOutAccountPeerIds)
            }
        }

        self.logoutDisposable.set(logoutDataSignal.start(next: { accountManager, loggedOutAccountPeerIds in
            let _ = (updateIntentsSettingsInteractively(accountManager: accountManager) { current in
                var updated = current
                for peerId in loggedOutAccountPeerIds {
                    deleteAllStoryDrafts(peerId: peerId)
                    if peerId == updated.account {
                        deleteAllSendMessageIntents()
                        updated = updated.withUpdatedAccount(nil)
                        break
                    }
                }
                return updated
            }).start()
        }))
        
        if buildConfig.isWatchEnabled {
            self.watchCommunicationManagerPromise.set(watchCommunicationManager(context: self.context.get() |> flatMap { WatchCommunicationManagerContext(context: $0.context) }, allowBackgroundTimeExtension: { timeout in
                let _ = (self.sharedContextPromise.get()
                |> take(1)).start(next: { sharedContext in
                    sharedContext.wakeupManager.allowBackgroundTimeExtension(timeout: timeout)
                })
            }))
        } else {
            self.watchCommunicationManagerPromise.set(.single(nil))
        }
        let _ = self.watchCommunicationManagerPromise.get().start(next: { manager in
            if let manager = manager {
                watchManagerArgumentsPromise.set(.single(manager.arguments))
            } else {
                watchManagerArgumentsPromise.set(.single(nil))
            }
        })
        
        self.resetBadge()
        
        if #available(iOS 9.1, *) {
            self.quickActionsDisposable.set((self.context.get()
            |> mapToSignal { context -> Signal<[ApplicationShortcutItem], NoError> in
                if let context = context {
                    let presentationData = context.context.sharedContext.currentPresentationData.with { $0 }
                    
                    return combineLatest(activeAccountsAndPeers(context: context.context) |> take(1), context.context.sharedContext.allHidableAccountIds, context.context.sharedContext.accountManager.accessChallengeData())
                    |> map { primaryAndAccounts, allHidableAccountIds, accessChallengeData -> (AccountContext, EnginePeer, Int32)? in
                        if accessChallengeData.data.isLockable {
                            return nil
                        }
                        return primaryAndAccounts.1.first { !allHidableAccountIds.contains($0.0.account.id) }
                    }
                    |> map { accountAndPeer -> String? in
                        if let (_, peer, _) = accountAndPeer {
                            return peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        } else {
                            return nil
                        }
                    } |> mapToSignal { otherAccountName -> Signal<[ApplicationShortcutItem], NoError> in
                        let presentationData = context.context.sharedContext.currentPresentationData.with { $0 }
                        return .single(applicationShortcutItems(strings: presentationData.strings, otherAccountName: otherAccountName))
                    }
                } else {
                    return .single([])
                }
            }
            |> distinctUntilChanged
            |> deliverOnMainQueue).start(next: { items in
                if items.isEmpty {
                    UIApplication.shared.shortcutItems = nil
                } else {
                    UIApplication.shared.shortcutItems = items.map({ $0.shortcutItem() })
                }
            }))
        }
        
        let _ = self.isInForegroundPromise.get().start(next: { value in
            Logger.shared.log("App \(self.episodeId)", "isInForeground = \(value)")
        })
        let _ = self.isActivePromise.get().start(next: { value in
            Logger.shared.log("App \(self.episodeId)", "isActive = \(value)")
        })
        
        if let url = launchOptions?[.url] {
            if let url = url as? URL, url.scheme == "tg" || url.scheme == buildConfig.appSpecificUrlScheme {
                self.openUrlWhenReady(url: url)
            } else if let urlString = url as? String, urlString.lowercased().hasPrefix("tg:") || urlString.lowercased().hasPrefix("\(buildConfig.appSpecificUrlScheme):"), let url = URL(string: urlString) {
                self.openUrlWhenReady(url: url)
            }
        }
        
        if application.applicationState == .active {
            self.isInForegroundValue = true
            self.isInForegroundPromise.set(true)
            self.isActiveValue = true
            self.isActivePromise.set(true)
            
            SharedDisplayLinkDriver.shared.updateForegroundState(self.isActiveValue)
            
            self.runForegroundTasks()
        }
        
        
        DeviceProximityManager.shared().proximityChanged = { [weak self] value in
            if let strongSelf = self {
                strongSelf.mainWindow.setProximityDimHidden(!value)
            }
        }
        
        if UIApplication.shared.isStatusBarHidden {
            UIApplication.shared.internalSetStatusBarHidden(false, animation: .none)
        }
        
        /*if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: baseAppBundleId + ".refresh", using: nil, launchHandler: { task in
                let _ = (self.sharedContextPromise.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { sharedApplicationContext in
                    
                    sharedApplicationContext.wakeupManager.replaceCurrentExtensionWithExternalTime(completion: {
                        task.setTaskCompleted(success: true)
                    }, timeout: 29.0)
                    let _ = (self.context.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { context in
                        guard let context = context else {
                            return
                        }
                        sharedApplicationContext.notificationManager.beginPollingState(account: context.context.account)
                    })
                })
            })
        }*/
        
        #if canImport(AppCenter)
        self.maybeCheckForUpdates()

        if !buildConfig.isAppStoreBuild, let appCenterId = buildConfig.appCenterId, !appCenterId.isEmpty {
            AppCenter.start(withAppSecret: buildConfig.appCenterId, services: [
                Crashes.self
            ])
        }
        #endif
        
        if #available(iOS 13.0, *) {
            let taskId = "\(baseAppBundleId).cleanup"
            
            var scheduleCleanupTask: (() -> Void)?
            
            BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: DispatchQueue.main) { task in
                Logger.shared.log("App \(self.episodeId)", "Executing cleanup task")
                
                let disposable = MetaDisposable()
                
                let _ = (self.sharedContextPromise.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { sharedApplicationContext in
                    // ensure wakeupManager does not suspend postbox transactions by calling postbox.setCanBeginTransactions(false)
                    sharedApplicationContext.wakeupManager.bgTaskSchedulerTaskBegan(taskId)
                    
                    disposable.set(self.runCacheReindexTasks(lowImpact: false, completion: {
                        Logger.shared.log("App \(self.episodeId)", "Completed cleanup task")
                        sharedApplicationContext.wakeupManager.bgTaskSchedulerTaskEnded(taskId)
                        task.setTaskCompleted(success: true)
                        scheduleCleanupTask?()
                    }))
                })
                
                task.expirationHandler = {
                    Logger.shared.log("App \(self.episodeId)", "Cleanup task expired")
                    disposable.dispose()
                    
                    let _ = (self.sharedContextPromise.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { sharedApplicationContext in
                        sharedApplicationContext.wakeupManager.bgTaskSchedulerTaskEnded(taskId)
                        task.setTaskCompleted(success: false)
                        scheduleCleanupTask?()
                    })
                }
            }
            
            scheduleCleanupTask = {
                BGTaskScheduler.shared.getPendingTaskRequests(completionHandler: { tasks in
                    if tasks.contains(where: { $0.identifier == taskId }) {
                        Logger.shared.log("App \(self.episodeId)", "Already have a cleanup task pending")
                        return
                    }
                    let request = BGProcessingTaskRequest(identifier: taskId)
                    request.requiresExternalPower = true
                    request.requiresNetworkConnectivity = false
                    
                    let timestamp = Int(CFAbsoluteTimeGetCurrent())
                    let minInterval = 18 * 60 * 60
                    if let indexTimestamp = UserDefaults.standard.object(forKey: "TelegramCacheIndexTimestamp") as? NSNumber, indexTimestamp.intValue >= timestamp - minInterval {
                        request.earliestBeginDate = Date(timeIntervalSinceNow: Double(min(minInterval, indexTimestamp.intValue - (timestamp - minInterval))))
                    }
                    
                    do {
                        try BGTaskScheduler.shared.submit(request)
                    } catch let e {
                        Logger.shared.log("App \(self.episodeId)", "Error submitting background task request: \(e)")
                    }
                })
            }
            
            scheduleCleanupTask?()
        }
        
        let reindexCacheOnce = Signal<Never, NoError> { subscriber in
            let timestamp = Int(CFAbsoluteTimeGetCurrent())
            let minReindexTimestamp = timestamp - 3 * 24 * 60 * 60
            if let indexTimestamp = UserDefaults.standard.object(forKey: "TelegramCacheIndexTimestamp") as? NSNumber, indexTimestamp.intValue >= minReindexTimestamp, indexTimestamp.intValue < timestamp + 24 * 60 * 60 {
                subscriber.putCompletion()
                return EmptyDisposable
            } else {
                Logger.shared.log("App \(self.episodeId)", "Executing low-impact cache reindex in foreground")
                return self.runCacheReindexTasks(lowImpact: true, completion: {
                    Logger.shared.log("App \(self.episodeId)", "Executing low-impact cache reindex in foreground — done")
                    subscriber.putCompletion()
                })
            }
        }
        
        let reindexCacheFirstTime = reindexCacheOnce
        |> delay(20.0, queue: Queue.concurrentDefaultQueue())
        let reindexCacheRepeatedly = (
            reindexCacheOnce
            |> suspendAwareDelay(24.0 * 60.0 * 60.0, granularity: 10.0, queue: Queue.concurrentDefaultQueue())
        )
        |> restart
        let reindexCache = reindexCacheFirstTime
        |> then(reindexCacheRepeatedly)
        
        self.reindexCacheDisposable = reindexCache.start()
        
        if #available(iOS 12.0, *) {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        let _ = self.urlSession(identifier: "\(baseAppBundleId).backroundSession")
        
        if let appGroupUserDefaults = UserDefaults(suiteName: appGroupName) {
            appGroupUserDefaults.removeObject(forKey: "suppressedNotificationForAccounId")
            
            var suppressedNotificationForAccounIdObserver: NSKeyValueObservation?
            
            let _ = self.isInForegroundPromise.get().start(next: { isInForeground in
                if isInForeground {
                    // using UserDefaults KVO to be notified by Notification Service Extension about suppressed notifications in hidable accounts and secret chats
                    // this allows to react to a call or new message for non-current account
                    suppressedNotificationForAccounIdObserver = appGroupUserDefaults.observe(\.suppressedNotificationForAccounId, options: [.new], changeHandler: { _, change in
                        if let accountIdString = (change.newValue as? String)?.components(separatedBy: ":").first, let rawAccountId = Int64(accountIdString) {
                            self.checkIncomingCallAndRefreshUnreadCountOfNonCurrentAccounts([AccountRecordId(rawValue: rawAccountId)])
                            // remove traces
                            appGroupUserDefaults.removeObject(forKey: "suppressedNotificationForAccounId")
                        }
                    })
                    
                    let _ = (self.sharedContextPromise.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { sharedApplicationContext in
                        if sharedApplicationContext.sharedContext.currentInAppNotificationSettings.with({ $0.displayNotificationsFromAllAccounts }) {
                            Queue.mainQueue().after(0.5) {
                                // handle calls or new messages while app was not running or in background for non-current accounts (both hidable and normal)
                                // for hidable accounts all notifications are unregistered when app is in background
                                // this also updates badge counter in case of new messages in hidable secret chat in normal non-current account
                                // even for normal non-current accounts if iOS Call Integration is disabled and new call comes, or if new message comes, when app is in background, if we do not tap notification but just open app, this will show incoming call window or update badge counter on Settings tab
                                self.checkIncomingCallAndRefreshUnreadCountOfNonCurrentAccounts(nil)
                            }
                        }
                    })
                } else {
                    suppressedNotificationForAccounIdObserver?.invalidate()
                    suppressedNotificationForAccounIdObserver = nil
                }
            })
        }
        
        // handle incoming calls and update unread counter badge right after previously hidden account is revealed
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            var lastInactiveAccountIds = Set<AccountRecordId>()
            
            let _ = (sharedApplicationContext.sharedContext.activeAccountContexts
            |> deliverOnMainQueue).start(next: { activeAccounts in
                let inactiveAccountsIds = Set(activeAccounts.inactiveAccounts.map({ $0.0 }))
                let newlyRevealedAccountIds = lastInactiveAccountIds.subtracting(inactiveAccountsIds)
                lastInactiveAccountIds = inactiveAccountsIds
                
                if !newlyRevealedAccountIds.isEmpty && sharedApplicationContext.sharedContext.currentInAppNotificationSettings.with({ $0.displayNotificationsFromAllAccounts }) {
                    self.checkIncomingCallAndRefreshUnreadCountOfNonCurrentAccounts(newlyRevealedAccountIds)
                }
            })
        })
        
        // exclude from backup folders that may reveal hidden secrets
        let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        excludePathFromBackup(libraryPath + "/Cookies")
        excludePathFromBackup(libraryPath + "/WebKit")
        
        Queue.concurrentBackgroundQueue().async { [weak self] in
            let _ = self?.cleanTmpFolderRecursively(path: NSTemporaryDirectory())
        }
        
        return true
    }
    
    private func cleanTmpFolderRecursively(path: String) -> Bool {
        var folderIsEmpty = true
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey], options: []) {
            for url in contents {
                var createdRecently = true
                if let creationDate = (try? url.resourceValues(forKeys: Set([.creationDateKey])))?.creationDate {
                    if creationDate < Date(timeIntervalSinceNow: -24.0 * 60.0 * 60.0) {
                        createdRecently = false
                    }
                }
                
                if (try? url.resourceValues(forKeys: Set([.isDirectoryKey])))?.isDirectory ?? false {
                    if cleanTmpFolderRecursively(path: url.path) && !createdRecently {
                        try? FileManager.default.removeItem(at: url)
                    } else {
                        folderIsEmpty = false
                    }
                } else {
                    if !createdRecently {
                        try? FileManager.default.removeItem(at: url)
                    } else {
                        folderIsEmpty = false
                    }
                }
            }
        }
        
        return folderIsEmpty
    }
    
    private var backgroundSessionSourceDataDisposables: [String: Disposable] = [:]
    private var backgroundUploadResultSubscribers: [String: Bag<(String?) -> Void>] = [:]
    
    func uploadInBackround(postbox: Postbox, resource: MediaResource) -> Signal<String?, NoError> {
        let baseAppBundleId = Bundle.main.bundleIdentifier!
        let session = self.urlSession(identifier: "\(baseAppBundleId).backroundSession")
        
        let signal = Signal<Never, NoError> { subscriber in
            let disposable = MetaDisposable()
            
            let _ = session.getAllTasks(completionHandler: { tasks in
                var alreadyExists = false
                for task in tasks {
                    if let originalRequest = task.originalRequest {
                        if let requestResourceId = originalRequest.value(forHTTPHeaderField: "tresource") {
                            if resource.id.stringRepresentation == requestResourceId {
                                alreadyExists = true
                                break
                            }
                        }
                    }
                }
                
                if !alreadyExists, self.backgroundSessionSourceDataDisposables[resource.id.stringRepresentation] == nil {
                    self.backgroundSessionSourceDataDisposables[resource.id.stringRepresentation] = (Signal<Never, NoError> { subscriber in
                        let dataDisposable = (postbox.mediaBox.resourceData(resource)
                        |> deliverOnMainQueue).start(next: { data in
                            if data.complete {
                                self.addBackgroundUploadTask(id: resource.id.stringRepresentation, path: data.path)
                            }
                        })
                        let fetchDisposable = postbox.mediaBox.fetchedResource(resource, parameters: nil).start()
                        
                        return ActionDisposable {
                            dataDisposable.dispose()
                            fetchDisposable.dispose()
                        }
                    }).start()
                }
            })
            
            return disposable
        }
        |> runOn(.mainQueue())
        
        return Signal { subscriber in
            let bag: Bag<(String?) -> Void>
            if let current = self.backgroundUploadResultSubscribers[resource.id.stringRepresentation] {
                bag = current
            } else {
                bag = Bag()
                self.backgroundUploadResultSubscribers[resource.id.stringRepresentation] = bag
            }
            let index = bag.add { result in
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            
            let workDisposable = signal.start()
            
            return ActionDisposable {
                workDisposable.dispose()
                
                Queue.mainQueue().async {
                    if let bag = self.backgroundUploadResultSubscribers[resource.id.stringRepresentation] {
                        bag.remove(index)
                        if bag.isEmpty {
                            //TODO:cancel tasks
                        }
                    }
                }
            }
        }
        |> runOn(.mainQueue())
    }
    
    private func addBackgroundUploadTask(id: String, path: String) {
        let baseAppBundleId = Bundle.main.bundleIdentifier!
        let session = self.urlSession(identifier: "\(baseAppBundleId).backroundSession")
        
        let fileName = "upload-\(UInt32.random(in: 0 ... UInt32.max))"
        let uploadFilePath = NSTemporaryDirectory() + "/" + fileName
        guard let sourceFile = ManagedFile(queue: nil, path: uploadFilePath, mode: .readwrite) else {
            return
        }
        guard let inFile = ManagedFile(queue: nil, path: path, mode: .read) else {
            return
        }
        
        let boundary = UUID().uuidString
        
        var headerData = Data()
        headerData.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        headerData.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        headerData.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        
        var footerData = Data()
        footerData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        let _ = sourceFile.write(headerData)
        
        let bufferSize = 512 * 1024
        let buffer = malloc(bufferSize)!
        defer {
            free(buffer)
        }
        
        while true {
            let readBytes = inFile.read(buffer, bufferSize)
            if readBytes <= 0 {
                break
            } else {
                let _ = sourceFile.write(buffer, count: readBytes)
            }
        }
        
        let _ = sourceFile.write(footerData)
        
        sourceFile._unsafeClose()
        inFile._unsafeClose()
        
        var request = URLRequest(url: URL(string: "http://localhost:25478/upload?token=f9403fc5f537b4ab332d")!)
        request.httpMethod = "POST"
        
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(id, forHTTPHeaderField: "tresource")
        
        let task = session.uploadTask(with: request, fromFile: URL(fileURLWithPath: uploadFilePath))
        task.resume()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let response = task.response as? HTTPURLResponse {
            if let originalRequest = task.originalRequest {
                if let requestResourceId = originalRequest.value(forHTTPHeaderField: "tresource") {
                    if let bag = self.backgroundUploadResultSubscribers[requestResourceId] {
                        for item in bag.copyItems() {
                            item("http server: \(response.allHeaderFields)")
                        }
                    }
                }
            }
        }
    }
    
    private func runCacheReindexTasks(lowImpact: Bool, completion: @escaping () -> Void) -> Disposable {
        let disposable = MetaDisposable()
        
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            let _ = (sharedApplicationContext.sharedContext.activeAccountContexts
            |> take(1)
            |> deliverOnMainQueue).start(next: { activeAccounts in
                var signals: Signal<Never, NoError> = .complete()
                
                for (_, context, _) in activeAccounts.accounts + activeAccounts.inactiveAccounts {
                    signals = signals |> then(context.account.cleanupTasks(lowImpact: lowImpact))
                }
                
                signals = signals |> then (
                    sharedApplicationContext.sharedContext.accountManager.optimizeAllStorages(minFreePagesFraction: 0.2)
                    |> (lowImpact ? runOn(.concurrentBackgroundQueue()) : identity)
                )
                
                // not touching inactive accounts
                for (_, context, _) in activeAccounts.accounts {
                    signals = signals |> then (
                        context.account.optimizeAllStorages(minFreePagesFraction: 0.2)
                        |> (lowImpact ? runOn(.concurrentBackgroundQueue()) : identity)
                    )
                }
                
                disposable.set(signals.start(completed: {
                    let timestamp = Int(CFAbsoluteTimeGetCurrent())
                    UserDefaults.standard.set(timestamp as NSNumber, forKey: "TelegramCacheIndexTimestamp")
                    completion()
                }))
            })
        })
        
        return disposable
    }

    private func resetBadge() {
        var resetOnce = true
        self.badgeDisposable.set((self.context.get()
        |> mapToSignal { context -> Signal<Int32, NoError> in
            if let context = context {
                return context.applicationBadge
            } else {
                return .single(0)
            }
        }
        |> deliverOnMainQueue).start(next: { count in
            if resetOnce {
                resetOnce = false
                if count == 0 {
                    UIApplication.shared.applicationIconBadgeNumber = 1
                }
            }
            UIApplication.shared.applicationIconBadgeNumber = Int(count)
        }))
    }

    private var lastResignActiveUptime: Int32?
    
    func applicationWillResignActive(_ application: UIApplication) {
        self.isActiveValue = false
        self.isActivePromise.set(false)
        self.clearNotificationsManager?.commitNow()
        
        if let navigationController = self.mainWindow.viewController as? NavigationController {
            for controller in navigationController.viewControllers {
                if let controller = controller as? TabBarController {
                    for subController in controller.controllers {
                        subController.forEachController { controller in
                            if let controller = controller as? UndoOverlayController {
                                controller.dismissWithCommitAction()
                            }
                            return true
                        }
                    }
                }
            }
        }
        self.mainWindow.forEachViewController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
        
        self.lastResignActiveUptime = getDeviceUptimeSeconds(nil)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            var extendNow = false
            if #available(iOS 9.0, *) {
                if !ProcessInfo.processInfo.isLowPowerModeEnabled {
                    extendNow = true
                }
            }
            if !sharedApplicationContext.sharedContext.energyUsageSettings.extendBackgroundWork {
                extendNow = false
            }
            sharedApplicationContext.wakeupManager.allowBackgroundTimeExtension(timeout: 2.0, extendNow: extendNow)
        })
        
        self.isInForegroundValue = false
        self.isInForegroundPromise.set(false)
        self.isActiveValue = false
        self.isActivePromise.set(false)
        
        var taskId: UIBackgroundTaskIdentifier?
        taskId = application.beginBackgroundTask(withName: "lock", expirationHandler: {
            if let taskId = taskId {
                UIApplication.shared.endBackgroundTask(taskId)
            }
        })
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5.0, execute: {
            if let taskId = taskId {
                UIApplication.shared.endBackgroundTask(taskId)
            }
        })
        
        self.mainWindow.dismissSensitiveViewControllers()
        self.lastResignActiveUptime = nil
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        if self.isActiveValue {
            self.isInForegroundValue = true
            self.isInForegroundPromise.set(true)
        } else {
            if #available(iOSApplicationExtension 12.0, *) {
                DispatchQueue.main.async {
                    self.isInForegroundValue = true
                    self.isInForegroundPromise.set(true)
                }
            }
        }
        
        // since we may need to quickly hide some secrets, delay these tasks for 0.5 seconds
        Queue.mainQueue().after(0.5, {
            self.runForegroundTasks()
        })
        
        SharedDisplayLinkDriver.shared.updateForegroundState(self.isActiveValue)
    }
    
    func runForegroundTasks() {
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            let _ = (sharedApplicationContext.sharedContext.activeAccountContexts
             |> take(1)
             |> deliverOnMainQueue).start(next: { activeAccounts in
                for (_, context, _) in activeAccounts.accounts {
                    (context.downloadedMediaStoreManager as? DownloadedMediaStoreManagerImpl)?.runTasks()
                }
            })
        })
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        if let lastResignActiveUptime = self.lastResignActiveUptime, getDeviceUptimeSeconds(nil) - lastResignActiveUptime >= 10 {
            self.mainWindow.dismissSensitiveViewControllers()
        }
        
        self.isInForegroundValue = true
        self.isInForegroundPromise.set(true)
        self.isActiveValue = true
        self.isActivePromise.set(true)

        // this is not needed, badge is already updated when needed
//        self.resetBadge()
        
        #if canImport(AppCenter)
        self.maybeCheckForUpdates()
        #endif
        
        SharedDisplayLinkDriver.shared.updateForegroundState(self.isActiveValue)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        Logger.shared.log("App \(self.episodeId)", "terminating")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Logger.shared.log("App \(self.episodeId)", "register for notifications: didRegisterForRemoteNotificationsWithDeviceToken (deviceToken: \(hexString(deviceToken)))")
        self.notificationTokenPromise.set(.single(deviceToken))
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.shared.log("App \(self.episodeId)", "register for notifications: didFailToRegisterForRemoteNotificationsWithError (error: \(error))")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            sharedApplicationContext.wakeupManager.allowBackgroundTimeExtension(timeout: 2.0)
        })
        
        var redactedPayload = userInfo
        if var aps = redactedPayload["aps"] as? [AnyHashable: Any] {
            if Logger.shared.redactSensitiveData {
                if aps["alert"] != nil {
                    aps["alert"] = "[[redacted]]"
                }
                if aps["body"] != nil {
                    aps["body"] = "[[redacted]]"
                }
            }
            redactedPayload["aps"] = aps
        }
        
        Logger.shared.log("App \(self.episodeId)", "remoteNotification: \(redactedPayload)")
        
        if let firebaseAuth = redactedPayload["com.google.firebase.auth"] as? String {
            guard let firebaseAuthData = firebaseAuth.data(using: .utf8), let firebaseJson = try? JSONSerialization.jsonObject(with: firebaseAuthData) else {
                completionHandler(.newData)
                return
            }
            guard let firebaseDict = firebaseJson as? [String: Any] else {
                completionHandler(.newData)
                return
            }
            
            if let receipt = firebaseDict["receipt"] as? String, let secret = firebaseDict["secret"] as? String {
                var firebaseSecrets = self.firebaseSecrets
                firebaseSecrets[receipt] = secret
                self.firebaseSecrets = firebaseSecrets
            }
            
            completionHandler(.newData)
            return
        }

        if userInfo["p"] == nil {
            completionHandler(.noData)
            return
        }
        
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            sharedApplicationContext.wakeupManager.replaceCurrentExtensionWithExternalTime(completion: {
                completionHandler(.newData)
            }, timeout: 29.0)
            sharedApplicationContext.notificationManager.addNotification(userInfo)
        })
    }
    
    /*func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        if (application.applicationState == .inactive) {
            Logger.shared.log("App \(self.episodeId)", "tap local notification \(String(describing: notification.userInfo)), applicationState \(application.applicationState)")
        }
    }*/

    public func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        if #available(iOS 9.0, *) {
            if case PKPushType.voIP = type {
                Logger.shared.log("App \(self.episodeId)", "pushRegistry credentials: \(credentials.token as NSData)")
                
                self.voipTokenPromise.set(.single(credentials.token))
            }
        }
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        Logger.shared.log("App \(self.episodeId) PushRegistry", "pushRegistry didReceiveIncomingPushWith \(payload.dictionaryPayload)")
        
        self.pushRegistryImpl(registry, didReceiveIncomingPushWith: payload, for: type, completion: completion)
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        Logger.shared.log("App \(self.episodeId) PushRegistry", "pushRegistry didReceiveIncomingPushWith \(payload.dictionaryPayload)")
        
        self.pushRegistryImpl(registry, didReceiveIncomingPushWith: payload, for: type, completion: {})
    }
    
    private func pushRegistryImpl(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        Logger.shared.log("App \(self.episodeId) PushRegistry", "pushRegistry processing push notification")
        
        let decryptedPayloadAndAccountId: ([AnyHashable: Any], AccountRecordId)?
        
        if let accountIdString = payload.dictionaryPayload["accountId"] as? String, let accountId = Int64(accountIdString) {
            decryptedPayloadAndAccountId = (payload.dictionaryPayload, AccountRecordId(rawValue: accountId))
        } else {
            guard var encryptedPayload = payload.dictionaryPayload["p"] as? String else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "encryptedPayload is nil")
                completion()
                return
            }
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "-", with: "+")
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "_", with: "/")
            while encryptedPayload.count % 4 != 0 {
                encryptedPayload.append("=")
            }
            guard let payloadData = Data(base64Encoded: encryptedPayload) else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't decode encryptedPayload")
                completion()
                return
            }
            guard let keyId = notificationPayloadKeyId(data: payloadData) else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't parse payload key id")
                completion()
                return
            }
            guard let accountManagerState = self.accountManagerState else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "accountManagerState is nil")
                completion()
                return
            }

            var maybeAccountId: AccountRecordId?
            var maybeNotificationKey: MasterNotificationKey?

            for key in accountManagerState.notificationKeys {
                if key.id == keyId {
                    maybeAccountId = key.accountId
                    maybeNotificationKey = MasterNotificationKey(id: key.id, data: key.key)
                    break
                }
            }

            guard let accountId = maybeAccountId, let notificationKey = maybeNotificationKey else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "accountId or notificationKey is nil")
                completion()
                return
            }
            guard let decryptedPayload = decryptedNotificationPayload(key: notificationKey, data: payloadData) else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't decrypt payload")
                completion()
                return
            }
            guard let payloadJson = try? JSONSerialization.jsonObject(with: decryptedPayload, options: []) as? [AnyHashable: Any] else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't decode payload json")
                completion()
                return
            }
            
            decryptedPayloadAndAccountId = (payloadJson, accountId)
        }
        
        guard let (payloadJson, accountId) = decryptedPayloadAndAccountId else {
            Logger.shared.log("App \(self.episodeId) PushRegistry", "decryptedPayloadAndAccountId is nil")
            completion()
            return
        }
        
        if !Logger.shared.redactSensitiveData {
            Logger.shared.log("App \(self.episodeId) PushRegistry", "decrypted payload: \(payloadJson)")
        }
        
        guard var updateString = payloadJson["updates"] as? String else {
            Logger.shared.log("App \(self.episodeId) PushRegistry", "updates is nil")
            completion()
            return
        }

        updateString = updateString.replacingOccurrences(of: "-", with: "+")
        updateString = updateString.replacingOccurrences(of: "_", with: "/")
        while updateString.count % 4 != 0 {
            updateString.append("=")
        }
        guard let updateData = Data(base64Encoded: updateString) else {
            Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't decode updateData")
            completion()
            return
        }
        guard let callUpdate = AccountStateManager.extractIncomingCallUpdate(data: updateData) else {
            Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't extract call update")
            completion()
            return
        }
        
        let useCallKitIntegration: Signal<Bool, NoError>
        if #available(iOS 13.0, *) {
            useCallKitIntegration = .single(true)
        } else {
            useCallKitIntegration = self.sharedContextPromise.get()
            |> mapToSignal { sharedApplicationContext in
                return sharedApplicationContext.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.voiceCallSettings])
            }
            |> map { sharedData in
                let voiceCallSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings]?.get(VoiceCallSettings.self) ?? .defaultSettings
                return voiceCallSettings.enableSystemIntegration
            }
        }
        
        let _ = (combineLatest(self.sharedContextPromise.get(), useCallKitIntegration)
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext, useCallKitIntegration in
            guard useCallKitIntegration else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "CallKitIntegration is disabled")
                if #available(iOS 13.0, *) {
                    assertionFailure()
                } else {
                    // On iOS before 13, telegram servers do not send regular push notification for incoming calls when call integration is disabled?! But they send voip-push, even when integration is disabled.
                    self.checkIncomingCallAndRefreshUnreadCountOfNonCurrentAccounts([accountId])
                }
                completion()
                return
            }
            
            guard let callKitIntegration = CallKitIntegration.shared else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "CallKitIntegration is not available")
                completion()
                return
            }
            
            let phoneNumber = payloadJson["phoneNumber"] as? String

            callKitIntegration.reportIncomingCall(
                uuid: CallSessionManager.getStableIncomingUUID(stableId: callUpdate.callId),
                stableId: callUpdate.callId,
                handle: "\(callUpdate.peer.id.id._internalGetInt64Value())",
                phoneNumber: phoneNumber.flatMap(formatPhoneNumber),
                isVideo: false,
                displayTitle: callUpdate.peer.debugDisplayTitle,
                completion: { error in
                    if let error = error {
                        if error.domain == "com.apple.CallKit.error.incomingcall" && (error.code == -3 || error.code == 3) {
                            Logger.shared.log("PresentationCall", "reportIncomingCall device in DND mode")
                        } else {
                            Logger.shared.log("PresentationCall", "reportIncomingCall error \(error)")
                            /*Queue.mainQueue().async {
                                if let strongSelf = self {
                                    strongSelf.callSessionManager.drop(internalId: strongSelf.internalId, reason: .hangUp, debugLog: .single(nil))
                                }
                            }*/
                        }
                    }
                }
            )
            
            let _ = (sharedApplicationContext.sharedContext.activeAccountContexts
            |> take(1)
            |> deliverOnMainQueue).start(next: { activeAccounts in
                var processed = false
                for (_, context, _) in activeAccounts.accounts {
                    if context.account.id == accountId {
                        context.account.stateManager.processIncomingCallUpdate(data: updateData, completion: { _ in
                        })
                        
                        //callUpdate.callId
                        let disposable = MetaDisposable()
                        self.watchedCallsDisposables.add(disposable)
                        
                        disposable.set((context.account.callSessionManager.callState(internalId: CallSessionManager.getStableIncomingUUID(stableId: callUpdate.callId))
                        |> deliverOnMainQueue).start(next: { state in
                            switch state.state {
                            case .terminated:
                                callKitIntegration.dropCall(uuid: CallSessionManager.getStableIncomingUUID(stableId: callUpdate.callId))
                            default:
                                break
                            }
                        }))
                        
                        processed = true
                        
                        break
                    }
                }
                
                if !processed {
                    callKitIntegration.dropCall(uuid: CallSessionManager.getStableIncomingUUID(stableId: callUpdate.callId))
                }
            })
            
            sharedApplicationContext.wakeupManager.allowBackgroundTimeExtension(timeout: 2.0)

            if case PKPushType.voIP = type {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "pushRegistry payload: \(payload.dictionaryPayload)")
                sharedApplicationContext.notificationManager.addNotification(payload.dictionaryPayload)
            }
            
            Logger.shared.log("App \(self.episodeId) PushRegistry", "Invoking completion handler")
            
            completion()
        })
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        Logger.shared.log("App \(self.episodeId)", "invalidated token for \(type)")
    }
    
    private func authorizedContext() -> Signal<AuthorizedApplicationContext, NoError> {
        return self.context.get()
        |> mapToSignal { context -> Signal<AuthorizedApplicationContext, NoError> in
            if let context = context {
                return .single(context)
            } else {
                return .complete()
            }
        }
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?) -> Bool {
        self.openUrl(url: url)
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        self.openUrl(url: url)
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        guard self.openUrlInProgress != url else {
            return true
        }
        
        self.openUrl(url: url)
        return true
    }
    
    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        self.openUrl(url: url)
        return true
    }
    
    private func openUrl(url: URL) {
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> delay(0.1, queue: Queue.mainQueue()) // allow possible secret passcodes deactivations to be applied
        |> mapToSignal { sharedApplicationContext -> Signal<(SharedAccountContextImpl, AuthorizedApplicationContext?, UnauthorizedApplicationContext?), NoError> in
            combineLatest(self.context.get(), self.authContext.get())
            |> filter { $0 != nil || $1 != nil }
            |> take(1)
            |> map { context, authContext -> (SharedAccountContextImpl, AuthorizedApplicationContext?, UnauthorizedApplicationContext?) in
                return (sharedApplicationContext.sharedContext, context, authContext)
            }
        }
        |> deliverOnMainQueue).start(next: { _, context, authContext in
            if let authContext = authContext, let confirmationCode = parseConfirmationCodeUrl(url) {
                authContext.rootController.applyConfirmationCode(confirmationCode)
            } else if let context = context {
                context.openUrl(url)
            } else if let authContext = authContext {
                if let proxyData = parseProxyUrl(url) {
                    authContext.rootController.view.endEditing(true)
                    let presentationData = authContext.sharedContext.currentPresentationData.with { $0 }
                    let controller = ProxyServerActionSheetController(presentationData: presentationData, accountManager: authContext.sharedContext.accountManager, postbox: authContext.account.postbox, network: authContext.account.network, server: proxyData, updatedPresentationData: nil)
                    authContext.rootController.currentWindow?.present(controller, on: PresentationSurfaceLevel.root, blockInteraction: false, completion: {})
                } else if let secureIdData = parseSecureIdUrl(url) {
                    let presentationData = authContext.sharedContext.currentPresentationData.with { $0 }
                    authContext.rootController.currentWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.Passport_NotLoggedInMessage, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Calls_NotNow, action: {
                        if let callbackUrl = URL(string: secureIdCallbackUrl(with: secureIdData.callbackUrl, peerId: secureIdData.peerId, result: .cancel, parameters: [:])) {
                            UIApplication.shared.open(callbackUrl, options: [:], completionHandler: nil)
                        }
                    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), on: .root, blockInteraction: false, completion: {})
                }
            }
        })
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if #available(iOS 10.0, *) {
            var startCallContacts: [INPerson]?
            var isVideo = false
            if let startCallIntent = userActivity.interaction?.intent as? SupportedStartCallIntent {
                startCallContacts = startCallIntent.contacts
                isVideo = false
            } else if let startCallIntent = userActivity.interaction?.intent as? SupportedStartVideoCallIntent {
                startCallContacts = startCallIntent.contacts
                isVideo = true
            }
            
            if let startCallContacts = startCallContacts {
                let startCall: (PeerId) -> Void = { peerId in
                    self.startCallWhenReady(accountId: nil, peerId: peerId, isVideo: isVideo)
                }
                
                func cleanPhoneNumber(_ text: String) -> String {
                    var result = ""
                    for c in text {
                        if c == "+" {
                            if result.isEmpty {
                                result += String(c)
                            }
                        } else if c >= "0" && c <= "9" {
                            result += String(c)
                        }
                    }
                    return result
                }
                
                func matchPhoneNumbers(_ lhs: String, _ rhs: String) -> Bool {
                    if lhs.count < 10 && lhs.count == rhs.count {
                        return lhs == rhs
                    } else if lhs.count >= 10 && rhs.count >= 10 && lhs.suffix(10) == rhs.suffix(10) {
                        return true
                    } else {
                        return false
                    }
                }
                
                if let contact = startCallContacts.first {
                    let _ = (self.sharedContextPromise.get()
                    |> take(1)
                    |> delay(0.1, queue: Queue.mainQueue()) // allow possible secret passcodes deactivations to be applied
                    |> deliverOnMainQueue).start(next: { _ in
                    
                    let contactByIdentifier: Signal<EnginePeer?, NoError>
                    if let context = self.contextValue?.context, let contactIdentifier = contact.contactIdentifier {
                        contactByIdentifier = context.engine.contacts.findPeerByLocalContactIdentifier(identifier: contactIdentifier)
                    } else {
                        contactByIdentifier = .single(nil)
                    }
                    
                    let _ = (contactByIdentifier |> deliverOnMainQueue).start(next: { peerByContact in
                        var processed = false
                        if let peerByContact = peerByContact {
                            startCall(peerByContact.id)
                            processed = true
                        } else if let handle = contact.customIdentifier, handle.hasPrefix("tg") {
                            let string = handle.suffix(from: handle.index(handle.startIndex, offsetBy: 2))
                            if let value = Int64(string) {
                                startCall(PeerId(value))
                                processed = true
                            }
                        }
                        if !processed, let handle = contact.personHandle, let value = handle.value {
                            switch handle.type {
                                case .unknown:
                                    if let value = Int64(value) {
                                        startCall(PeerId(value))
                                        processed = true
                                    }
                                case .phoneNumber:
                                    let phoneNumber = cleanPhoneNumber(value)
                                    if !phoneNumber.isEmpty {
                                        guard let context = self.contextValue?.context else {
                                            return
                                        }
                                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.List(includePresences: false))
                                        |> map { contactList -> PeerId? in
                                            var result: PeerId?
                                            for peer in contactList.peers {
                                                if case let .user(peer) = peer, let peerPhoneNumber = peer.phone {
                                                    if matchPhoneNumbers(phoneNumber, peerPhoneNumber) {
                                                        result = peer.id
                                                        break
                                                    }
                                                }
                                            }
                                            return result
                                        }
                                        |> deliverOnMainQueue).start(next: { peerId in
                                            if let peerId = peerId {
                                                startCall(peerId)
                                            }
                                        })
                                        processed = true
                                    }
                                default:
                                    break
                            }
                        }
                    })
                    
                    })
                    
                    return true
                }
            } else if let sendMessageIntent = userActivity.interaction?.intent as? INSendMessageIntent {
                if let contact = sendMessageIntent.recipients?.first, let handle = contact.customIdentifier, handle.hasPrefix("tg") {
                    let string = handle.suffix(from: handle.index(handle.startIndex, offsetBy: 2))
                    if let value = Int64(string) {
                        let _ = (self.sharedContextPromise.get()
                        |> take(1)
                        |> delay(0.1, queue: Queue.mainQueue()) // allow possible secret passcodes deactivations to be applied
                        |> deliverOnMainQueue).start(next: { _ in
                        
                        guard PeerId(value).namespace == Namespaces.Peer.CloudUser else {
                            return
                        }
                        
                        self.openChatWhenReady(accountId: nil, peerId: PeerId(value), threadId: nil, activateInput: true, storyId: nil)
                        
                        })
                    }
                }
            }
        }
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            self.openUrl(url: url)
        }
        
        if userActivity.activityType == CSSearchableItemActionType {
            if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String, uniqueIdentifier.hasPrefix("contact-") {
                if let peerIdValue = Int64(String(uniqueIdentifier[uniqueIdentifier.index(uniqueIdentifier.startIndex, offsetBy: "contact-".count)...])) {
                    let peerId = PeerId(peerIdValue)
                    guard peerId.namespace == Namespaces.Peer.CloudUser else {
                        return true
                    }
                
                    let signal = self.sharedContextPromise.get()
                    |> take(1)
                    |> delay(0.1, queue: Queue.mainQueue()) // allow possible secret passcodes deactivations to be applied
                    |> mapToSignal { sharedApplicationContext -> Signal<(AccountRecordId?, [AccountContext?]), NoError> in
                        return sharedApplicationContext.sharedContext.activeAccountContexts
                        |> take(1)
                        |> mapToSignal { primary, contexts, _, _ -> Signal<(AccountRecordId?, [AccountContext?]), NoError> in
                            return combineLatest(contexts.map { _, context, _ -> Signal<AccountContext?, NoError> in
                                return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                |> map { peer -> AccountContext? in
                                    if peer != nil {
                                        return context
                                    } else {
                                        return nil
                                    }
                                }
                            })
                            |> map { contexts -> (AccountRecordId?, [AccountContext?]) in
                                return (primary?.account.id, contexts)
                            }
                        }
                    }
                    let _ = (signal
                    |> deliverOnMainQueue).start(next: { primary, contexts in
                        if let primary = primary {
                            for context in contexts {
                                if let context = context, context.account.id == primary {
                                    self.openChatWhenReady(accountId: nil, peerId: peerId, threadId: nil, storyId: nil)
                                    return
                                }
                            }
                        }
                        
                        for context in contexts {
                            if let context = context {
                                self.openChatWhenReady(accountId: context.account.id, peerId: peerId, threadId: nil, storyId: nil)
                                return
                            }
                        }
                    })
                }
            }
        }
        
        return true
    }
    
    @available(iOS 9.0, *)
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedContext in
            let type = ApplicationShortcutItemType(rawValue: shortcutItem.type)
            let immediately = type == .hideAllSecrets
            let proceed: () -> Void = {
                let _ = (self.context.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { context in
                    if let context = context {
                        if let type = type {
                            switch type {
                                case .search:
                                    context.openRootSearch()
                                case .compose:
                                    context.openRootCompose()
                                case .camera:
                                    context.openRootCamera()
                                case .savedMessages:
                                    self.openChatWhenReady(accountId: nil, peerId: context.context.account.peerId, threadId: nil, storyId: nil)
                                case .account:
                                    context.switchAccount()
                                case .hideAllSecrets:
                                let _ = hideAllSecrets(accountManager: context.context.sharedContext.accountManager).start()
                            }
                        }
                    }
                })
            }
            if let appLockContext = sharedContext.sharedContext.appLockContext as? AppLockContextImpl, !immediately {
                let _ = (appLockContext.isCurrentlyLocked
                |> filter { !$0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { _ in
                    proceed()
                })
            } else {
                proceed()
            }
        })
    }
    
    private func openNotificationSettingsWhenReady() {
        let _ = (self.authorizedContext()
        |> take(1)
        |> delay(0.1, queue: Queue.mainQueue()) // allow possible secret passcodes deactivations to be applied
        |> deliverOnMainQueue).start(next: { context in
            context.openNotificationSettings()
        })
    }
    
    private func startCallWhenReady(accountId: AccountRecordId?, peerId: PeerId, isVideo: Bool) {
        let signal = self.sharedContextPromise.get()
        |> take(1)
        |> mapToSignal { sharedApplicationContext -> Signal<AuthorizedApplicationContext, NoError> in
            if let accountId = accountId {
                sharedApplicationContext.sharedContext.switchToAccount(id: accountId)
                return self.authorizedContext()
                |> filter { context in
                    context.context.account.id == accountId
                }
                |> take(1)
            } else {
                return self.authorizedContext()
                |> take(1)
            }
        }
        self.openChatWhenReadyDisposable.set((signal
        |> deliverOnMainQueue).start(next: { context in
            context.startCall(peerId: peerId, isVideo: isVideo)
        }))
    }
    
    private func openChatWhenReady(accountId: AccountRecordId?, peerId: PeerId, threadId: Int64?, messageId: MessageId? = nil, activateInput: Bool = false, storyId: StoryId?) {
        let signal = self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue
        |> mapToSignal { sharedApplicationContext -> Signal<AuthorizedApplicationContext, NoError> in
            if let accountId = accountId {
                sharedApplicationContext.sharedContext.switchToAccount(id: accountId)
                return self.authorizedContext()
                |> filter { context in
                    context.context.account.id == accountId
                }
                |> take(1)
            } else {
                return self.authorizedContext()
                |> take(1)
            }
        }
        self.openChatWhenReadyDisposable.set((signal
        |> deliverOnMainQueue).start(next: { context in
            context.openChatWithPeerId(peerId: peerId, threadId: threadId, messageId: messageId, activateInput: activateInput, storyId: storyId)
        }))
    }
    
    private var openUrlInProgress: URL?
    private func openUrlWhenReady(url: URL) {
        self.openUrlInProgress = url
        
        self.openUrlWhenReadyDisposable.set((self.authorizedContext()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] context in
            context.openUrl(url)
            
            Queue.mainQueue().after(1.0, {
                self?.openUrlInProgress = nil
            })
        }))
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let _ = (accountIdFromNotification(response.notification, sharedContext: self.sharedContextPromise.get())
        |> deliverOnMainQueue).start(next: { accountId in
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                // for incoming call to non-current account when iOS Call Integration is turned off, this will show incoming call window
                // (the app was in background when a call came in, so notification was shown. here we are handling a tap on this notification.)
                if response.notification.request.content.userInfo["call_id"] != nil, let accountId {
                    self.checkIncomingCallAndRefreshUnreadCountOfNonCurrentAccounts([accountId])
                } else if let (peerId, threadId) = peerIdFromNotification(response.notification) {
                    var messageId: MessageId? = nil
                    if response.notification.request.content.categoryIdentifier == "c" || response.notification.request.content.categoryIdentifier == "t" {
                        messageId = messageIdFromNotification(peerId: peerId, notification: response.notification)
                    }
                    let storyId = storyIdFromNotification(peerId: peerId, notification: response.notification)
                    self.openChatWhenReady(accountId: accountId, peerId: peerId, threadId: threadId, messageId: messageId, storyId: storyId)
                }
                completionHandler()
            } else if response.actionIdentifier == "reply", let (peerId, threadId) = peerIdFromNotification(response.notification), let accountId = accountId {
                guard let response = response as? UNTextInputNotificationResponse, !response.userText.isEmpty else {
                    completionHandler()
                    return
                }
                let text = response.userText
                let signal = self.sharedContextPromise.get()
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { sharedContext -> Signal<Void, NoError> in
                    sharedContext.wakeupManager.allowBackgroundTimeExtension(timeout: 2.0, extendNow: true)
                    return sharedContext.sharedContext.activeAccountContexts
                    |> mapToSignal { _, contexts, _, _ -> Signal<Account, NoError> in
                        for context in contexts {
                            if context.1.account.id == accountId {
                                return .single(context.1.account)
                            }
                        }
                        return .complete()
                    }
                    |> take(1)
                    |> deliverOnMainQueue
                    |> mapToSignal { account -> Signal<Void, NoError> in
                        if let messageId = messageIdFromNotification(peerId: peerId, notification: response.notification) {
                            let _ = TelegramEngine(account: account).messages.applyMaxReadIndexInteractively(index: MessageIndex(id: messageId, timestamp: 0)).start()
                        }
                        var replyToMessageId: MessageId?
                        if let threadId {
                            replyToMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId))
                        }
                        return enqueueMessages(account: account, peerId: peerId, messages: [EnqueueMessage.message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, replyToMessageId: replyToMessageId, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
                        |> map { messageIds -> MessageId? in
                            if messageIds.isEmpty {
                                return nil
                            } else {
                                return messageIds[0]
                            }
                        }
                        |> mapToSignal { messageId -> Signal<Void, NoError> in
                            if let messageId = messageId {
                                return account.postbox.unsentMessageIdsView()
                                |> filter { view in
                                    return !view.ids.contains(messageId)
                                }
                                |> take(1)
                                |> mapToSignal { _ -> Signal<Void, NoError> in
                                    return .complete()
                                }
                            } else {
                                return .complete()
                            }
                        }
                    }
                }
                |> deliverOnMainQueue
                
                let disposable = MetaDisposable()
                disposable.set((signal
                |> afterDisposed { [weak disposable] in
                    Queue.mainQueue().async {
                        if let disposable = disposable {
                            self.replyFromNotificationsDisposables.remove(disposable)
                        }
                        completionHandler()
                    }
                }).start())
                self.replyFromNotificationsDisposables.add(disposable)
            } else {
                completionHandler()
            }
        })
    }
    
    func requestNotificationTokenInvalidation() {
        UIApplication.shared.unregisterForRemoteNotifications()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
            UIApplication.shared.registerForRemoteNotifications()
        })
    }
    
    private func registerForNotifications(context: AccountContextImpl, authorize: Bool = true, completion: @escaping (Bool) -> Void = { _ in }) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let _ = (context.sharedContext.accountManager.transaction { transaction -> Bool in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.inAppNotificationSettings)?.get(InAppNotificationSettings.self) ?? InAppNotificationSettings.defaultSettings
            return settings.displayNameOnLockscreen
        }
        |> deliverOnMainQueue).start(next: { displayNames in
            self.registerForNotifications(replyString: presentationData.strings.Notification_Reply, messagePlaceholderString: presentationData.strings.Conversation_InputTextPlaceholder, hiddenContentString: presentationData.strings.Watch_MessageView_Title, hiddenReactionContentString: presentationData.strings.Notification_LockScreenReactionPlaceholder, hiddenStoryContentString: presentationData.strings.Notification_LockScreenStoryPlaceholder, includeNames: displayNames, authorize: authorize, completion: completion)
        })
    }

    private func registerForNotifications(replyString: String, messagePlaceholderString: String, hiddenContentString: String, hiddenReactionContentString: String, hiddenStoryContentString: String, includeNames: Bool, authorize: Bool = true, completion: @escaping (Bool) -> Void = { _ in }) {
        let notificationCenter = UNUserNotificationCenter.current()
        Logger.shared.log("App \(self.episodeId)", "register for notifications: get settings (authorize: \(authorize))")
        notificationCenter.getNotificationSettings(completionHandler: { settings in
            Logger.shared.log("App \(self.episodeId)", "register for notifications: received settings: \(settings.authorizationStatus)")
            
            switch (settings.authorizationStatus, authorize) {
                case (.authorized, _), (.notDetermined, true):
                    var authorizationOptions: UNAuthorizationOptions = [.badge, .sound, .alert, .carPlay]
                    if #available(iOS 12.0, *) {
                        authorizationOptions.insert(.providesAppNotificationSettings)
                    }
                    if #available(iOS 13.0, *) {
                        authorizationOptions.insert(.announcement)
                    }
                    Logger.shared.log("App \(self.episodeId)", "register for notifications: request authorization")
                    notificationCenter.requestAuthorization(options: authorizationOptions, completionHandler: { result, _ in
                        Logger.shared.log("App \(self.episodeId)", "register for notifications: received authorization: \(result)")
                        completion(result)
                        if result {
                            Queue.mainQueue().async {
                                let reply = UNTextInputNotificationAction(identifier: "reply", title: replyString, options: [], textInputButtonTitle: replyString, textInputPlaceholder: messagePlaceholderString)
                                                                    
                                let unknownMessageCategory: UNNotificationCategory
                                let repliableMessageCategory: UNNotificationCategory
                                let repliableMediaMessageCategory: UNNotificationCategory
                                let groupRepliableMessageCategory: UNNotificationCategory
                                let groupRepliableMediaMessageCategory: UNNotificationCategory
                                let channelMessageCategory: UNNotificationCategory
                                let reactionMessageCategory: UNNotificationCategory
                                let storyCategory: UNNotificationCategory
                                
                                var options: UNNotificationCategoryOptions = []
                                if includeNames {
                                    options.insert(.hiddenPreviewsShowTitle)
                                }
                                
                                var carPlayOptions = options
                                carPlayOptions.insert(.allowInCarPlay)
                                if #available(iOS 13.2, *) {
                                    carPlayOptions.insert(.allowAnnouncement)
                                }
                                
                                unknownMessageCategory = UNNotificationCategory(identifier: "unknown", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                repliableMessageCategory = UNNotificationCategory(identifier: "r", actions: [reply], intentIdentifiers: [INSearchForMessagesIntentIdentifier], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: carPlayOptions)
                                repliableMediaMessageCategory = UNNotificationCategory(identifier: "m", actions: [reply], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: carPlayOptions)
                                groupRepliableMessageCategory = UNNotificationCategory(identifier: "gr", actions: [reply], intentIdentifiers: [INSearchForMessagesIntentIdentifier], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                groupRepliableMediaMessageCategory = UNNotificationCategory(identifier: "gm", actions: [reply], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                channelMessageCategory = UNNotificationCategory(identifier: "c", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                reactionMessageCategory = UNNotificationCategory(identifier: "t", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenReactionContentString, options: options)
                                storyCategory = UNNotificationCategory(identifier: "st", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenStoryContentString, options: options)
                                
                                UNUserNotificationCenter.current().setNotificationCategories([
                                    unknownMessageCategory,
                                    repliableMessageCategory,
                                    repliableMediaMessageCategory,
                                    channelMessageCategory,
                                    reactionMessageCategory,
                                    groupRepliableMessageCategory,
                                    groupRepliableMediaMessageCategory,
                                    storyCategory
                                ])
                                
                                Logger.shared.log("App \(self.episodeId)", "register for notifications: invoke registerForRemoteNotifications")
                                UIApplication.shared.registerForRemoteNotifications()
                            }
                        }
                    })
                default:
                    break
            }
        })
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let _ = (accountIdFromNotification(notification, sharedContext: self.sharedContextPromise.get())
        |> deliverOnMainQueue).start(next: { accountId in
            if let context = self.contextValue {
                if let accountId = accountId, context.context.account.id != accountId {
                    // for incoming call to non-current account when iOS Call Integration is turned off, this will show incoming call window
                    // for message notification for non-current account this will update badge counter on Settings tab
                    self.checkIncomingCallAndRefreshUnreadCountOfNonCurrentAccounts([accountId])
                    if notification.request.content.userInfo["call_id"] != nil {
                        // if this is a call, no need to show notification
                        completionHandler([])
                    } else {
                        completionHandler([.alert])
                    }
                    return
                }
            }
            completionHandler([])
        })
    }
    
    @available(iOS 12.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        self.openNotificationSettingsWhenReady()
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        Logger.shared.log("App \(self.episodeId)", "handleEventsForBackgroundURLSession \(identifier)")
        completionHandler()
    }
    
    private func checkIncomingCallAndRefreshUnreadCountOfNonCurrentAccounts(_ accountIds: Set<AccountRecordId>?) {
        Logger.shared.log("App \(self.episodeId)", "checkIncomingCallAndRefreshUnreadCountOfNonCurrentAccounts: \(accountIds ?? [])")
        
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            let _ = (sharedApplicationContext.sharedContext.activeAccountContexts
            |> take(1)
            |> deliverOnMainQueue).start(next: { activeAccounts in
                for (_, context, _) in activeAccounts.accounts {
                    if context.account.id != activeAccounts.primary?.account.id && accountIds?.contains(context.account.id) ?? true {
                        sharedApplicationContext.notificationManager.beginPollingState(account: context.account)
                    }
                }
            })
        })
    }
    
    private var lastCheckForUpdatesTimestamp: Double?
    private let currentCheckForUpdatesDisposable = MetaDisposable()
    
    #if canImport(AppCenter)
    private func maybeCheckForUpdates() {
        #if targetEnvironment(simulator)
        #else
        guard let buildConfig = self.buildConfig, !buildConfig.isAppStoreBuild, let appCenterId = buildConfig.appCenterId, !appCenterId.isEmpty else {
            return
        }
        let timestamp = CFAbsoluteTimeGetCurrent()
        if self.lastCheckForUpdatesTimestamp == nil || self.lastCheckForUpdatesTimestamp! < timestamp - 10.0 * 60.0 {
            self.lastCheckForUpdatesTimestamp = timestamp
            
            if let url = URL(string: "https://api.appcenter.ms/v0.1/public/sdk/apps/\(appCenterId)/releases/latest") {
                self.currentCheckForUpdatesDisposable.set((downloadHTTPData(url: url)
                |> deliverOnMainQueue).start(next: { [weak self] data in
                    guard let strongSelf = self else {
                        return
                    }
                    guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
                        return
                    }
                    guard let dict = json as? [String: Any] else {
                        return
                    }
                    guard let versionString = dict["version"] as? String, let version = Int(versionString) else {
                        return
                    }
                    guard let releaseNotesUrl = dict["release_notes_url"] as? String else {
                        return
                    }
                    guard let currentVersionString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, let currentVersion = Int(currentVersionString) else {
                        return
                    }
                    if currentVersion < version {
                        let _ = (strongSelf.sharedContextPromise.get()
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { sharedContext in
                            let presentationData = sharedContext.sharedContext.currentPresentationData.with { $0 }
                            sharedContext.sharedContext.mainWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: "A new build is available", actions: [
                                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                                TextAlertAction(type: .defaultAction, title: "Show", action: {
                                    sharedContext.sharedContext.applicationBindings.openUrl(releaseNotesUrl)
                                })
                            ]), on: .root, blockInteraction: false, completion: {})
                        })
                    }
                }))
            }
        }
        #endif
    }
    #endif
    
    override var next: UIResponder? {
        if let context = self.contextValue, let controller = context.context.keyShortcutsController {
            return controller
        }
        return super.next
    }
    
    @objc func debugPressed() {
        // exporting logs is not secure, may reveal deleted/hidden data
        #if DEBUG
        let _ = (Logger.shared.collectShortLogFiles()
        |> deliverOnMainQueue).start(next: { logs in
            var activityItems: [Any] = []
            for (_, path) in logs {
                activityItems.append(URL(fileURLWithPath: path))
            }
            
            let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            
            self.window?.rootViewController?.present(activityController, animated: true, completion: nil)
        })
        #endif
    }
    
    private func resetIntentsIfNeeded(context: AccountContextImpl) {
        let _ = (context.sharedContext.accountManager.transaction { transaction in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.intentsSettings)?.get(IntentsSettings.self) ?? IntentsSettings.defaultSettings
            if (!settings.initiallyReset || settings.account == nil) && !context.immediateIsHidable {
                if #available(iOS 10.0, *) {
                    Queue.mainQueue().async {
                        INInteraction.deleteAll()
                    }
                }
                transaction.updateSharedData(ApplicationSpecificSharedDataKeys.intentsSettings, { _ in
                    return PreferencesEntry(IntentsSettings(initiallyReset: true, account: context.account.peerId, contacts: settings.contacts, privateChats: settings.privateChats, savedMessages: settings.savedMessages, groups: settings.groups, onlyShared: settings.onlyShared))
                })
            }
        }).start()
    }
}

private func notificationPayloadKey(data: Data) -> Data? {
    if data.count < 8 {
        return nil
    }
    return data.subdata(in: 0 ..< 8)
}

@available(iOS 10.0, *)
private func accountIdFromNotification(_ notification: UNNotification, sharedContext: Signal<SharedApplicationContext, NoError>) -> Signal<AccountRecordId?, NoError> {
    if let id = notification.request.content.userInfo["accountId"] as? Int64 {
        return .single(AccountRecordId(rawValue: id))
    } else if let idString = notification.request.content.userInfo["accountId"] as? String, let id = Int64(idString) {
        return .single(AccountRecordId(rawValue: id))
    } else {
        var encryptedData: Data?
        if var encryptedPayload = notification.request.content.userInfo["p"] as? String {
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "-", with: "+")
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "_", with: "/")
            while encryptedPayload.count % 4 != 0 {
                encryptedPayload.append("=")
            }
            encryptedData = Data(base64Encoded: encryptedPayload)
        }
        if let encryptedData = encryptedData, let notificationKeyId = notificationPayloadKey(data: encryptedData) {
            return sharedContext
            |> take(1)
            |> mapToSignal { sharedContext -> Signal<AccountRecordId?, NoError> in
                return sharedContext.sharedContext.activeAccountContexts
                |> take(1)
                |> mapToSignal { _, contexts, _, _ -> Signal<AccountRecordId?, NoError> in
                    let keys = contexts.map { _, context, _ -> Signal<(AccountRecordId, MasterNotificationKey)?, NoError> in
                        return masterNotificationsKey(account: context.account, ignoreDisabled: true)
                        |> map { key in
                            return (context.account.id, key)
                        }
                    }
                    return combineLatest(keys)
                    |> map { keys -> AccountRecordId? in
                        for idAndKey in keys {
                            if let (id, key) = idAndKey, key.id == notificationKeyId {
                                return id
                            }
                        }
                        return nil
                    }
                }
            }
        } else if let userId = notification.request.content.userInfo["userId"] as? Int {
            return sharedContext
            |> take(1)
            |> mapToSignal { sharedContext -> Signal<AccountRecordId?, NoError> in
                return sharedContext.sharedContext.activeAccountContexts
                |> take(1)
                |> map { _, contexts, _, _ -> AccountRecordId? in
                    for (_, context, _) in contexts {
                        if Int(context.account.peerId.id._internalGetInt64Value()) == userId {
                            return context.account.id
                        }
                    }
                    return nil
                }
            }
        } else {
            return .single(nil)
        }
    }
}

@available(iOS 10.0, *)
private func peerIdFromNotification(_ notification: UNNotification) -> (peerId: PeerId, threadId: Int64?)? {
    let threadId = notification.request.content.userInfo["threadId"] as? Int64
    
    if let peerId = notification.request.content.userInfo["peerId"] as? Int64 {
        return (PeerId(peerId), threadId)
    } else if let peerIdString = notification.request.content.userInfo["peerId"] as? String, let peerId = Int64(peerIdString) {
        return (PeerId(peerId), threadId)
    } else {
        let payload = notification.request.content.userInfo
        var peerId: PeerId?
        if let fromId = payload["from_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
        } else if let fromId = payload["chat_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
        } else if let fromId = payload["channel_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
        } else if let fromId = payload["encryption_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
        }
        
        if let peerId = peerId {
            return (peerId, threadId)
        } else {
            return nil
        }
    }
}

private func messageIdFromNotification(peerId: PeerId, notification: UNNotification) -> MessageId? {
    let payload = notification.request.content.userInfo
    if let messageIdNamespace = payload["messageId.namespace"] as? Int32, let messageIdId = payload["messageId.id"] as? Int32 {
        return MessageId(peerId: peerId, namespace: messageIdNamespace, id: messageIdId)
    }
    
    if let msgId = payload["msg_id"] {
        let msgIdValue = msgId as! NSString
        return MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(msgIdValue.intValue))
    }
    return nil
}

private func storyIdFromNotification(peerId: PeerId, notification: UNNotification) -> StoryId? {
    let payload = notification.request.content.userInfo
    if let storyId = payload["story_id"] {
        let storyIdValue = storyId as! NSString
        return StoryId(peerId: peerId, id: Int32(storyIdValue.intValue))
    }
    return nil
}

private enum DownloadFileError {
    case network
}

private func downloadHTTPData(url: URL) -> Signal<Data, DownloadFileError> {
    return Signal { subscriber in
        let completed = Atomic<Bool>(value: false)
        let downloadTask = URLSession.shared.downloadTask(with: url, completionHandler: { location, _, error in
            let _ = completed.swap(true)
            if let location = location, let data = try? Data(contentsOf: location) {
                subscriber.putNext(data)
                subscriber.putCompletion()
            } else {
                subscriber.putError(.network)
            }
        })
        downloadTask.resume()
        
        return ActionDisposable {
            if !completed.with({ $0 }) {
                downloadTask.cancel()
            }
        }
    }
}
