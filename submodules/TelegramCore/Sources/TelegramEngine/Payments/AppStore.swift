import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public enum AssignAppStoreTransactionError {
    case generic
    case timeout
    case serverProvided
}

public enum AppStoreTransactionPurpose {
    case subscription
    case upgrade
    case restore
    case gift(peerId: EnginePeer.Id, currency: String, amount: Int64)
    case giftCode(peerIds: [EnginePeer.Id], boostPeer: EnginePeer.Id?, currency: String, amount: Int64)
    case giveaway(boostPeer: EnginePeer.Id, additionalPeerIds: [EnginePeer.Id], countries: [String], onlyNewSubscribers: Bool, showWinners: Bool, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64)
}

private func apiInputStorePaymentPurpose(account: Account, purpose: AppStoreTransactionPurpose) -> Signal<Api.InputStorePaymentPurpose, NoError> {
    switch purpose {
    case .subscription, .upgrade, .restore:
        var flags: Int32 = 0
        switch purpose {
        case .upgrade:
            flags |= (1 << 1)
        case .restore:
            flags |= (1 << 0)
        default:
            break
        }
        return .single(.inputStorePaymentPremiumSubscription(flags: flags))
    case let .gift(peerId, currency, amount):
        return  account.postbox.loadedPeerWithId(peerId)
        |> mapToSignal { peer -> Signal<Api.InputStorePaymentPurpose, NoError> in
            guard let inputUser = apiInputUser(peer) else {
                return .complete()
            }
            return .single(.inputStorePaymentGiftPremium(userId: inputUser, currency: currency, amount: amount))
        }
    case let .giftCode(peerIds, boostPeerId, currency, amount):
        return account.postbox.transaction { transaction -> Api.InputStorePaymentPurpose in
            var flags: Int32 = 0
            var apiBoostPeer: Api.InputPeer?
            var apiInputUsers: [Api.InputUser] = []
            
            for peerId in peerIds {
                if let user = transaction.getPeer(peerId), let apiUser = apiInputUser(user) {
                    apiInputUsers.append(apiUser)
                }
            }
            
            if let boostPeerId = boostPeerId, let boostPeer = transaction.getPeer(boostPeerId), let apiPeer = apiInputPeer(boostPeer) {
                apiBoostPeer = apiPeer
                flags |= (1 << 0)
            }
   
            return .inputStorePaymentPremiumGiftCode(flags: flags, users: apiInputUsers, boostPeer: apiBoostPeer, currency: currency, amount: amount)
        }
    case let .giveaway(boostPeerId, additionalPeerIds, countries, onlyNewSubscribers, showWinners, prizeDescription, randomId, untilDate, currency, amount):
        return account.postbox.transaction { transaction -> Signal<Api.InputStorePaymentPurpose, NoError> in
            guard let peer = transaction.getPeer(boostPeerId), let apiBoostPeer = apiInputPeer(peer) else {
                return .complete()
            }
            var flags: Int32 = 0
            if onlyNewSubscribers {
                flags |= (1 << 0)
            }
            if showWinners {
                flags |= (1 << 3)
            }
            var additionalPeers: [Api.InputPeer] = []
            if !additionalPeerIds.isEmpty {
                flags |= (1 << 1)
                for peerId in additionalPeerIds {
                    if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                        additionalPeers.append(inputPeer)
                    }
                }
            }
            if !countries.isEmpty {
                flags |= (1 << 2)
            }
            if let _ = prizeDescription {
                flags |= (1 << 4)
            }
            return .single(.inputStorePaymentPremiumGiveaway(flags: flags, boostPeer: apiBoostPeer, additionalPeers: additionalPeers, countriesIso2: countries, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate, currency: currency, amount: amount))
        }
        |> switchToLatest
    }
}

func _internal_sendAppStoreReceipt(account: Account, receipt: Data, purpose: AppStoreTransactionPurpose) -> Signal<Never, AssignAppStoreTransactionError> {
    return apiInputStorePaymentPurpose(account: account, purpose: purpose)
    |> castError(AssignAppStoreTransactionError.self)
    |> mapToSignal { purpose -> Signal<Never, AssignAppStoreTransactionError> in
        return account.network.request(Api.functions.payments.assignAppStoreTransaction(receipt: Buffer(data: receipt), purpose: purpose))
        |> mapError { error -> AssignAppStoreTransactionError in
            if error.errorCode == 406 {
                return .serverProvided
            } else {
                return .generic
            }
        }
        |> mapToSignal { updates -> Signal<Never, AssignAppStoreTransactionError> in
            account.stateManager.addUpdates(updates)
            return .complete()
        }
    }
}

public enum RestoreAppStoreReceiptError {
    case generic
}

func _internal_canPurchasePremium(account: Account, purpose: AppStoreTransactionPurpose) -> Signal<Bool, NoError> {
    return apiInputStorePaymentPurpose(account: account, purpose: purpose)
    |> mapToSignal { purpose -> Signal<Bool, NoError> in
        return account.network.request(Api.functions.payments.canPurchasePremium(purpose: purpose))
        |> map { result -> Bool in
            switch result {
                case .boolTrue:
                    return true
                case .boolFalse:
                    return false
            }
        }
        |> `catch` { _ -> Signal<Bool, NoError> in
            return .single(false)
        }
    }
}
