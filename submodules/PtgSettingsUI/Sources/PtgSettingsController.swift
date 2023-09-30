import Foundation
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountUtils
import PresentationDataUtils
import PtgSettings

private final class PtgSettingsControllerArguments {
    let switchShowPeerId: (Bool) -> Void
    let switchShowChannelCreationDate: (Bool) -> Void
    let switchSuppressForeignAgentNotice: (Bool) -> Void
    let switchEnableLiveText: (Bool) -> Void
    let changeVoiceToTextPremiumAccountsImplementation: () -> Void
    let changeDefaultCameraForVideos: () -> Void
    let switchEnableQuickReaction: (Bool) -> Void
    let switchHideReactionsInChannels: (Bool) -> Void
    let switchHideCommentsInChannels: (Bool) -> Void
    let switchHideShareButtonInChannels: (Bool) -> Void
    let switchUseFullWidthInChannels: (Bool) -> Void
    let switchAddContextMenuSaveMessage: (Bool) -> Void
    let switchAddContextMenuShare: (Bool) -> Void
    let changeJumpToNextUnreadChannel: () -> Void
    let switchHideSignatureInChannels: (Bool) -> Void
    
    init(
        switchShowPeerId: @escaping (Bool) -> Void,
        switchShowChannelCreationDate: @escaping (Bool) -> Void,
        switchSuppressForeignAgentNotice: @escaping (Bool) -> Void,
        switchEnableLiveText: @escaping (Bool) -> Void,
        changeVoiceToTextPremiumAccountsImplementation: @escaping () -> Void,
        changeDefaultCameraForVideos: @escaping () -> Void,
        switchEnableQuickReaction: @escaping (Bool) -> Void,
        switchHideReactionsInChannels: @escaping (Bool) -> Void,
        switchHideCommentsInChannels: @escaping (Bool) -> Void,
        switchHideShareButtonInChannels: @escaping (Bool) -> Void,
        switchUseFullWidthInChannels: @escaping (Bool) -> Void,
        switchAddContextMenuSaveMessage: @escaping (Bool) -> Void,
        switchAddContextMenuShare: @escaping (Bool) -> Void,
        changeJumpToNextUnreadChannel: @escaping () -> Void,
        switchHideSignatureInChannels: @escaping (Bool) -> Void
    ) {
        self.switchShowPeerId = switchShowPeerId
        self.switchShowChannelCreationDate = switchShowChannelCreationDate
        self.switchSuppressForeignAgentNotice = switchSuppressForeignAgentNotice
        self.switchEnableLiveText = switchEnableLiveText
        self.changeVoiceToTextPremiumAccountsImplementation = changeVoiceToTextPremiumAccountsImplementation
        self.changeDefaultCameraForVideos = changeDefaultCameraForVideos
        self.switchEnableQuickReaction = switchEnableQuickReaction
        self.switchHideReactionsInChannels = switchHideReactionsInChannels
        self.switchHideCommentsInChannels = switchHideCommentsInChannels
        self.switchHideShareButtonInChannels = switchHideShareButtonInChannels
        self.switchUseFullWidthInChannels = switchUseFullWidthInChannels
        self.switchAddContextMenuSaveMessage = switchAddContextMenuSaveMessage
        self.switchAddContextMenuShare = switchAddContextMenuShare
        self.changeJumpToNextUnreadChannel = changeJumpToNextUnreadChannel
        self.switchHideSignatureInChannels = switchHideSignatureInChannels
    }
}

private enum PtgSettingsSection: Int32 {
    case showProfileData
    case experimental
    case channels
    case voiceToText
    case defaultCameraForVideos
    case addContextMenus
}

private enum PtgSettingsEntry: ItemListNodeEntry {
    case showPeerId(String, Bool)
    case showChannelCreationDate(String, Bool)
    
    case suppressForeignAgentNotice(String, Bool)

    case enableLiveText(String, Bool)
    case enableLiveTextInfo(String)
    
    case voiceToTextHeader(String)
    case voiceToTextPremiumAccountsImplementation(String, String, Bool)
    case voiceToTextInfo(String)

    case defaultCameraForVideos(String, String)
    
