import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramNotices
import NotificationSoundSelectionUI
import TelegramStringFormatting
import ItemListPeerItem
import ItemListPeerActionItem
import NotificationPeerExceptionController

private extension EnginePeer.NotificationSettings.MuteState {
    var timeInterval: Int32? {
        switch self {
        case .default:
            return nil
        case .unmuted:
            return 0
        case let .muted(until):
            return until
        }
    }
}

private final class NotificationsPeerCategoryControllerArguments {
    let context: AccountContext
    let soundSelectionDisposable: MetaDisposable
    
    let updateEnabled: (Bool) -> Void
    let updateEnabledImportant: (Bool) -> Void
    let updatePreviews: (Bool) -> Void
    
    let openSound: (PeerMessageSound) -> Void
    
    let addException: () -> Void
    let openException: (EnginePeer) -> Void
    let removeAllExceptions: () -> Void
    let updateRevealedPeerId: (EnginePeer.Id?) -> Void
    let removePeer: (EnginePeer) -> Void
        
    let updatedExceptionMode: (NotificationExceptionMode) -> Void
        
    init(context: AccountContext, soundSelectionDisposable: MetaDisposable, updateEnabled: @escaping (Bool) -> Void, updateEnabledImportant: @escaping (Bool) -> Void, updatePreviews: @escaping (Bool) -> Void, openSound: @escaping (PeerMessageSound) -> Void, addException: @escaping () -> Void, openException: @escaping (EnginePeer) -> Void, removeAllExceptions: @escaping () -> Void, updateRevealedPeerId: @escaping (EnginePeer.Id?) -> Void, removePeer: @escaping (EnginePeer) -> Void, updatedExceptionMode: @escaping (NotificationExceptionMode) -> Void) {
        self.context = context
        self.soundSelectionDisposable = soundSelectionDisposable
        
        self.updateEnabled = updateEnabled
        self.updateEnabledImportant = updateEnabledImportant
        self.updatePreviews = updatePreviews
        self.openSound = openSound
        
        self.addException = addException
        self.openException = openException
        self.removeAllExceptions = removeAllExceptions
        
        self.updateRevealedPeerId = updateRevealedPeerId
        self.removePeer = removePeer
        
        self.updatedExceptionMode = updatedExceptionMode
    }
}

private enum NotificationsPeerCategorySection: Int32 {
    case enable
    case options
    case exceptions
}

