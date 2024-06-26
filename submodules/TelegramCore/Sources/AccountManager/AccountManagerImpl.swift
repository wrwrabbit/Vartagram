import Foundation
import SwiftSignalKit
import Postbox

public protocol AccountManagerTypes {
    associatedtype Attribute: AccountRecordAttribute
}

public typealias SharedPreferencesEntry = PreferencesEntry

public struct AccountManagerModifier<Types: AccountManagerTypes> {
    public let getRecords: (Set<AccountRecordId>) -> [AccountRecord<Types.Attribute>]
    public let updateRecord: (AccountRecordId, (AccountRecord<Types.Attribute>?) -> (AccountRecord<Types.Attribute>?)) -> Void
    public let getCurrent: (Set<AccountRecordId>) -> (AccountRecordId, [Types.Attribute])?
    public let setCurrentId: (AccountRecordId) -> Void
    public let getCurrentAuth: () -> AuthAccountRecord<Types.Attribute>?
    public let createAuth: ([Types.Attribute]) -> AuthAccountRecord<Types.Attribute>?
    public let removeAuth: () -> Void
    public let createRecord: ([Types.Attribute]) -> AccountRecordId
    public let getSharedData: (ValueBoxKey) -> PreferencesEntry?
    public let updateSharedData: (ValueBoxKey, (PreferencesEntry?) -> PreferencesEntry?) -> Void
    public let getAccessChallengeData: () -> PostboxAccessChallengeData
    public let setAccessChallengeData: (PostboxAccessChallengeData) -> Void
    public let getVersion: () -> Int32?
    public let setVersion: (Int32) -> Void
    public let getNotice: (NoticeEntryKey) -> CodableEntry?
    public let setNotice: (NoticeEntryKey, CodableEntry?) -> Void
    public let clearNotices: () -> Void
    public let getStoredLoginTokens: () -> [Data]
    public let setStoredLoginTokens: ([Data]) -> Void
}

final class AccountManagerImpl<Types: AccountManagerTypes> {
    private let queue: Queue
    private let basePath: String
    private let atomicStatePath: String
    private let loginTokensPath: String
    private let temporarySessionId: Int64
    private let guardValueBox: ValueBox?
    private let valueBox: ValueBox
    
    private var tables: [Table] = []
    
    private var currentAtomicState: AccountManagerAtomicState<Types>
    private var currentAtomicStateUpdated = false
    
    private let legacyMetadataTable: AccountManagerMetadataTable<Types.Attribute>
    private let legacyRecordTable: AccountManagerRecordTable<Types.Attribute>
    
    let sharedDataTable: AccountManagerSharedDataTable
    let noticeTable: NoticeTable
    
    private var currentRecordOperations: [AccountManagerRecordOperation<Types.Attribute>] = []
    private var currentMetadataOperations: [AccountManagerMetadataOperation<Types.Attribute>] = []
    
    private var currentUpdatedSharedDataKeys = Set<ValueBoxKey>()
    private var currentUpdatedNoticeEntryKeys = Set<NoticeEntryKey>()
    private var currentUpdatedAccessChallengeData: PostboxAccessChallengeData?
    
    private var recordsViews = Bag<(MutableAccountRecordsView<Types>, ValuePipe<AccountRecordsView<Types>>)>()
    
    private var sharedDataViews = Bag<(MutableAccountSharedDataView<Types>, ValuePipe<AccountSharedDataView<Types>>)>()
    private var noticeEntryViews = Bag<(MutableNoticeEntryView<Types>, ValuePipe<NoticeEntryView<Types>>)>()
    private var accessChallengeDataViews = Bag<(MutableAccessChallengeDataView, ValuePipe<AccessChallengeDataView>)>()
    
    private var queuedInternalTransactions = Atomic<[() -> Void]>(value: [])
    