    case enableQuickReaction(String, Bool)
    case enableQuickReactionInfo(String)
    
    case channelAppearanceHeader(String)
    case hideReactionsInChannels(String, Bool)
    case hideCommentsInChannels(String, Bool)
    case hideShareButtonInChannels(String, Bool)
    case useFullWidthInChannels(String, Bool)
    case jumpToNextUnreadChannel(String, String)
    case hideSignatureInChannels(String, Bool)
    
    case addContextMenuHeader(String)
    case addContextMenuSaveMessage(String, Bool)
    case addContextMenuShare(String, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .showPeerId, .showChannelCreationDate:
            return PtgSettingsSection.showProfileData.rawValue
        case .enableQuickReaction, .enableQuickReactionInfo, .enableLiveText, .enableLiveTextInfo:
            return PtgSettingsSection.experimental.rawValue
        case .voiceToTextHeader, .voiceToTextPremiumAccountsImplementation, .voiceToTextInfo:
            return PtgSettingsSection.voiceToText.rawValue
        case .defaultCameraForVideos:
            return PtgSettingsSection.defaultCameraForVideos.rawValue
        case .channelAppearanceHeader, .hideReactionsInChannels, .hideCommentsInChannels, .hideShareButtonInChannels, .useFullWidthInChannels, .jumpToNextUnreadChannel, .hideSignatureInChannels, .suppressForeignAgentNotice:
            return PtgSettingsSection.channels.rawValue
        case .addContextMenuHeader, .addContextMenuSaveMessage, .addContextMenuShare:
            return PtgSettingsSection.addContextMenus.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .showPeerId:
            return 0
        case .showChannelCreationDate:
            return 1
        case .channelAppearanceHeader:
            return 2
        case .hideReactionsInChannels:
            return 3
        case .hideCommentsInChannels:
            return 4
        case .hideSignatureInChannels:
            return 5
        case .hideShareButtonInChannels:
            return 6
        case .useFullWidthInChannels:
            return 7
        case .jumpToNextUnreadChannel:
            return 8
        case .suppressForeignAgentNotice:
            return 9
        case .addContextMenuHeader:
            return 10
        case .addContextMenuSaveMessage:
            return 11
        case .addContextMenuShare:
            return 12
        case .enableQuickReaction:
            return 13
        case .enableQuickReactionInfo:
            return 14
        case .enableLiveText:
            return 15
        case .enableLiveTextInfo:
            return 16
        case .defaultCameraForVideos:
            return 17
        case .voiceToTextHeader:
            return 18
        case .voiceToTextPremiumAccountsImplementation:
            return 19
        case .voiceToTextInfo:
            return 20
        }
    }
    
    static func <(lhs: PtgSettingsEntry, rhs: PtgSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PtgSettingsControllerArguments
        switch self {
        case let .showPeerId(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchShowPeerId(updatedValue)
            })
        case let .showChannelCreationDate(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchShowChannelCreationDate(updatedValue)
            })
        case let .suppressForeignAgentNotice(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchSuppressForeignAgentNotice(updatedValue)
            })
        case let .enableLiveText(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchEnableLiveText(updatedValue)
            })
        case let .enableQuickReactionInfo(text), let .enableLiveTextInfo(text), let .voiceToTextInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .voiceToTextPremiumAccountsImplementation(title, value, enabled):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, enabled: enabled, label: value, sectionId: self.section, style: .blocks, action: {
                arguments.changeVoiceToTextPremiumAccountsImplementation()
            })
        case let .defaultCameraForVideos(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                arguments.changeDefaultCameraForVideos()
            })
        case let .enableQuickReaction(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchEnableQuickReaction(updatedValue)
            })
        case let .hideReactionsInChannels(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchHideReactionsInChannels(updatedValue)
            })
        case let .hideCommentsInChannels(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchHideCommentsInChannels(updatedValue)
            })
        case let .hideShareButtonInChannels(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchHideShareButtonInChannels(updatedValue)
            })
        case let .useFullWidthInChannels(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchUseFullWidthInChannels(updatedValue)
            })
        case let .channelAppearanceHeader(text), let .addContextMenuHeader(text), let .voiceToTextHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .addContextMenuSaveMessage(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchAddContextMenuSaveMessage(updatedValue)
            })
        case let .addContextMenuShare(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchAddContextMenuShare(updatedValue)
            })
        case let .jumpToNextUnreadChannel(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                arguments.changeJumpToNextUnreadChannel()
            })
        case let .hideSignatureInChannels(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.switchHideSignatureInChannels(updatedValue)
            })
        }
    }
}