public enum NotificationsPeerCategoryEntryTag: ItemListItemTag {
    case enable
    case previews
    case sound
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? NotificationsPeerCategoryEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum NotificationsPeerCategoryEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case enable
        case enableImportant
        case importantInfo
        case optionsHeader
        case previews
        case sound
        case exceptionsHeader
        case addException
        case peer(EnginePeer.Id)
        case removeAllExceptions
    }
    
    case enable(PresentationTheme, String, Bool)
    case enableImportant(PresentationTheme, String, Bool)
    case importantInfo(PresentationTheme, String)
    case optionsHeader(PresentationTheme, String)
    case previews(PresentationTheme, String, Bool)
    case sound(PresentationTheme, String, String, PeerMessageSound)
  
    case exceptionsHeader(PresentationTheme, String)
    case addException(PresentationTheme, String)
    case exception(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, EnginePeer, String, TelegramPeerNotificationSettings, Bool, Bool, Bool)
    case removeAllExceptions(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .enable, .enableImportant, .importantInfo:
                return NotificationsPeerCategorySection.enable.rawValue
            case .optionsHeader, .previews, .sound:
                return NotificationsPeerCategorySection.options.rawValue
            case .exceptionsHeader, .addException, .exception, .removeAllExceptions:
                return NotificationsPeerCategorySection.exceptions.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .enable:
            return .enable
        case .enableImportant:
            return .enableImportant
        case .importantInfo:
            return .importantInfo
        case .optionsHeader:
            return .optionsHeader
        case .previews:
            return .previews
        case .sound:
            return .sound
        case .exceptionsHeader:
            return .exceptionsHeader
        case .addException:
            return .addException
        case let .exception(_, _, _, _, _, peer, _, _, _, _, _):
            return .peer(peer.id)
        case .removeAllExceptions:
            return .removeAllExceptions
        }
    }
    
    var sortIndex: Int32 {
        switch self {
        case .enable:
            return 0
        case .enableImportant:
            return 1
        case .importantInfo:
            return 2
        case .optionsHeader:
            return 3
        case .previews:
            return 4
        case .sound:
            return 5
        case .exceptionsHeader:
            return 6
        case .addException:
            return 7
        case let .exception(index, _, _, _, _, _, _, _, _, _, _):
            return 100 + index
        case .removeAllExceptions:
            return 10000
        }
    }
    
    var tag: ItemListItemTag? {
        switch self {
            case .enable:
                return NotificationsPeerCategoryEntryTag.enable
            case .previews:
                return NotificationsPeerCategoryEntryTag.previews
            case .sound:
                return NotificationsPeerCategoryEntryTag.sound
            default:
                return nil
        }
    }
    
    static func ==(lhs: NotificationsPeerCategoryEntry, rhs: NotificationsPeerCategoryEntry) -> Bool {
        switch lhs {
            case let .enable(lhsTheme, lhsText, lhsValue):
                if case let .enable(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .enableImportant(lhsTheme, lhsText, lhsValue):
                if case let .enableImportant(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .importantInfo(lhsTheme, lhsText):
                if case let .importantInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .optionsHeader(lhsTheme, lhsText):
                if case let .optionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .previews(lhsTheme, lhsText, lhsValue):
                if case let .previews(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .sound(lhsTheme, lhsText, lhsValue, lhsSound):
                if case let .sound(rhsTheme, rhsText, rhsValue, rhsSound) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsSound == rhsSound {
                    return true
                } else {
                    return false
            }
            case let .exceptionsHeader(lhsTheme, lhsText):
                if case let .exceptionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addException(lhsTheme, lhsText):
                if case let .addException(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .exception(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsDisplayNameOrder, lhsPeer, lhsDescription, lhsSettings, lhsEditing, lhsRevealed, lhsCanRemove):
                if case let .exception(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsDisplayNameOrder, rhsPeer, rhsDescription, rhsSettings, rhsEditing, rhsRevealed, rhsCanRemove) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsDisplayNameOrder == rhsDisplayNameOrder, lhsPeer == rhsPeer, lhsDescription == rhsDescription, lhsSettings == rhsSettings, lhsEditing == rhsEditing, lhsRevealed == rhsRevealed, lhsCanRemove == rhsCanRemove {
                    return true
                } else {
                    return false
                }
            case let .removeAllExceptions(lhsTheme, lhsText):
                if case let .removeAllExceptions(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            
        }
    }
    
    static func <(lhs: NotificationsPeerCategoryEntry, rhs: NotificationsPeerCategoryEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NotificationsPeerCategoryControllerArguments
        switch self {
            case let .enable(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateEnabled(updatedValue)
                }, tag: self.tag)
            case let .enableImportant(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateEnabledImportant(updatedValue)
                }, tag: self.tag)
            case let .importantInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .optionsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .previews(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updatePreviews(value)
                })
            case let .sound(_, text, value, sound):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, labelStyle: .text, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.openSound(sound)
                }, tag: self.tag)
            case let .exceptionsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .addException(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(theme), title: text, sectionId: self.section, height: .peerList, color: .accent, editing: false, action: {
                    arguments.addException()
                })
            case let .exception(_, _, _, dateTimeFormat, nameDisplayOrder, peer, description, _, editing, revealed, canRemove):
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: peer, presence: nil, text: .text(description, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: canRemove, editing: canRemove && editing, revealed: canRemove && revealed), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openException(peer)
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.updateRevealedPeerId(peerId)
                }, removePeer: { peerId in
                    arguments.removePeer(peer)
                }, hasTopStripe: false, hasTopGroupInset: false, noInsets: false)
            case let .removeAllExceptions(theme, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.deleteIconImage(theme), title: text, sectionId: self.section, height: .generic, color: .destructive, editing: false, action: {
                    arguments.removeAllExceptions()
                })
        }
    }
}

private func filteredGlobalSound(_ sound: PeerMessageSound) -> PeerMessageSound {
    if case .default = sound {
        return defaultCloudPeerNotificationSound
    } else {
        return sound
    }
}