    static func getCurrentRecords(basePath: String, excludeAccountIds: Set<AccountRecordId>) -> (records: [AccountRecord<Types.Attribute>], currentId: AccountRecordId?) {
        let atomicStatePath = "\(basePath)/atomic-state"
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: atomicStatePath))
            let atomicState = try JSONDecoder().decode(AccountManagerAtomicState<Types>.self, from: data)
            
            let records = atomicState.records.sorted(by: { $0.key.int64 < $1.key.int64 }).map({ $1 })
                .filter { !excludeAccountIds.contains($0.id) }
            
            var currentRecordId = atomicState.currentRecordId
            if let id = currentRecordId, excludeAccountIds.contains(id) {
                currentRecordId = records.sorted(by: { $0 < $1 }).first?.id
            }
            
            return (records, currentRecordId)
        } catch let e {
            postboxLog("decode atomic state error: \(e)")
            postboxLogSync()
            if FileManager.default.fileExists(atPath: atomicStatePath) {
                preconditionFailure()
            } else {
                // it is possible in app extension before first app launch
                return ([], nil)
            }
        }
    }
    
    fileprivate init?(queue: Queue, basePath: String, isTemporary: Bool, isReadOnly: Bool, useCaches: Bool, removeDatabaseOnError: Bool, temporarySessionId: Int64) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        self.queue = queue
        self.basePath = basePath
        self.atomicStatePath = "\(basePath)/atomic-state"
        self.loginTokensPath = "\(basePath)/login-tokens"
        self.temporarySessionId = temporarySessionId
        let _ = try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)
        guard let guardValueBox = SqliteValueBox(basePath: basePath + "/guard_db", queue: queue, isTemporary: isTemporary, isReadOnly: false, useCaches: useCaches, removeDatabaseOnError: removeDatabaseOnError, encryptionParameters: nil, upgradeProgress: { _ in }) else {
            postboxLog("Could not open guard value box at \(basePath + "/guard_db")")
            postboxLogSync()
            preconditionFailure()
            return nil
        }
        self.guardValueBox = guardValueBox
        
        var valueBox: SqliteValueBox?
        for i in 0 ..< 3 {
            if let valueBoxValue = SqliteValueBox(basePath: basePath + "/db", queue: queue, isTemporary: isTemporary, isReadOnly: isReadOnly, useCaches: useCaches, removeDatabaseOnError: removeDatabaseOnError, encryptionParameters: nil, upgradeProgress: { _ in }) {
                valueBox = valueBoxValue
                break
            } else {
                postboxLog("Could not open value box at \(basePath + "/db") (try \(i))")
                postboxLogSync()
                
                Thread.sleep(forTimeInterval: 0.1 + 0.5 * Double(i))
            }
        }
        guard let valueBox = valueBox else {
            postboxLog("Giving up on opening value box at \(basePath + "/db")")
            postboxLogSync()
            preconditionFailure()
        }
        self.valueBox = valueBox
        
        self.legacyMetadataTable = AccountManagerMetadataTable<Types.Attribute>(valueBox: self.valueBox, table: AccountManagerMetadataTable<Types.Attribute>.tableSpec(0), useCaches: useCaches)
        self.legacyRecordTable = AccountManagerRecordTable<Types.Attribute>(valueBox: self.valueBox, table: AccountManagerRecordTable<Types.Attribute>.tableSpec(1), useCaches: useCaches)
        self.sharedDataTable = AccountManagerSharedDataTable(valueBox: self.valueBox, table: AccountManagerSharedDataTable.tableSpec(2), useCaches: useCaches)
        self.noticeTable = NoticeTable(valueBox: self.valueBox, table: NoticeTable.tableSpec(3), useCaches: useCaches)
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: self.atomicStatePath))
            do {
                let atomicState = try JSONDecoder().decode(AccountManagerAtomicState<Types>.self, from: data)
                self.currentAtomicState = atomicState
            } catch let e {
                postboxLog("decode atomic state error: \(e)")
                postboxLogSync()
                
                if removeDatabaseOnError {
                    let _ = try? FileManager.default.removeItem(atPath: self.atomicStatePath)
                }
                preconditionFailure()
            }
        } catch let e {
            postboxLog("load atomic state error: \(e)")
            postboxLogSync()
            
            if removeDatabaseOnError {
                var legacyRecordDict: [AccountRecordId: AccountRecord<Types.Attribute>] = [:]
                for record in self.legacyRecordTable.getRecords() {
                    legacyRecordDict[record.id] = record
                }
                self.currentAtomicState = AccountManagerAtomicState(records: legacyRecordDict, currentRecordId: self.legacyMetadataTable.getCurrentAccountId(), currentAuthRecord: self.legacyMetadataTable.getCurrentAuthAccount(), accessChallengeData: self.legacyMetadataTable.getAccessChallengeData())
                self.syncAtomicStateToFile()
            } else {
                if FileManager.default.fileExists(atPath: self.atomicStatePath) {
                    preconditionFailure()
                } else {
                    // it is possible in app extension before first app launch
                    self.currentAtomicState = AccountManagerAtomicState()
                }
            }
        }
        
        let tableAccessChallengeData = self.legacyMetadataTable.getAccessChallengeData()
        if self.currentAtomicState.accessChallengeData != .none {
            if tableAccessChallengeData == .none {
                self.legacyMetadataTable.setAccessChallengeData(self.currentAtomicState.accessChallengeData)
            }
        } else if tableAccessChallengeData != .none {
            self.currentAtomicState.accessChallengeData = tableAccessChallengeData
            self.syncAtomicStateToFile()
        }
        
        postboxLog("AccountManager: currentAccountId = \(String(describing: currentAtomicState.currentRecordId))")
        
        self.tables.append(self.legacyMetadataTable)
        self.tables.append(self.legacyRecordTable)
        self.tables.append(self.sharedDataTable)
        self.tables.append(self.noticeTable)
        
        postboxLog("AccountManager initialization took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }

    fileprivate func transactionSync<T>(ignoreDisabled: Bool, _ f: (AccountManagerModifier<Types>) -> T) -> T {
        self.valueBox.begin()

        let transaction = AccountManagerModifier<Types>(getRecords: { excludeAccountIds in
            return self.currentAtomicState.records.map { $0.1 }
                .filter { !excludeAccountIds.contains($0.id) }
        }, updateRecord: { id, update in
            let current = self.currentAtomicState.records[id]
            let updated = update(current)
            if updated != current {
                if let updated = updated {
                    self.currentAtomicState.records[id] = updated
                } else {
                    self.currentAtomicState.records.removeValue(forKey: id)
                }
                self.currentAtomicStateUpdated = true
                self.currentRecordOperations.append(.set(id: id, record: updated))
            }
        }, getCurrent: { excludeAccountIds in
            if let id = self.currentAtomicState.currentRecordId, let record = self.currentAtomicState.records[id] {
                if !excludeAccountIds.contains(record.id) {
                    return (record.id, record.attributes)
                } else {
                    let records = self.currentAtomicState.records.map { $0.1 }
                        .filter { !excludeAccountIds.contains($0.id) }
                        .sorted { $0 < $1 }
                    return records.first.flatMap { ($0.id, $0.attributes) }
                }
            } else {
                return nil
            }
        }, setCurrentId: { id in
            self.currentAtomicState.currentRecordId = id
            self.currentMetadataOperations.append(.updateCurrentAccountId(id))
            self.currentAtomicStateUpdated = true
        }, getCurrentAuth: {
            if let record = self.currentAtomicState.currentAuthRecord {
                return record
            } else {
                return nil
            }
        }, createAuth: { attributes in
            let record = AuthAccountRecord<Types.Attribute>(id: generateAccountRecordId(), attributes: attributes)
            self.currentAtomicState.currentAuthRecord = record
            self.currentAtomicStateUpdated = true
            self.currentMetadataOperations.append(.updateCurrentAuthAccountRecord(record))
            return record
        }, removeAuth: {
            self.currentAtomicState.currentAuthRecord = nil
            self.currentMetadataOperations.append(.updateCurrentAuthAccountRecord(nil))
            self.currentAtomicStateUpdated = true
        }, createRecord: { attributes in
            let id = generateAccountRecordId()
            let record = AccountRecord<Types.Attribute>(id: id, attributes: attributes, temporarySessionId: nil)
            self.currentAtomicState.records[id] = record
            self.currentRecordOperations.append(.set(id: id, record: record))
            self.currentAtomicStateUpdated = true
            return id
        }, getSharedData: { key in
            return self.sharedDataTable.get(key: key)
        }, updateSharedData: { key, f in
            let updated = f(self.sharedDataTable.get(key: key))
            self.sharedDataTable.set(key: key, value: updated, updatedKeys: &self.currentUpdatedSharedDataKeys)
        }, getAccessChallengeData: {
            return self.legacyMetadataTable.getAccessChallengeData()
        }, setAccessChallengeData: { data in
            self.currentUpdatedAccessChallengeData = data
            self.currentAtomicStateUpdated = true
            self.legacyMetadataTable.setAccessChallengeData(data)
            self.currentAtomicState.accessChallengeData = data
        }, getVersion: {
            return self.legacyMetadataTable.getVersion()
        }, setVersion: { version in
            self.legacyMetadataTable.setVersion(version)
        }, getNotice: { key in
            self.noticeTable.get(key: key)
        }, setNotice: { key, value in
            self.noticeTable.set(key: key, value: value)
            self.currentUpdatedNoticeEntryKeys.insert(key)
        }, clearNotices: {
            self.noticeTable.clear()
        }, getStoredLoginTokens: {
            return self.getLoginTokens()
        }, setStoredLoginTokens: { list in
            self.setLoginTokens(list: list)
        })

        let result = f(transaction)

        self.beforeCommit()

        self.valueBox.commit()

        return result
    }
    
    fileprivate func transaction<T>(ignoreDisabled: Bool, _ f: @escaping (AccountManagerModifier<Types>) -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            self.queue.justDispatch {
                self.beginInternalTransaction(ignoreDisabled: ignoreDisabled, {
                    let result = self.transactionSync(ignoreDisabled: ignoreDisabled, f)
                    
                    subscriber.putNext(result)
                    subscriber.putCompletion()
                })
            }
            return EmptyDisposable
        }
    }
    
    private func syncAtomicStateToFile() {
        if let data = try? JSONEncoder().encode(self.currentAtomicState) {
            if let _ = try? data.write(to: URL(fileURLWithPath: self.atomicStatePath), options: [.atomic]) {
            } else {
                postboxLogSync()
                preconditionFailure()
            }
        } else {
            postboxLogSync()
            preconditionFailure()
        }
    }
    
    private func getLoginTokens() -> [Data] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: self.loginTokensPath)) else {
            return []
        }
        guard let list = try? JSONDecoder().decode([Data].self, from: data) else {
            return []
        }
        return list
    }
    
    private func setLoginTokens(list: [Data]) {
        if let data = try? JSONEncoder().encode(list) {
            if let _ = try? data.write(to: URL(fileURLWithPath: self.loginTokensPath), options: [.atomic]) {
            }
        }
    }
    
    private func beforeCommit() {
        if self.currentAtomicStateUpdated {
            self.syncAtomicStateToFile()
        }
        
        if !self.currentRecordOperations.isEmpty || !self.currentMetadataOperations.isEmpty {
            for (view, pipe) in self.recordsViews.copyItems() {
                if view.replay(operations: self.currentRecordOperations, metadataOperations: self.currentMetadataOperations) {
                    pipe.putNext(AccountRecordsView<Types>(view))
                }
            }
        }
        
        if !self.currentUpdatedSharedDataKeys.isEmpty {
            for (view, pipe) in self.sharedDataViews.copyItems() {
                if view.replay(accountManagerImpl: self, updatedKeys: self.currentUpdatedSharedDataKeys) {
                    pipe.putNext(AccountSharedDataView<Types>(view))
                }
            }
        }
        
        if !self.currentUpdatedNoticeEntryKeys.isEmpty {
            for (view, pipe) in self.noticeEntryViews.copyItems() {
                if view.replay(accountManagerImpl: self, updatedKeys: self.currentUpdatedNoticeEntryKeys) {
                    pipe.putNext(NoticeEntryView(view))
                }
            }
        }
        
        if let data = self.currentUpdatedAccessChallengeData {
            for (view, pipe) in self.accessChallengeDataViews.copyItems() {
                if view.replay(updatedData: data) {
                    pipe.putNext(AccessChallengeDataView(view))
                }
            }
        }
        
        self.currentRecordOperations.removeAll()
        self.currentMetadataOperations.removeAll()
        self.currentUpdatedSharedDataKeys.removeAll()
        self.currentUpdatedNoticeEntryKeys.removeAll()
        self.currentUpdatedAccessChallengeData = nil
        self.currentAtomicStateUpdated = false
        
        for table in self.tables {
            table.beforeCommit()
        }
    }
    
    fileprivate func accountRecords(excludeAccountIds: Signal<Set<AccountRecordId>, NoError>) -> Signal<AccountRecordsView<Types>, NoError> {
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<AccountRecordsView<Types>, NoError> in
            return self.accountRecordsInternal(transaction: transaction, excludeAccountIds: excludeAccountIds)
        })
        |> switchToLatest
    }

    fileprivate func _internalAccountRecordsSync(excludeAccountIds: Set<AccountRecordId>) -> AccountRecordsView<Types> {
        let mutableView = MutableAccountRecordsView<Types>(getRecords: {
            return self.currentAtomicState.records.map { $0.1 }
        }, currentId: self.currentAtomicState.currentRecordId, currentAuth: self.currentAtomicState.currentAuthRecord, excludeAccountIds: excludeAccountIds)
        return AccountRecordsView<Types>(mutableView)
    }
    
    fileprivate func sharedData(keys: Set<ValueBoxKey>) -> Signal<AccountSharedDataView<Types>, NoError> {
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<AccountSharedDataView<Types>, NoError> in
            return self.sharedDataInternal(transaction: transaction, keys: keys)
        })
        |> switchToLatest
    }
    
    fileprivate func noticeEntry(key: NoticeEntryKey) -> Signal<NoticeEntryView<Types>, NoError> {
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<NoticeEntryView<Types>, NoError> in
            return self.noticeEntryInternal(transaction: transaction, key: key)
        })
        |> switchToLatest
    }
    
    fileprivate func accessChallengeData() -> Signal<AccessChallengeDataView, NoError> {
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<AccessChallengeDataView, NoError> in
            return self.accessChallengeDataInternal(transaction: transaction)
        })
        |> switchToLatest
    }
    
    private func accountRecordsInternal(transaction: AccountManagerModifier<Types>, excludeAccountIds: Signal<Set<AccountRecordId>, NoError>) -> Signal<AccountRecordsView<Types>, NoError> {
        return excludeAccountIds
        |> deliverOn(self.queue)
        |> mapToSignal { excludeAccountIds in
            assert(self.queue.isCurrent())
            let mutableView = MutableAccountRecordsView<Types>(getRecords: {
                return self.currentAtomicState.records.map { $0.1 }
            }, currentId: self.currentAtomicState.currentRecordId, currentAuth: self.currentAtomicState.currentAuthRecord, excludeAccountIds: excludeAccountIds)
            let pipe = ValuePipe<AccountRecordsView<Types>>()
            let index = self.recordsViews.add((mutableView, pipe))
            
            let queue = self.queue
            return (.single(AccountRecordsView<Types>(mutableView))
            |> then(pipe.signal()))
            |> `catch` { _ -> Signal<AccountRecordsView<Types>, NoError> in
            }
            |> afterDisposed { [weak self] in
                queue.async {
                    if let strongSelf = self {
                        strongSelf.recordsViews.remove(index)
                    }
                }
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.currentRecord != rhs.currentRecord {
                return false
            }
            if lhs.records != rhs.records {
                return false
            }
            if let lhs = lhs.currentAuthAccount, let rhs = rhs.currentAuthAccount {
                if lhs.id != rhs.id {
                    return false
                }
                if lhs.attributes.count != rhs.attributes.count {
                    return false
                }
                for i in 0 ..< lhs.attributes.count {
                    if !lhs.attributes[i].isEqual(to: rhs.attributes[i]) {
                        return false
                    }
                }
            } else if lhs.currentAuthAccount != nil || rhs.currentAuthAccount != nil {
                return false
            }
            return true
        })
    }
    
    private func sharedDataInternal(transaction: AccountManagerModifier<Types>, keys: Set<ValueBoxKey>) -> Signal<AccountSharedDataView<Types>, NoError> {
        let mutableView = MutableAccountSharedDataView<Types>(accountManagerImpl: self, keys: keys)
        let pipe = ValuePipe<AccountSharedDataView<Types>>()
        let index = self.sharedDataViews.add((mutableView, pipe))
        
        let queue = self.queue
        return (.single(AccountSharedDataView<Types>(mutableView))
        |> then(pipe.signal()))
        |> `catch` { _ -> Signal<AccountSharedDataView<Types>, NoError> in
        }
        |> afterDisposed { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.sharedDataViews.remove(index)
                }
            }
        }
    }
    
    private func noticeEntryInternal(transaction: AccountManagerModifier<Types>, key: NoticeEntryKey) -> Signal<NoticeEntryView<Types>, NoError> {
        let mutableView = MutableNoticeEntryView<Types>(accountManagerImpl: self, key: key)
        let pipe = ValuePipe<NoticeEntryView<Types>>()
        let index = self.noticeEntryViews.add((mutableView, pipe))
        
        let queue = self.queue
        return (.single(NoticeEntryView(mutableView))
        |> then(pipe.signal()))
        |> `catch` { _ -> Signal<NoticeEntryView<Types>, NoError> in
        }
        |> afterDisposed { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.noticeEntryViews.remove(index)
                }
            }
        }
    }
    
    private func accessChallengeDataInternal(transaction: AccountManagerModifier<Types>) -> Signal<AccessChallengeDataView, NoError> {
        let mutableView = MutableAccessChallengeDataView(data: transaction.getAccessChallengeData())
        let pipe = ValuePipe<AccessChallengeDataView>()
        let index = self.accessChallengeDataViews.add((mutableView, pipe))
        
        let queue = self.queue
        return (.single(AccessChallengeDataView(mutableView))
        |> then(pipe.signal()))
        |> `catch` { _ -> Signal<AccessChallengeDataView, NoError> in
        }
        |> afterDisposed { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.accessChallengeDataViews.remove(index)
                }
            }
        }
    }
    
    fileprivate func currentAccountRecord(allocateIfNotExists: Bool, excludeAccountIds: Set<AccountRecordId>) -> Signal<(AccountRecordId, [Types.Attribute])?, NoError> {
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<(AccountRecordId, [Types.Attribute])?, NoError> in
            let current = transaction.getCurrent(excludeAccountIds)
            if let _ = current {
            } else if allocateIfNotExists {
                let id = generateAccountRecordId()
                transaction.setCurrentId(id)
                transaction.updateRecord(id, { _ in
                    return AccountRecord(id: id, attributes: [], temporarySessionId: nil)
                })
            } else {
                return .single(nil)
            }
            
            let signal = self.accountRecordsInternal(transaction: transaction, excludeAccountIds: .single(excludeAccountIds))
            |> map { view -> (AccountRecordId, [Types.Attribute])? in
                if let currentRecord = view.currentRecord {
                    return (currentRecord.id, currentRecord.attributes)
                } else {
                    return nil
                }
            }
            
            return signal
        })
        |> switchToLatest
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if let lhs = lhs, let rhs = rhs {
                if lhs.0 != rhs.0 {
                    return false
                }
                if lhs.1.count != rhs.1.count {
                    return false
                }
                for i in 0 ..< lhs.1.count {
                    if !lhs.1[i].isEqual(to: rhs.1[i]) {
                        return false
                    }
                }
                return true
            } else if (lhs != nil) != (rhs != nil) {
                return false
            } else {
                return true
            }
        })
    }
    
    func allocatedTemporaryAccountId() -> Signal<AccountRecordId, NoError> {
        let temporarySessionId = self.temporarySessionId
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<AccountRecordId, NoError> in
            
            let id = generateAccountRecordId()
            transaction.updateRecord(id, { _ in
                return AccountRecord(id: id, attributes: [], temporarySessionId: temporarySessionId)
            })
            
            return .single(id)
        })
        |> switchToLatest
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
    }
    
    private func beginInternalTransaction(ignoreDisabled: Bool = false, _ f: @escaping () -> Void) {
        assert(self.queue.isCurrent())
        if ignoreDisabled || self.canBeginTransactionsValue.with({ $0 }) {
            f()
        } else {
            let _ = self.queuedInternalTransactions.modify { fs in
                var fs = fs
                fs.append(f)
                return fs
            }
        }
    }
    
    let canBeginTransactionsValue = Atomic<Bool>(value: true)
    func setCanBeginTransactions(_ value: Bool, afterTransactionIfRunning: @escaping () -> Void) {
        let previous = self.canBeginTransactionsValue.swap(value)
        if previous != value && value {
            let fs = self.queuedInternalTransactions.swap([])
            for f in fs {
                f()
            }
        }
        afterTransactionIfRunning()
    }
    
    fileprivate func optimizeStorage(minFreePagesFraction: Double) -> Signal<Never, NoError> {
        return Signal { subscriber in
            self.beginInternalTransaction {
                if let valueBox = self.valueBox as? SqliteValueBox {
                    if valueBox.freePagesFraction() >= minFreePagesFraction {
                        valueBox.vacuum()
                    }
                }
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    #if TEST_BUILD
    fileprivate func debugDumpDbStat() -> Signal<String, NoError> {
        return (self.valueBox as? SqliteValueBox)?.debugDumpStat() ?? .complete()
    }
    #endif
}

private let sharedQueue = Queue()

public final class AccountManager<Types: AccountManagerTypes> {
    public let basePath: String
    public let mediaBox: MediaBox
    private let queue: Queue
    private let impl: QueueLocalObject<AccountManagerImpl<Types>>
    public let temporarySessionId: Int64
    
    public static func getCurrentRecords(basePath: String, excludeAccountIds: Set<AccountRecordId>) -> (records: [AccountRecord<Types.Attribute>], currentId: AccountRecordId?) {
        return AccountManagerImpl<Types>.getCurrentRecords(basePath: basePath, excludeAccountIds: excludeAccountIds)
    }
    
    public init(basePath: String, isTemporary: Bool, isReadOnly: Bool, useCaches: Bool, removeDatabaseOnError: Bool) {
        self.queue = sharedQueue
        self.basePath = basePath
        var temporarySessionId: Int64 = 0
        arc4random_buf(&temporarySessionId, 8)
        self.temporarySessionId = temporarySessionId
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            if let value = AccountManagerImpl<Types>(queue: queue, basePath: basePath, isTemporary: isTemporary, isReadOnly: isReadOnly, useCaches: useCaches, removeDatabaseOnError: removeDatabaseOnError, temporarySessionId: temporarySessionId) {
                return value
            } else {
                postboxLogSync()
                preconditionFailure()
            }
        })
        self.mediaBox = MediaBox(basePath: basePath + "/media", isMainProcess: removeDatabaseOnError)
    }
    
    public func transaction<T>(ignoreDisabled: Bool = false, _ f: @escaping (AccountManagerModifier<Types>) -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.transaction(ignoreDisabled: ignoreDisabled, f).start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func accountRecords(excludeAccountIds: Signal<Set<AccountRecordId>, NoError>) -> Signal<AccountRecordsView<Types>, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.accountRecords(excludeAccountIds: excludeAccountIds).start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }

    public func _internalAccountRecordsSync(excludeAccountIds: Set<AccountRecordId>) -> AccountRecordsView<Types> {
        var result: AccountRecordsView<Types>?
        self.impl.syncWith { impl in
            result = impl._internalAccountRecordsSync(excludeAccountIds: excludeAccountIds)
        }
        return result!
    }
    
    public func sharedData(keys: Set<ValueBoxKey>) -> Signal<AccountSharedDataView<Types>, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.sharedData(keys: keys).start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func noticeEntry(key: NoticeEntryKey) -> Signal<NoticeEntryView<Types>, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.noticeEntry(key: key).start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func accessChallengeData() -> Signal<AccessChallengeDataView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.accessChallengeData().start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func currentAccountRecord(allocateIfNotExists: Bool, excludeAccountIds: Set<AccountRecordId>) -> Signal<(AccountRecordId, [Types.Attribute])?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.currentAccountRecord(allocateIfNotExists: allocateIfNotExists, excludeAccountIds: excludeAccountIds).start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func allocatedTemporaryAccountId() -> Signal<AccountRecordId, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.allocatedTemporaryAccountId().start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func setCanBeginTransactions(_ value: Bool, afterTransactionIfRunning: @escaping () -> Void = {}) {
        let storageBox = self.mediaBox.storageBox
        let cacheStorageBox = self.mediaBox.cacheStorageBox
        self.impl.with { impl in
            impl.setCanBeginTransactions(value, afterTransactionIfRunning: {
                storageBox.setCanBeginTransactions(value, afterTransactionIfRunning: {
                    cacheStorageBox.setCanBeginTransactions(value, afterTransactionIfRunning: {
                        afterTransactionIfRunning()
                    })
                })
            })
        }
    }
    
    public func optimizeStorage(minFreePagesFraction: Double) -> Signal<Never, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                disposable.set(impl.optimizeStorage(minFreePagesFraction: minFreePagesFraction).start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion))
            }
            
            return disposable
        }
    }
    
    public func optimizeAllStorages(minFreePagesFraction: Double) -> Signal<Never, NoError> {
        return self.optimizeStorage(minFreePagesFraction: minFreePagesFraction)
        |> then (self.mediaBox.storageBox.optimizeStorage(minFreePagesFraction: minFreePagesFraction))
        |> then (self.mediaBox.cacheStorageBox.optimizeStorage(minFreePagesFraction: minFreePagesFraction))
    }
    
    #if TEST_BUILD
    public func debugDumpDbStat() -> Signal<String, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                disposable.set(impl.debugDumpDbStat().start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion))
            }
            
            return disposable
        }
    }
    
    public func debugDumpAllDbStats() -> Signal<String, NoError> {
        return self.debugDumpDbStat()
        |> then (self.mediaBox.storageBox.debugDumpDbStat())
        |> then (self.mediaBox.cacheStorageBox.debugDumpDbStat())
    }
    #endif
}