private struct PtgSettingsState: Equatable {
    let settings: PtgSettings

    func withUpdatedSettings(_ settings: PtgSettings) -> PtgSettingsState {
        return PtgSettingsState(settings: settings)
    }
}

private func ptgSettingsControllerEntries(presentationData: PresentationData, settings: PtgSettings, experimentalSettings: ExperimentalUISettings, hasPremiumAccounts: Bool, ptgAccountSettings: PtgAccountSettings) -> [PtgSettingsEntry] {
    var entries: [PtgSettingsEntry] = []
    
    entries.append(.showPeerId(presentationData.strings.PtgSettings_ShowPeerId, settings.showPeerId))
    entries.append(.showChannelCreationDate(presentationData.strings.PtgSettings_ShowChannelCreationDate, settings.showChannelCreationDate))
    
    entries.append(.channelAppearanceHeader(presentationData.strings.PtgSettings_ChannelAppearanceHeader.uppercased()))
    entries.append(.hideReactionsInChannels(presentationData.strings.PtgSettings_HideReactions, settings.hideReactionsInChannels))
    entries.append(.hideCommentsInChannels(presentationData.strings.PtgSettings_HideComments, settings.hideCommentsInChannels))
    entries.append(.hideSignatureInChannels(presentationData.strings.PtgSettings_HideSignatures, settings.hideSignatureInChannels))
    entries.append(.hideShareButtonInChannels(presentationData.strings.PtgSettings_HideShareButton, settings.hideShareButtonInChannels))
    entries.append(.useFullWidthInChannels(presentationData.strings.PtgSettings_UseFullWidth, settings.useFullWidthInChannels))
    entries.append(.jumpToNextUnreadChannel(presentationData.strings.PtgSettings_JumpToNextUnreadChannel, jumpToNextUnreadChannelValueString(settings.jumpToNextUnreadChannel, strings: presentationData.strings)))
    entries.append(.suppressForeignAgentNotice(presentationData.strings.PtgSettings_SuppressForeignAgentNotice, settings.suppressForeignAgentNotice))
    
    entries.append(.addContextMenuHeader(presentationData.strings.PtgSettings_AddContextMenuHeader.uppercased()))
    entries.append(.addContextMenuSaveMessage(presentationData.strings.PtgSettings_AddContextMenuSaveMessage, settings.addContextMenuSaveMessage))
    entries.append(.addContextMenuShare(presentationData.strings.PtgSettings_AddContextMenuShare, settings.addContextMenuShare))
    
    entries.append(.enableQuickReaction(presentationData.strings.PtgSettings_EnableQuickReaction, !experimentalSettings.disableQuickReaction))
    entries.append(.enableQuickReactionInfo(presentationData.strings.PtgSettings_EnableQuickReactionHelp))
    
    entries.append(.enableLiveText(presentationData.strings.PtgSettings_EnableLiveText, !experimentalSettings.disableImageContentAnalysis))
    entries.append(.enableLiveTextInfo(presentationData.strings.PtgSettings_EnableLiveTextHelp))

    entries.append(.defaultCameraForVideos(presentationData.strings.PtgSettings_DefaultCameraForVideos, settings.useRearCameraByDefault ? presentationData.strings.PtgSettings_DefaultCameraForVideos_Rear : presentationData.strings.PtgSettings_DefaultCameraForVideos_Front))
    
    if experimentalSettings.localTranscription {
        entries.append(.voiceToTextHeader(presentationData.strings.PtgSettings_VoiceToTextHeader.uppercased()))
        entries.append(.voiceToTextPremiumAccountsImplementation(presentationData.strings.PtgSettings_VoiceToTextPremiumAccountsImplmentation, ptgAccountSettings.preferAppleVoiceToText ? presentationData.strings.PtgSettings_VoiceToTextPremiumAccountsImplmentation_Apple : presentationData.strings.PtgSettings_VoiceToTextPremiumAccountsImplmentation_Telegram, hasPremiumAccounts))
        entries.append(.voiceToTextInfo(presentationData.strings.PtgSettings_VoiceToTextHelp))
    }
    
    return entries
}