private func notificationsPeerCategoryEntries(category: NotificationsPeerCategory, globalSettings: GlobalNotificationSettingsSet, state: NotificationExceptionState, presentationData: PresentationData, notificationSoundList: NotificationSoundList?, automaticTopPeers: [EnginePeer], automaticNotificationSettings: [EnginePeer.Id: EnginePeer.NotificationSettings]) -> [NotificationsPeerCategoryEntry] {
    var entries: [NotificationsPeerCategoryEntry] = []
    
    let notificationSettings: MessageNotificationSettings
    let notificationExceptions = state.mode
    switch category {
        case .privateChat:
            notificationSettings = globalSettings.privateChats
        case .group:
            notificationSettings = globalSettings.groupChats
        case .channel:
            notificationSettings = globalSettings.channels
        case .stories:
            notificationSettings = globalSettings.privateChats
    }

    if case .stories = category {
        var allEnabled = false
        var importantEnabled = false
        
        switch notificationSettings.storySettings.mute {
        case .muted:
            allEnabled = false
            importantEnabled = false
        case .unmuted:
            allEnabled = true
            importantEnabled = true
        case .default:
            allEnabled = false
            importantEnabled = true
        }
        
        entries.append(.enable(presentationData.theme, presentationData.strings.NotificationSettings_Stories_ShowAll, allEnabled))
        if !allEnabled {
            entries.append(.enableImportant(presentationData.theme, presentationData.strings.NotificationSettings_Stories_ShowImportant, importantEnabled))
            entries.append(.importantInfo(presentationData.theme, presentationData.strings.NotificationSettings_Stories_ShowImportantFooter))
        }
        
        if notificationSettings.enabled || !notificationExceptions.isEmpty {
            entries.append(.optionsHeader(presentationData.theme, presentationData.strings.Notifications_Options.uppercased()))
            
            entries.append(.previews(presentationData.theme, presentationData.strings.NotificationSettings_Stories_DisplayAuthorName, notificationSettings.storySettings.hideSender != .hide))
            entries.append(.sound(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsSound, localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: filteredGlobalSound(notificationSettings.storySettings.sound)), filteredGlobalSound(notificationSettings.storySettings.sound)))
        }
    } else {
        entries.append(.enable(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsAlert, notificationSettings.enabled))
        
        if notificationSettings.enabled || !notificationExceptions.isEmpty {
            entries.append(.optionsHeader(presentationData.theme, presentationData.strings.Notifications_Options.uppercased()))
            entries.append(.previews(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsPreview, notificationSettings.displayPreviews))
            entries.append(.sound(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsSound, localizedPeerNotificationSoundString(strings: presentationData.strings, notificationSoundList: notificationSoundList, sound: filteredGlobalSound(notificationSettings.sound)), filteredGlobalSound(notificationSettings.sound)))
        }
    }
    
    entries.append(.exceptionsHeader(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsExceptions.uppercased()))
    entries.append(.addException(presentationData.theme, presentationData.strings.Notification_Exceptions_AddException))
    
    var sortedExceptions = notificationExceptions.settings.sorted(by: { lhs, rhs in
        let lhsName = lhs.value.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        let rhsName = rhs.value.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        
        if let lhsDate = lhs.value.date, let rhsDate = rhs.value.date {
            return lhsDate > rhsDate
        } else if lhs.value.date != nil && rhs.value.date == nil {
            return true
        } else if lhs.value.date == nil && rhs.value.date != nil {
            return false
        }
        
        if case let .user(lhsPeer) = lhs.value.peer, case let .user(rhsPeer) = rhs.value.peer {
            if lhsPeer.botInfo != nil && rhsPeer.botInfo == nil {
                return false
            } else if lhsPeer.botInfo == nil && rhsPeer.botInfo != nil {
                return true
            }
        }
        
        return lhsName < rhsName
    })
    var automaticSet = Set<EnginePeer.Id>()
    if globalSettings.privateChats.storySettings.mute == .default {
        for peer in automaticTopPeers {
            if sortedExceptions.contains(where: { $0.key == peer.id }) {
                continue
            }
            sortedExceptions.append((peer.id, NotificationExceptionWrapper(settings: automaticNotificationSettings[peer.id]?._asNotificationSettings() ?? .defaultSettings, peer: peer, date: nil)))
            automaticSet.insert(peer.id)
        }
    }
    
    var existingPeerIds = Set<EnginePeer.Id>()
    var index: Int = 0
    
    for (_, value) in sortedExceptions {
        if !value.peer.isDeleted {
            var canRemove = true
            var title: String = ""
            
            if automaticSet.contains(value.peer.id) {
                title = presentationData.strings.NotificationSettings_Stories_AutomaticValue(presentationData.strings.Notification_Exceptions_AlwaysOn).string
                canRemove = false
            } else {
                if case .stories = category {
                    var muted = false
                    if value.settings.storySettings.mute == .muted {
                        muted = true
                        title.append(presentationData.strings.Notification_Exceptions_AlwaysOff)
                    } else {
                        title.append(presentationData.strings.Notification_Exceptions_AlwaysOn)
                    }
                    
                    if !muted {
                        switch value.settings.storySettings.sound {
                        case .default:
                            break
                        default:
                            if !title.isEmpty {
                                title.append(", ")
                            }
                            title.append(presentationData.strings.Notification_Exceptions_SoundCustom)
                        }
                        switch value.settings.storySettings.hideSender {
                        case .default:
                            break
                        default:
                            if !title.isEmpty {
                                title += ", "
                            }
                            if case .show = value.settings.storySettings.hideSender {
                                title += presentationData.strings.NotificationSettings_Stories_CompactShowName
                            } else {
                                title += presentationData.strings.NotificationSettings_Stories_CompactHideName
                            }
                        }
                    }
                } else {
                    var muted = false
                    switch value.settings.muteState {
                    case let .muted(until):
                        if until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                            if until < Int32.max - 1 {
                                let formatter = DateFormatter()
                                formatter.locale = Locale(identifier: presentationData.strings.baseLanguageCode)
                                
                                if Calendar.current.isDateInToday(Date(timeIntervalSince1970: Double(until))) {
                                    formatter.dateFormat = "HH:mm"
                                } else {
                                    formatter.dateFormat = "E, d MMM HH:mm"
                                }
                                
                                let dateString = formatter.string(from: Date(timeIntervalSince1970: Double(until)))
                                
                                title = presentationData.strings.Notification_Exceptions_MutedUntil(dateString).string
                            } else {
                                muted = true
                                title = presentationData.strings.Notification_Exceptions_AlwaysOff
                            }
                        } else {
                            title = presentationData.strings.Notification_Exceptions_AlwaysOn
                        }
                    case .unmuted:
                        title = presentationData.strings.Notification_Exceptions_AlwaysOn
                    default:
                        title = ""
                    }
                    if !muted {
                        switch value.settings.messageSound {
                        case .default:
                            break
                        default:
                            if !title.isEmpty {
                                title.append(", ")
                            }
                            title.append(presentationData.strings.Notification_Exceptions_SoundCustom)
                        }
                        switch value.settings.displayPreviews {
                        case .default:
                            break
                        default:
                            if !title.isEmpty {
                                title += ", "
                            }
                            if case .show = value.settings.displayPreviews {
                                title += presentationData.strings.Notification_Exceptions_PreviewAlwaysOn
                            } else {
                                title += presentationData.strings.Notification_Exceptions_PreviewAlwaysOff
                            }
                        }
                    }
                }
            }
            existingPeerIds.insert(value.peer.id)
            entries.append(.exception(Int32(index), presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, value.peer, title, value.settings, state.editing, state.revealedPeerId == value.peer.id, canRemove))
            index += 1
        }
    }
    
    if notificationExceptions.peerIds.count > 0 {
        entries.append(.removeAllExceptions(presentationData.theme, presentationData.strings.Notifications_DeleteAllExceptions))
    }

    return entries
}

