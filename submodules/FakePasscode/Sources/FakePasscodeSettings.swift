import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import SwiftSignalKit
import TelegramStringFormatting
import AccountContext

public struct FakePasscodeSmsActionSettings: Codable, Equatable {
    public init() {

    }

    public init(from decoder: Decoder) throws {
        let _ = try decoder.container(keyedBy: StringCodingKey.self)

        // TODO Implement
    }

    public func encode(to encoder: Encoder) throws {
        var _ = encoder.container(keyedBy: StringCodingKey.self)

        // TODO Implement
    }
}


public struct FakePasscodeSettingsHolder: Codable, Equatable {  // TODO probably replace with some PartisanSettings structure, and put [FakePasscodeSettings] under it because PostboxDecoder cannot decode Arrays directly and we need some structure to hold it
    public let settings: [FakePasscodeSettings]
    public let fakePasscodeIndex: Int32
    public let activeFakePasscodeUuid: UUID?
    public let savedAccessChallenge: PostboxAccessChallengeData?

    public static var defaultSettings: FakePasscodeSettingsHolder {
        return FakePasscodeSettingsHolder(settings: [], fakePasscodeIndex: 0, activeFakePasscodeUuid: nil, savedAccessChallenge: nil)
    }

    public init(settings: [FakePasscodeSettings], fakePasscodeIndex: Int32, activeFakePasscodeUuid: UUID?, savedAccessChallenge: PostboxAccessChallengeData?) {
        self.settings = settings
        self.fakePasscodeIndex = fakePasscodeIndex
        self.activeFakePasscodeUuid = activeFakePasscodeUuid
        self.savedAccessChallenge = savedAccessChallenge
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.settings = try container.decode([FakePasscodeSettings].self, forKey: "afps")
        self.fakePasscodeIndex = try container.decodeIfPresent(Int32.self, forKey: "fpi") ?? 0
        self.activeFakePasscodeUuid = try UUID(uuidString: container.decodeIfPresent(String.self, forKey: "afpid") ?? "")
        self.savedAccessChallenge = try container.decodeIfPresent(PostboxAccessChallengeData.self, forKey: "sac")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.settings, forKey: "afps")
        try container.encode(self.fakePasscodeIndex, forKey: "fpi")
        try container.encodeIfPresent(self.activeFakePasscodeUuid?.uuidString, forKey: "afpid")
        try container.encodeIfPresent(self.savedAccessChallenge, forKey: "sac")
    }

    public init(_ entry: PreferencesEntry?) {
        self = entry?.get(FakePasscodeSettingsHolder.self) ?? .defaultSettings
    }

    public init(_ transaction: AccountManagerModifier<TelegramAccountManagerTypes>) {
        let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.fakePasscodeSettings)
        self.init(entry)
    }

    public func withAddedSettingsItem(_ item: FakePasscodeSettings) -> FakePasscodeSettingsHolder {
        assert(!self.settings.contains(where: { $0.uuid == item.uuid}))
        let newList = self.settings + [item]
        return FakePasscodeSettingsHolder(settings: newList, fakePasscodeIndex: self.fakePasscodeIndex + 1, activeFakePasscodeUuid: self.activeFakePasscodeUuid, savedAccessChallenge: self.savedAccessChallenge)
    }

    public func withDeletedSettingsItem(_ uuid: UUID) -> FakePasscodeSettingsHolder {
        assert(uuid != self.activeFakePasscodeUuid)
        assert(self.settings.contains(where: { $0.uuid == uuid}))
        let newList = self.settings.filter({ $0.uuid != uuid })
        return FakePasscodeSettingsHolder(settings: newList, fakePasscodeIndex: self.fakePasscodeIndex, activeFakePasscodeUuid: self.activeFakePasscodeUuid, savedAccessChallenge: self.savedAccessChallenge)
    }

    public func withUpdatedSettingsItem(_ item: FakePasscodeSettings) -> FakePasscodeSettingsHolder {
        if let ind = self.settings.firstIndex(where: { $0.uuid == item.uuid }) {
            var settings = self.settings
            settings[ind] = item
            return FakePasscodeSettingsHolder(settings: settings, fakePasscodeIndex: self.fakePasscodeIndex, activeFakePasscodeUuid: self.activeFakePasscodeUuid, savedAccessChallenge: self.savedAccessChallenge)
        } else {
            assertionFailure()
            return self
        }
    }

    public func withUpdatedAccessChallenge(_ accessChallenge: PostboxAccessChallengeData) -> FakePasscodeSettingsHolder {
        if let activeFakePasscodeUuid = self.activeFakePasscodeUuid {
            if let fakePasscodeItem = self.settings.first(where: { $0.uuid == activeFakePasscodeUuid }) {
                return self.withUpdatedSettingsItem(fakePasscodeItem.withUpdatedPasscode(accessChallenge.normalizedString()))
            } else {
                assertionFailure()
                return .defaultSettings
            }
        } else {
            return .defaultSettings
        }
    }

    public func unlockedWithFakePasscode() -> Bool {
        return activeFakePasscodeUuid != nil
    }
    
    public func activeFakePasscodeSettings() -> FakePasscodeSettings? {
        if let activeFakePasscodeUuid = self.activeFakePasscodeUuid {
            if let fakePasscodeItem = self.settings.first(where: { $0.uuid == activeFakePasscodeUuid }) {
                return fakePasscodeItem
            } else {
                assertionFailure()
            }
        }
        return nil
    }

    public func sessionFilter(account: Account) -> ((RecentAccountSession) -> Bool) {
        var sessionFilter: ((RecentAccountSession) -> Bool) = { _ in true }
        if unlockedWithFakePasscode() {
            let settings = getAccountActions(account: account)
            if settings.sessionsToHide.mode == .selected {
                sessionFilter = { !settings.sessionsToHide.sessions.contains($0.hash) || $0.hash == 0 }
            } else {
                sessionFilter = { settings.sessionsToHide.sessions.contains($0.hash) || $0.hash == 0 }
            }
        }
        return sessionFilter
    }

    public func getAccountActions(account: Account) -> FakePasscodeAccountActionsSettings {
        guard let settings = activeFakePasscodeSettings() else { return .defaultSettings(peerId: account.peerId, recordId: account.id) }
        return settings.accountActions.first(where: { $0.peerId == account.peerId && $0.recordId == account.id }) ?? .defaultSettings(peerId: account.peerId, recordId: account.id)
    }

    public func getAccountActions(_ uuid: UUID, _ account: Account) -> FakePasscodeAccountActionsSettings {
        let fakePasscodeSettings = self.settings.first(where: { $0.uuid == uuid })
        let settings = fakePasscodeSettings?.accountActions.first(where: { $0.peerId == account.peerId && $0.recordId == account.id }) ?? .defaultSettings(peerId: account.peerId, recordId: account.id)
        return settings;
    }
}