public func ptgSettingsController(context: AccountContext) -> ViewController {
    let statePromise = Promise<PtgSettingsState>()
    statePromise.set(context.sharedContext.accountManager.transaction { transaction in
        return PtgSettingsState(settings: PtgSettings(transaction))
    })
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    
    let arguments = PtgSettingsControllerArguments(switchShowPeerId: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(showPeerId: value)
        }
    }, switchShowChannelCreationDate: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(showChannelCreationDate: value)
        }
    }, switchSuppressForeignAgentNotice: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(suppressForeignAgentNotice: value)
        }
    }, switchEnableLiveText: { value in
        let _ = context.sharedContext.accountManager.transaction({ transaction in
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                settings.disableImageContentAnalysis = !value
                return PreferencesEntry(settings)
            })
        }).start()
    }, changeVoiceToTextPremiumAccountsImplementation: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        
        for value in [false, true] {
            items.append(ActionSheetButtonItem(title: value ? presentationData.strings.PtgSettings_VoiceToTextPremiumAccountsImplmentation_Apple : presentationData.strings.PtgSettings_VoiceToTextPremiumAccountsImplmentation_Telegram, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let _ = updatePtgAccountSettings(engine: context.engine, { settings in
                    return settings.withUpdated(preferAppleVoiceToText: value)
                }).start()
            }))
        }
        
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        
        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, changeDefaultCameraForVideos: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        
        for value in [false, true] {
            items.append(ActionSheetButtonItem(title: value ? presentationData.strings.PtgSettings_DefaultCameraForVideos_Rear : presentationData.strings.PtgSettings_DefaultCameraForVideos_Front, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                updateSettings(context, statePromise) { settings in
                    return settings.withUpdated(useRearCameraByDefault: value)
                }
            }))
        }
        
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        
        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, switchEnableQuickReaction: { value in
        let _ = context.sharedContext.accountManager.transaction({ transaction in
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                settings.disableQuickReaction = !value
                return PreferencesEntry(settings)
            })
        }).start()
    }, switchHideReactionsInChannels: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(hideReactionsInChannels: value)
        }
    }, switchHideCommentsInChannels: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(hideCommentsInChannels: value)
        }
    }, switchHideShareButtonInChannels: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(hideShareButtonInChannels: value)
        }
    }, switchUseFullWidthInChannels: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(useFullWidthInChannels: value)
        }
    }, switchAddContextMenuSaveMessage: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(addContextMenuSaveMessage: value)
        }
    }, switchAddContextMenuShare: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(addContextMenuShare: value)
        }
    }, changeJumpToNextUnreadChannel: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        
        let values: [PtgSettings.JumpToNextUnreadChannel] = [.disabled, .topFirst, .bottomFirst]
        for value in values {
            items.append(ActionSheetButtonItem(title: jumpToNextUnreadChannelValueString(value, strings: presentationData.strings), color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                updateSettings(context, statePromise) { settings in
                    return settings.withUpdated(jumpToNextUnreadChannel: value)
                }
            }))
        }
        
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        
        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, switchHideSignatureInChannels: { value in
        updateSettings(context, statePromise) { settings in
            return settings.withUpdated(hideSignatureInChannels: value)
        }
    })
    
    let hasPremiumAccounts = combineLatest(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)), activeAccountsAndPeers(context: context))
    |> map { accountPeer, accountsAndPeers -> Bool in
        if accountPeer?.isPremium == true && !context.account.testingEnvironment {
            return true
        }
        for (accountContext, peer, _) in accountsAndPeers.1 {
            if peer.isPremium && !accountContext.account.testingEnvironment {
                return true
            }
        }
        return false
    }
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.experimentalUISettings]), hasPremiumAccounts, context.ptgAccountSettings)
    |> deliverOnMainQueue
    |> map { presentationData, state, sharedData, hasPremiumAccounts, ptgAccountSettings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let experimentalSettings: ExperimentalUISettings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PtgSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ptgSettingsControllerEntries(presentationData: presentationData, settings: state.settings, experimentalSettings: experimentalSettings, hasPremiumAccounts: hasPremiumAccounts, ptgAccountSettings: ptgAccountSettings), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    presentControllerImpl = { [weak controller] c, p in
        controller?.present(c, in: .window(.root), with: p)
    }
    
    return controller
}