public enum NotificationsPeerCategory {
    case privateChat
    case group
    case channel
    case stories
}

private final class NotificationExceptionState : Equatable {
    let mode: NotificationExceptionMode
    let revealedPeerId: EnginePeer.Id?
    let editing: Bool
    
    init(mode: NotificationExceptionMode, revealedPeerId: EnginePeer.Id? = nil, editing: Bool = false) {
        self.mode = mode
        self.revealedPeerId = revealedPeerId
        self.editing = editing
    }
    
    func withUpdatedMode(_ mode: NotificationExceptionMode) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode, revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> NotificationExceptionState {
        return NotificationExceptionState(mode: self.mode, revealedPeerId: self.revealedPeerId, editing: editing)
    }
    
    func withUpdatedRevealedPeerId(_ revealedPeerId: EnginePeer.Id?) -> NotificationExceptionState {
        return NotificationExceptionState(mode: self.mode, revealedPeerId: revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedPeerSound(_ peer: EnginePeer, _ sound: PeerMessageSound) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.withUpdatedPeerSound(peer, sound), revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedPeerMuteInterval(_ peer: EnginePeer, _ muteInterval: Int32?) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.withUpdatedPeerMuteInterval(peer, muteInterval), revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedPeerDisplayPreviews(_ peer: EnginePeer, _ displayPreviews: PeerNotificationDisplayPreviews) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.withUpdatedPeerDisplayPreviews(peer, displayPreviews), revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedPeerStoriesMuted(_ peer: EnginePeer, _ mute: PeerStoryNotificationSettings.Mute) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.withUpdatedPeerStoriesMuted(peer, mute), revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedPeerStoriesHideSender(_ peer: EnginePeer, _ hideSender: PeerStoryNotificationSettings.HideSender) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.withUpdatedPeerStoriesHideSender(peer, hideSender), revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    func withUpdatedPeerStorySound(_ peer: EnginePeer, _ sound: PeerMessageSound) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.withUpdatedPeerStorySound(peer, sound), revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    func removeStoryPeerIfDefault(id: EnginePeer.Id) -> NotificationExceptionState {
        return NotificationExceptionState(mode: mode.removeStoryPeerIfDefault(id: id), revealedPeerId: self.revealedPeerId, editing: self.editing)
    }
    
    static func == (lhs: NotificationExceptionState, rhs: NotificationExceptionState) -> Bool {
        return lhs.mode == rhs.mode && lhs.revealedPeerId == rhs.revealedPeerId && lhs.editing == rhs.editing
    }
}

public func notificationsPeerCategoryController(context: AccountContext, category: NotificationsPeerCategory, mode: NotificationExceptionMode, updatedMode: @escaping (NotificationExceptionMode) -> Void, focusOnItemTag: NotificationsPeerCategoryEntryTag? = nil) -> ViewController {
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let stateValue = Atomic<NotificationExceptionState>(value: NotificationExceptionState(mode: mode))
    let statePromise: ValuePromise<NotificationExceptionState> = ValuePromise(ignoreRepeated: true)
    
    statePromise.set(NotificationExceptionState(mode: mode))
    
    let notificationExceptions: Promise<(users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode, stories: NotificationExceptionMode)> = Promise()
    
    let updateNotificationExceptions:((users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode, stories: NotificationExceptionMode)) -> Void = { value in
        notificationExceptions.set(.single(value))
    }
    
    let updateState: ((NotificationExceptionState) -> NotificationExceptionState) -> Void = { f in
        let result = stateValue.modify { f($0) }
        statePromise.set(result)
        updatedMode(result.mode)
    }
    
    let updatePeerSound: (EnginePeer.Id, PeerMessageSound) -> Signal<Void, NoError> = { peerId, sound in
        return context.engine.peers.updatePeerNotificationSoundInteractive(peerId: peerId, threadId: nil, sound: sound) |> deliverOnMainQueue
    }

    let updatePeerNotificationInterval: (EnginePeer.Id, Int32?) -> Signal<Void, NoError> = { peerId, muteInterval in
        return context.engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: nil, muteInterval: muteInterval) |> deliverOnMainQueue
    }

    let updatePeerDisplayPreviews:(EnginePeer.Id, PeerNotificationDisplayPreviews) -> Signal<Void, NoError> = {
        peerId, displayPreviews in
        return context.engine.peers.updatePeerDisplayPreviewsSetting(peerId: peerId, threadId: nil, displayPreviews: displayPreviews) |> deliverOnMainQueue
    }
    
    let updatePeerStoriesMuted: (EnginePeer.Id, PeerStoryNotificationSettings.Mute) -> Signal<Void, NoError> = {
        peerId, mute in
        return context.engine.peers.updatePeerStoriesMutedSetting(peerId: peerId, mute: mute) |> deliverOnMainQueue
    }
    
    let updatePeerStoriesHideSender: (EnginePeer.Id, PeerStoryNotificationSettings.HideSender) -> Signal<Void, NoError> = {
        peerId, hideSender in
        return context.engine.peers.updatePeerStoriesHideSenderSetting(peerId: peerId, hideSender: hideSender) |> deliverOnMainQueue
    }
    
    let updatePeerStorySound: (EnginePeer.Id, PeerMessageSound) -> Signal<Void, NoError> = { peerId, sound in
        return context.engine.peers.updatePeerStorySoundInteractive(peerId: peerId, sound: sound) |> deliverOnMainQueue
    }
    
    var peerIds: Set<EnginePeer.Id> = Set(mode.peerIds)
    let updateNotificationsDisposable = MetaDisposable()
    let updateNotificationsView: (@escaping () -> Void) -> Void = { completion in
        updateState { current in
            peerIds = peerIds.union(current.mode.peerIds)
            let combinedPeerNotificationSettings = context.engine.data.subscribe(EngineDataMap(
                peerIds.map(TelegramEngine.EngineData.Item.Peer.NotificationSettings.init)
            ))
            
            updateNotificationsDisposable.set((combinedPeerNotificationSettings
            |> deliverOnMainQueue).start(next: { combinedPeerNotificationSettings in
                let _ = (context.engine.data.get(
                    EngineDataMap(combinedPeerNotificationSettings.keys.map(TelegramEngine.EngineData.Item.Peer.Peer.init)),
                    EngineDataMap(combinedPeerNotificationSettings.keys.map(TelegramEngine.EngineData.Item.Peer.NotificationSettings.init))
                )
                |> deliverOnMainQueue).start(next: { peerMap, notificationSettingsMap in
                    updateState { current in
                        var current = current
                        for (key, value) in combinedPeerNotificationSettings {
                            if let local = current.mode.settings[key]  {
                                if !value._asNotificationSettings().isEqual(to: local.settings), let maybePeer = peerMap[key], let peer = maybePeer, let settings = notificationSettingsMap[key], !settings._asNotificationSettings().isEqual(to: local.settings) {
                                    current = current.withUpdatedPeerSound(peer, settings.messageSound._asMessageSound()).withUpdatedPeerMuteInterval(peer, settings.muteState.timeInterval).withUpdatedPeerDisplayPreviews(peer, settings.displayPreviews._asDisplayPreviews())
                                }
                            } else if let maybePeer = peerMap[key], let peer = maybePeer {
                                if case .default = value.messageSound, case .unmuted = value.muteState, case .default = value.displayPreviews {
                                } else {
                                    current = current.withUpdatedPeerSound(peer, value.messageSound._asMessageSound()).withUpdatedPeerMuteInterval(peer, value.muteState.timeInterval).withUpdatedPeerDisplayPreviews(peer, value.displayPreviews._asDisplayPreviews())
                                }
                            }
                        }
                        return current
                    }
                    
                    completion()
                })
            }))
            return current
        }
    }
    
    updateNotificationsView({})
    
    let presentPeerSettings: (EnginePeer.Id, @escaping () -> Void) -> Void = { peerId, completion in
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
            TelegramEngine.EngineData.Item.NotificationSettings.Global()
        )
        |> deliverOnMainQueue).start(next: { peer, globalSettings in
            completion()
            
            guard let peer = peer else {
                return
            }
            
            let mode = stateValue.with { $0.mode }
            
            let canRemove = mode.peerIds.contains(peerId)
            
            let defaultSound: PeerMessageSound
            var isStories = false
            switch mode {
            case .channels:
                defaultSound = globalSettings.channels.sound._asMessageSound()
            case .groups:
                defaultSound = globalSettings.groupChats.sound._asMessageSound()
            case .users:
                defaultSound = globalSettings.privateChats.sound._asMessageSound()
            case .stories:
                defaultSound = globalSettings.privateChats.storySettings.sound
                isStories = true
            }
            
            pushControllerImpl?(notificationPeerExceptionController(context: context, peer: peer, threadId: nil, isStories: isStories, canRemove: canRemove, defaultSound: defaultSound, defaultStoriesSound: defaultSound, updatePeerSound: { peerId, sound in
                _ = updatePeerSound(peer.id, sound).start(next: { _ in
                    updateNotificationsDisposable.set(nil)
                    _ = combineLatest(updatePeerSound(peer.id, sound), context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue).start(next: { _, peer in
                        if let peer = peer {
                            updateState { value in
                                return value.withUpdatedPeerSound(peer, sound)
                            }
                        }
                        updateNotificationsView({})
                    })
                })
            }, updatePeerNotificationInterval: { peerId, muteInterval in
                updateNotificationsDisposable.set(nil)
                _ = combineLatest(updatePeerNotificationInterval(peerId, muteInterval), context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue).start(next: { _, peer in
                    if let peer = peer {
                        updateState { value in
                            return value.withUpdatedPeerMuteInterval(peer, muteInterval)
                        }
                    }
                    updateNotificationsView({})
                })
            }, updatePeerDisplayPreviews: { peerId, displayPreviews in
                updateNotificationsDisposable.set(nil)
                _ = combineLatest(updatePeerDisplayPreviews(peerId, displayPreviews), context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue).start(next: { _, peer in
                    if let peer = peer {
                        updateState { value in
                            return value.withUpdatedPeerDisplayPreviews(peer, displayPreviews)
                        }
                    }
                    updateNotificationsView({})
                })
            }, updatePeerStoriesMuted: { peerId, mute in
                updateNotificationsDisposable.set(nil)
                let _ = combineLatest(updatePeerStoriesMuted(peerId, mute), context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue).start(next: { _, peer in
                    if let peer = peer {
                        updateState { value in
                            return value.withUpdatedPeerStoriesMuted(peer, mute)
                        }
                    }
                    updateNotificationsView({})
                })
            }, updatePeerStoriesHideSender: { peerId, hideSender in
                updateNotificationsDisposable.set(nil)
                let _ = combineLatest(updatePeerStoriesHideSender(peerId, hideSender), context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue).start(next: { _, peer in
                    if let peer = peer {
                        updateState { value in
                            return value.withUpdatedPeerStoriesHideSender(peer, hideSender)
                        }
                    }
                    updateNotificationsView({})
                })
            }, updatePeerStorySound: { peerId, sound in
                updateNotificationsDisposable.set(nil)
                let _ = combineLatest(updatePeerStorySound(peerId, sound), context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue).start(next: { _, peer in
                    if let peer = peer {
                        updateState { value in
                            return value.withUpdatedPeerStorySound(peer, sound)
                        }
                    }
                    updateNotificationsView({})
                })
            }, removePeerFromExceptions: {
                if case .stories = mode.mode {
                    let _ = (
                        context.engine.peers.removeCustomStoryNotificationSettings(peerIds: [peerId])
                        |> map { _ -> EnginePeer? in }
                        |> then(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)))
                    ).start(next: { peer in
                        guard let peer = peer else {
                            return
                        }
                        updateState { value in
                            var value = value.withUpdatedPeerStorySound(peer, .default).withUpdatedPeerStoriesMuted(peer, .default).withUpdatedPeerStoriesHideSender(peer, .default)
                            value = value.removeStoryPeerIfDefault(id: peer.id)
                            return value
                        }
                        updateNotificationsView({})
                    })
                } else {
                    let _ = (
                        context.engine.peers.removeCustomNotificationSettings(peerIds: [peerId])
                        |> map { _ -> EnginePeer? in }
                        |> then(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)))
                    ).start(next: { peer in
                        guard let peer = peer else {
                            return
                        }
                        updateState { value in
                            return value.withUpdatedPeerDisplayPreviews(peer, .default).withUpdatedPeerSound(peer, .default).withUpdatedPeerMuteInterval(peer, nil)
                        }
                        updateNotificationsView({})
                    })
                }
            }, modifiedPeer: {

            }))
        })
    }
    
    let arguments = NotificationsPeerCategoryControllerArguments(context: context, soundSelectionDisposable: MetaDisposable(), updateEnabled: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            switch category {
            case .privateChat:
                settings.privateChats.enabled = value
            case .group:
                settings.groupChats.enabled = value
            case .channel:
                settings.channels.enabled = value
            case .stories:
                settings.privateChats.storySettings.mute = value ? .unmuted : .default
            }
            return settings
        }).start()
    }, updateEnabledImportant: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            switch category {
            case .stories:
                settings.privateChats.storySettings.mute = value ? .default : .muted
            default:
                break
            }
            return settings
        }).start()
    }, updatePreviews: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            switch category {
                case .privateChat:
                    settings.privateChats.displayPreviews = value
                case .group:
                    settings.groupChats.displayPreviews = value
                case .channel:
                    settings.channels.displayPreviews = value
                case .stories:
                    settings.privateChats.storySettings.hideSender = value ? .show : .hide
            }
            return settings
        }).start()
    }, openSound: { sound in
        let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: sound, defaultSound: nil, completion: { value in
            let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                switch category {
                    case .privateChat:
                        settings.privateChats.sound = value
                    case .group:
                        settings.groupChats.sound = value
                    case .channel:
                        settings.channels.sound = value
                    case .stories:
                        settings.privateChats.storySettings.sound = value
                }
                return settings
            }).start()
        })
        pushControllerImpl?(controller)
    }, addException: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var filter: ChatListNodePeersFilter = [.excludeRecent, .doNotSearchMessages, .removeSearchHeader]
        switch category {
            case .privateChat, .stories:
                filter.insert(.onlyPrivateChats)
                filter.insert(.excludeSavedMessages)
                filter.insert(.excludeSecretChats)
            case .group:
                filter.insert(.onlyGroups)
            case .channel:
                filter.insert(.onlyChannels)
        }
        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: filter, hasContactSelector: false, title: presentationData.strings.Notifications_AddExceptionTitle))
        controller.peerSelected = { [weak controller] peer, _ in
            let peerId = peer.id
            
            presentPeerSettings(peerId, {
                controller?.dismiss()
            })
        }
        pushControllerImpl?(controller)
    }, openException: { peer in
        presentPeerSettings(peer.id, {})
    }, removeAllExceptions: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetTextItem(title: presentationData.strings.Notification_Exceptions_DeleteAllConfirmation),
            ActionSheetButtonItem(title: presentationData.strings.Notification_Exceptions_DeleteAll, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let values = stateValue.with { $0.mode.settings.values }
                
                if case .stories = mode.mode {
                    let _ = (context.engine.peers.ensurePeersAreLocallyAvailable(peers: values.map { $0.peer })
                    |> deliverOnMainQueue).start(completed: {
                        updateNotificationsDisposable.set(nil)
                        updateState { state in
                            var state = state
                            for value in values {
                                state = state.withUpdatedPeerStorySound(value.peer, .default).withUpdatedPeerStoriesMuted(value.peer, .default).withUpdatedPeerStoriesHideSender(value.peer, .default)
                                state = state.removeStoryPeerIfDefault(id: value.peer.id)
                            }
                            return state
                        }
                        let _ = (context.engine.peers.removeCustomStoryNotificationSettings(peerIds: values.map(\.peer.id))
                        |> deliverOnMainQueue).start(completed: {
                            updateNotificationsView({})
                        })
                    })
                } else {
                    let _ = (context.engine.peers.ensurePeersAreLocallyAvailable(peers: values.map { $0.peer })
                    |> deliverOnMainQueue).start(completed: {
                        updateNotificationsDisposable.set(nil)
                        updateState { state in
                            var state = state
                            for value in values {
                                state = state.withUpdatedPeerMuteInterval(value.peer, nil).withUpdatedPeerSound(value.peer, .default).withUpdatedPeerDisplayPreviews(value.peer, .default)
                            }
                            return state
                        }
                        let _ = (context.engine.peers.removeCustomNotificationSettings(peerIds: values.map(\.peer.id))
                        |> deliverOnMainQueue).start(completed: {
                            updateNotificationsView({})
                        })
                    })
                }
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }, updateRevealedPeerId: { peerId in
        updateState { current in
            return current.withUpdatedRevealedPeerId(peerId)
        }
    }, removePeer: { peer in
        if case .stories = mode.mode {
            let _ = (context.engine.peers.ensurePeersAreLocallyAvailable(peers: [peer])
            |> deliverOnMainQueue).start(completed: {
                updateNotificationsDisposable.set(nil)
                updateState { value in
                    var value = value.withUpdatedPeerStorySound(peer, .default).withUpdatedPeerStoriesMuted(peer, .default).withUpdatedPeerStoriesHideSender(peer, .default)
                    value = value.removeStoryPeerIfDefault(id: peer.id)
                    return value
                }
                let _ = (context.engine.peers.removeCustomStoryNotificationSettings(peerIds: [peer.id])
                |> deliverOnMainQueue).start(completed: {
                    updateNotificationsView({})
                })
            })
        } else {
            let _ = (context.engine.peers.ensurePeersAreLocallyAvailable(peers: [peer])
            |> deliverOnMainQueue).start(completed: {
                updateNotificationsDisposable.set(nil)
                updateState { value in
                    return value.withUpdatedPeerMuteInterval(peer, nil).withUpdatedPeerSound(peer, .default).withUpdatedPeerDisplayPreviews(peer, .default)
                }
                let _ = (context.engine.peers.removeCustomNotificationSettings(peerIds: [peer.id])
                |> deliverOnMainQueue).start(completed: {
                    updateNotificationsView({})
                })
            })
        }
    }, updatedExceptionMode: { mode in
        _ = (notificationExceptions.get() |> take(1) |> deliverOnMainQueue).start(next: { (users, groups, channels, stories) in
            switch mode {
                case .users:
                    updateNotificationExceptions((mode, groups, channels, stories))
                case .groups:
                    updateNotificationExceptions((users, mode, channels, stories))
                case .channels:
                    updateNotificationExceptions((users, groups, mode, stories))
                case .stories:
                    updateNotificationExceptions((users, groups, channels, mode))
            }
        })
    })
    
    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
    let preferences = context.account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])
    
    var automaticData: Signal<([EnginePeer], [EnginePeer.Id: EnginePeer.NotificationSettings]), NoError> = .single(([], [:]))
    if case .stories = category {
        automaticData = context.engine.peers.recentPeers()
        |> mapToSignal { recentPeers -> Signal<([EnginePeer], [EnginePeer.Id: EnginePeer.NotificationSettings]), NoError> in
            guard case let .peers(peersValue) = recentPeers else {
                return .single(([], [:]))
            }
            let peers = peersValue.prefix(5).map(EnginePeer.init)
            return context.engine.data.subscribe(
                EngineDataMap(peers.map { peer in
                    return TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peer.id)
                })
            )
            |> map { settings -> ([EnginePeer], [EnginePeer.Id: EnginePeer.NotificationSettings]) in
                var settingsMap: [EnginePeer.Id: EnginePeer.NotificationSettings] = [:]
                for peer in peers {
                    if let value = settings[peer.id] {
                        settingsMap[peer.id] = value
                    } else {
                        settingsMap[peer.id] = EnginePeer.NotificationSettings(TelegramPeerNotificationSettings.defaultSettings)
                    }
                }
                return (peers, settingsMap)
            }
        }
    }
    
    let signal = combineLatest(context.sharedContext.presentationData, context.engine.peers.notificationSoundList(), sharedData, preferences, statePromise.get(), automaticData)
    |> map { presentationData, notificationSoundList, sharedData, view, state, automaticData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let viewSettings: GlobalNotificationSettingsSet
        if let settings = view.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
            viewSettings = settings.effective
        } else {
            viewSettings = GlobalNotificationSettingsSet.defaultSettings
        }
        
        let entries = notificationsPeerCategoryEntries(category: category, globalSettings: viewSettings, state: state, presentationData: presentationData, notificationSoundList: notificationSoundList, automaticTopPeers: automaticData.0, automaticNotificationSettings: automaticData.1)
        
        var index = 0
        var scrollToItem: ListViewScrollToItem?
        if let focusOnItemTag = focusOnItemTag {
            for entry in entries {
                if entry.tag?.isEqual(to: focusOnItemTag) ?? false {
                    scrollToItem = ListViewScrollToItem(index: index, position: .top(0.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
                }
                index += 1
            }
        }
        
        let leftNavigationButton: ItemListNavigationButton?
        let rightNavigationButton: ItemListNavigationButton?
        if !state.mode.peerIds.isEmpty {
            if state.editing {
                leftNavigationButton = ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {})
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    updateState { value in
                        return value.withUpdatedEditing(false)
                    }
                })
            } else {
                leftNavigationButton = nil
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    updateState { value in
                        return value.withUpdatedEditing(true)
                    }
                })
            }
        } else {
            leftNavigationButton = nil
            rightNavigationButton = nil
        }
        
        let title: String
        switch category {
            case .privateChat:
                title = presentationData.strings.Notifications_PrivateChatsTitle
            case .group:
                title = presentationData.strings.Notifications_GroupChatsTitle
            case .channel:
                title = presentationData.strings.Notifications_ChannelsTitle
            case .stories:
                title = presentationData.strings.Notifications_StoriesTitle
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: focusOnItemTag, initialScrollToItem: scrollToItem)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