public struct FakePasscodeSettings: Codable, Equatable {
    public let uuid: UUID
    public let name: String
    public let passcode: String?
    public let allowLogin: Bool
    public let clearAfterActivation: Bool
    public let deleteOtherPasscodes: Bool
    public let activationMessage: String?
    public let activationAttempts: Int32
    public let smsActions: FakePasscodeSmsActionSettings?
    public let clearCache: Bool
    public let clearProxies: Bool
    public let accountActions: [FakePasscodeAccountActionsSettings]

    public init(name: String, passcode: String?) {
        self.init(uuid: UUID(), name: name, passcode: passcode, allowLogin: false, clearAfterActivation: false, deleteOtherPasscodes: false, activationMessage: nil, activationAttempts: -1, smsActions: FakePasscodeSmsActionSettings(), clearCache: false, clearProxies: false, accountActions: [])
    }

    public init(uuid: UUID, name: String, passcode: String?, allowLogin: Bool, clearAfterActivation: Bool, deleteOtherPasscodes: Bool, activationMessage: String?, activationAttempts: Int32, smsActions: FakePasscodeSmsActionSettings?, clearCache: Bool, clearProxies: Bool, accountActions: [FakePasscodeAccountActionsSettings]) {
        self.uuid = uuid
        self.name = name
        self.passcode = passcode
        self.allowLogin = allowLogin
        self.clearAfterActivation = clearAfterActivation
        self.deleteOtherPasscodes = deleteOtherPasscodes
        self.activationMessage = activationMessage
        self.activationAttempts = activationAttempts
        self.smsActions = smsActions
        self.clearCache = clearCache
        self.clearProxies = clearProxies
        self.accountActions = accountActions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.uuid = try UUID(uuidString: container.decode(String.self, forKey: "uuid"))!
        self.name = try container.decode(String.self, forKey: "n")
        self.passcode = try container.decodeIfPresent(String.self, forKey: "pass")
        self.allowLogin = (try container.decode(Int32.self, forKey: "al")) != 0
        self.clearAfterActivation = (try container.decode(Int32.self, forKey: "caa")) != 0
        self.deleteOtherPasscodes = (try container.decode(Int32.self, forKey: "dop")) != 0
        self.activationMessage = (try container.decodeIfPresent(String.self, forKey: "am"))
        self.activationAttempts = try container.decode(Int32.self, forKey: "bpa")
        self.smsActions = try container.decodeIfPresent(FakePasscodeSmsActionSettings.self, forKey: "fps")
        self.clearCache = (try container.decode(Int32.self, forKey: "cc")) != 0
        self.clearProxies = (try container.decode(Int32.self, forKey: "cp")) != 0
        self.accountActions = try container.decodeIfPresent([FakePasscodeAccountActionsSettings].self, forKey: "aa") ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.uuid.uuidString, forKey: "uuid")
        try container.encode(self.name, forKey: "n")
        try container.encodeIfPresent(self.passcode, forKey: "pass")
        try container.encode((self.allowLogin ? 1 : 0) as Int32, forKey: "al")
        try container.encode((self.clearAfterActivation ? 1 : 0) as Int32, forKey: "caa")
        try container.encode((self.deleteOtherPasscodes ? 1 : 0) as Int32, forKey: "dop")
        try container.encodeIfPresent(self.activationMessage, forKey: "am")
        try container.encodeIfPresent(self.activationAttempts, forKey: "bpa")
        try container.encodeIfPresent(self.smsActions, forKey: "fps")
        try container.encode((self.clearCache ? 1 : 0) as Int32, forKey: "cc")
        try container.encode((self.clearProxies ? 1 : 0) as Int32, forKey: "cp")
        try container.encode(self.accountActions, forKey: "aa")
    }

    public func withUpdatedPasscode(_ passcode: String?) -> FakePasscodeSettings {
        return FakePasscodeSettings(uuid: self.uuid, name: self.name, passcode: passcode, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedName(_ name: String) -> FakePasscodeSettings {
        return FakePasscodeSettings(uuid: self.uuid, name: name, passcode: self.passcode, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedAllowLogin(_ allowLogin: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(uuid: self.uuid, name: self.name, passcode: self.passcode, allowLogin: allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedClearAfterActivation(_ clearAfterActivation: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(uuid: self.uuid, name: self.name, passcode: self.passcode, allowLogin: self.allowLogin, clearAfterActivation: clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedDeleteOtherPasscodes(_ deleteOtherPasscodes: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(uuid: self.uuid, name: self.name, passcode: self.passcode, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedActivationMessage(_ activationMessage: String) -> FakePasscodeSettings {
        return FakePasscodeSettings(uuid: self.uuid, name: self.name, passcode: self.passcode, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedBadPasscodeActivation(_ activationAttempts: Int32) -> FakePasscodeSettings {
        return FakePasscodeSettings(uuid: self.uuid, name: self.name, passcode: self.passcode, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedSms(_ smsActions: FakePasscodeSmsActionSettings?) -> FakePasscodeSettings {
        return FakePasscodeSettings(uuid: self.uuid, name: self.name, passcode: self.passcode, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: self.deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedClearCache(_ clearCache: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(uuid: self.uuid, name: self.name, passcode: self.passcode, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: clearCache, clearProxies: self.clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedClearProxies(_ clearProxies: Bool) -> FakePasscodeSettings {
        return FakePasscodeSettings(uuid: self.uuid, name: self.name, passcode: self.passcode, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: clearProxies, accountActions: self.accountActions)
    }

    public func withUpdatedAccountActions(_ accountActions: [FakePasscodeAccountActionsSettings]) -> FakePasscodeSettings {
        return FakePasscodeSettings(uuid: self.uuid, name: self.name, passcode: self.passcode, allowLogin: self.allowLogin, clearAfterActivation: self.clearAfterActivation, deleteOtherPasscodes: deleteOtherPasscodes, activationMessage: self.activationMessage, activationAttempts: self.activationAttempts, smsActions: self.smsActions, clearCache: self.clearCache, clearProxies: self.clearProxies, accountActions: accountActions)
    }
    
    public func withUpdatedAccountActionItem(_ accountAction: FakePasscodeAccountActionsSettings) -> FakePasscodeSettings {
        return withUpdatedAccountActions(self.accountActions.filter({ $0.peerId != accountAction.peerId }) + [accountAction])
    }
    
    public func activate(sharedAccountContext: SharedAccountContext, beforeUnlockTaskCounter: PendingTaskCounter) {
        beforeUnlockTaskCounter.increment()
        let _ = (sharedAccountContext.activeAccountContexts
        |> take(1)).start(next: { activeAccounts in
            let currentAccountId = activeAccounts.primary?.account.id
            for (_, context, _) in activeAccounts.accounts.sorted(by: { lhs, rhs in
                if lhs.0 == currentAccountId {
                    return true
                }
                if rhs.0 == currentAccountId {
                    return false
                }
                return lhs.2 < rhs.2
            }) {
                if let accountAction = accountActions.first(where: { $0.peerId == context.account.peerId && $0.recordId == context.account.id }) {
                    accountAction.performActions(context: context, isCurrentAccount: context.account.id == currentAccountId, beforeUnlockTaskCounter: beforeUnlockTaskCounter, updateSettings: { updatedSettings in
                        let _ = updateFakePasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, { holder in
                            return holder.withUpdatedSettingsItem(holder.settings.first(where: { $0.uuid == self.uuid })!.withUpdatedAccountActionItem(updatedSettings))
                        }).start()
                    })
                }
            }
            beforeUnlockTaskCounter.decrement()
        })
    }
}

public func updateFakePasscodeSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (FakePasscodeSettingsHolder) -> FakePasscodeSettingsHolder) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        updateFakePasscodeSettingsInternal(transaction: transaction, f)
    }
}

public func updateFakePasscodeSettingsInternal(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, _ f: @escaping (FakePasscodeSettingsHolder) -> FakePasscodeSettingsHolder) {
    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.fakePasscodeSettings, { entry in
        let currentSettings = FakePasscodeSettingsHolder(entry)
        return PreferencesEntry(f(currentSettings))
    })
}

public protocol ReactiveToPasscodeSwitch {
    func passcodeSwitched()
}

extension PostboxAccessChallengeData {
    public init(passcode: String, numerical: Bool) {
        if numerical {
            self = .numericalPassword(value: passcode)
        } else {
            self = .plaintextPassword(value: passcode)
        }
    }
    
    public func normalizedString() -> String? {
        switch self {
            case .none:
                return nil
            case let .numericalPassword(code):
                return normalizeArabicNumeralString(code, type: .western)
            case let .plaintextPassword(code):
                return code
        }
    }
}

public func ptgCheckPasscode(passcode: String,
                             secondaryUnlock: Bool,
                             accessChallenge: PostboxAccessChallengeData,
                             fakePasscodeHolder: FakePasscodeSettingsHolder) -> (Bool, PostboxAccessChallengeData?, FakePasscodeSettingsHolder?) {
    if let activeFakePasscodeUuid = fakePasscodeHolder.activeFakePasscodeUuid {
        if let fakePasscodeItem = fakePasscodeHolder.settings.first(where: { $0.uuid == activeFakePasscodeUuid }) {
            if passcode == fakePasscodeItem.passcode {
                return (true, nil, nil)
            }
        } else {
            assertionFailure()
        }

        if let savedAccessChallenge = fakePasscodeHolder.savedAccessChallenge {
            if !secondaryUnlock && passcode == savedAccessChallenge.normalizedString() {
                let updatedFakePasscodeSettingsHolder = FakePasscodeSettingsHolder(settings: fakePasscodeHolder.settings, fakePasscodeIndex: fakePasscodeHolder.fakePasscodeIndex, activeFakePasscodeUuid: nil, savedAccessChallenge: nil)
                return (true, savedAccessChallenge, updatedFakePasscodeSettingsHolder)
            }
        } else {
            assertionFailure()
        }
    } else {
        if passcode == accessChallenge.normalizedString() {
            return (true, nil, nil)
        }
    }

    if !secondaryUnlock,
       let fakePasscodeItem = fakePasscodeHolder.settings.first(where: { passcode == $0.passcode }) {
        let updatedFakePasscodeSettingsHolder = FakePasscodeSettingsHolder(settings: fakePasscodeHolder.settings, fakePasscodeIndex: fakePasscodeHolder.fakePasscodeIndex, activeFakePasscodeUuid: fakePasscodeItem.uuid, savedAccessChallenge: fakePasscodeHolder.unlockedWithFakePasscode() ? fakePasscodeHolder.savedAccessChallenge : accessChallenge)
        return (true, nil, updatedFakePasscodeSettingsHolder)
    }

    return (false, nil, nil)
}