private func jumpToNextUnreadChannelValueString(_ value: PtgSettings.JumpToNextUnreadChannel, strings: PresentationStrings) -> String {
    switch value {
    case .disabled:
        return strings.PtgSettings_JumpToNextUnreadChannel_Disabled
    case .topFirst:
        return strings.PtgSettings_JumpToNextUnreadChannel_TopFirst
    case .bottomFirst:
        return strings.PtgSettings_JumpToNextUnreadChannel_BottomFirst
    }
}

private func updateSettings(_ context: AccountContext, _ statePromise: Promise<PtgSettingsState>, _ f: @escaping (PtgSettings) -> PtgSettings) {
    let _ = (statePromise.get() |> take(1)).start(next: { [weak statePromise] state in
        let updatedSettings = f(state.settings)
        statePromise?.set(.single(state.withUpdatedSettings(updatedSettings)))
        
        let _ = context.sharedContext.accountManager.transaction({ transaction -> Void in
            transaction.updateSharedData(ApplicationSpecificSharedDataKeys.ptgSettings, { _ in
                return PreferencesEntry(updatedSettings)
            })
        }).start()
    })
}

extension PtgSettings {
    public func withUpdated(showPeerId: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(showChannelCreationDate: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(suppressForeignAgentNotice: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(useRearCameraByDefault: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(hideReactionsInChannels: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(hideCommentsInChannels: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(hideShareButtonInChannels: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(useFullWidthInChannels: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(addContextMenuSaveMessage: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(addContextMenuShare: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(jumpToNextUnreadChannel: JumpToNextUnreadChannel) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(hideSignatureInChannels: Bool) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: hideSignatureInChannels, testToolsEnabled: self.testToolsEnabled)
    }
    
    public func withUpdated(testToolsEnabled: Bool?) -> PtgSettings {
        return PtgSettings(showPeerId: self.showPeerId, showChannelCreationDate: self.showChannelCreationDate, suppressForeignAgentNotice: self.suppressForeignAgentNotice, useRearCameraByDefault: self.useRearCameraByDefault, hideReactionsInChannels: self.hideReactionsInChannels, hideCommentsInChannels: self.hideCommentsInChannels, hideShareButtonInChannels: self.hideShareButtonInChannels, useFullWidthInChannels: self.useFullWidthInChannels, addContextMenuSaveMessage: self.addContextMenuSaveMessage, addContextMenuShare: self.addContextMenuShare, jumpToNextUnreadChannel: self.jumpToNextUnreadChannel, hideSignatureInChannels: self.hideSignatureInChannels, testToolsEnabled: testToolsEnabled)
    }
}

extension PtgAccountSettings {
    public func withUpdated(ignoreAllContentRestrictions: Bool) -> PtgAccountSettings {
        return PtgAccountSettings(ignoreAllContentRestrictions: ignoreAllContentRestrictions, preferAppleVoiceToText: self.preferAppleVoiceToText)
    }
    
    public func withUpdated(preferAppleVoiceToText: Bool) -> PtgAccountSettings {
        return PtgAccountSettings(ignoreAllContentRestrictions: self.ignoreAllContentRestrictions, preferAppleVoiceToText: preferAppleVoiceToText)
    }
}

public func updatePtgAccountSettings(engine: TelegramEngine, _ f: @escaping (PtgAccountSettings) -> PtgAccountSettings) -> Signal<Never, NoError> {
    return engine.preferences.update(id: ApplicationSpecificPreferencesKeys.ptgAccountSettings, { entry in
        return PreferencesEntry(f(PtgAccountSettings(entry)))
    })
}
