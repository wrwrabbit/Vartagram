import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public enum MediaResourceUserContentType: UInt8, Equatable {
    case other = 0
    case image = 1
    case video = 2
    case audio = 3
    case file = 4
    case sticker = 6
    case avatar = 7
    case audioVideoMessage = 8
    case story = 9
}

public extension MediaResourceUserContentType {
    init(file: TelegramMediaFile) {
        if file.isInstantVideo || file.isVoice {
            self = .audioVideoMessage
        } else if file.isMusic {
            self = .audio
        } else if file.isSticker || file.isAnimatedSticker {
            self = .sticker
        } else if file.isCustomEmoji {
            self = .sticker
        } else if file.isVideo {
            if file.isAnimated {
                self = .other
            } else {
                self = .video
            }
        } else {
            self = .file
        }
    }
}

public extension MediaResourceFetchParameters {
    init(tag: MediaResourceFetchTag?, info: MediaResourceFetchInfo?, location: MediaResourceStorageLocation?, contentType: MediaResourceUserContentType, isRandomAccessAllowed: Bool) {
        self.init(tag: tag, info: info, location: location, contentType: contentType.rawValue, isRandomAccessAllowed: isRandomAccessAllowed)
    }
}

func bufferedFetch(_ signal: Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error>) -> Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error> {
    return Signal { subscriber in
        final class State {
            var data = Data()
            var isCompleted: Bool = false
            
            init() {
            }
        }
        
        let state = Atomic<State>(value: State())
        return signal.start(next: { value in
            switch value {
            case let .dataPart(_, data, _, _):
                let _ = state.with { state in
                    state.data.append(data)
                }
            case let .moveTempFile(file):
                let _ = state.with { state in
                    state.isCompleted = true
                }
                subscriber.putNext(.moveTempFile(file: file))
            case let .resourceSizeUpdated(size):
                if size == 0 {
                    let _ = state.with { state in
                        state.data.removeAll()
                        state.isCompleted = true
                    }
                    let tempFile = TempBox.shared.tempFile(fileName: "file")
                    let _ = try? Data().write(to: URL(fileURLWithPath: tempFile.path), options: .atomic)
                    subscriber.putNext(.moveTempFile(file: tempFile))
                    subscriber.putCompletion()
                }
            default:
                assert(false)
                break
            }
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            let tempFile = state.with { state -> TempBoxFile? in
                if state.isCompleted {
                    return nil
                } else {
                    let tempFile = TempBox.shared.tempFile(fileName: "data")
                    let _ = try? state.data.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic)
                    return tempFile
                }
            }
            if let tempFile = tempFile {
                subscriber.putNext(.moveTempFile(file: tempFile))
            }
            subscriber.putCompletion()
        })
    }
}

public final class EngineMediaResource: Equatable {
    public enum CacheTimeout {
        case `default`
        case shortLived
    }

    public struct ByteRange {
        public enum Priority {
            case `default`
            case elevated
            case maximum
        }

        public var range: Range<Int>
        public var priority: Priority

        public init(range: Range<Int>, priority: Priority) {
            self.range = range
            self.priority = priority
        }
    }

    public final class Fetch {
        public enum Result {
            case dataPart(resourceOffset: Int64, data: Data, range: Range<Int64>, complete: Bool)
            case resourceSizeUpdated(Int64)
            case progressUpdated(Float)
            case replaceHeader(data: Data, range: Range<Int64>)
            case moveLocalFile(path: String)
            case moveTempFile(file: TempBoxFile)
            case copyLocalItem(MediaResourceDataFetchCopyLocalItem)
            case reset
        }

        public enum Error {
            case generic
        }

        public let signal: () -> Signal<Result, Error>

        public init(_ signal: @escaping () -> Signal<Result, Error>) {
            self.signal = signal
        }
    }

    public final class ResourceData {
        public let path: String
        public let availableSize: Int64
        public let isComplete: Bool

        public init(
            path: String,
            availableSize: Int64,
            isComplete: Bool
        ) {
            self.path = path
            self.availableSize = availableSize
            self.isComplete = isComplete
        }
    }

    public enum FetchStatus: Equatable {
        case Remote(progress: Float)
        case Local
        case Fetching(isActive: Bool, progress: Float)
        case Paused(progress: Float)
    }

    public struct Id: Equatable, Hashable {
        public var stringRepresentation: String

        public init(_ stringRepresentation: String) {
            self.stringRepresentation = stringRepresentation
        }

        public init(_ id: MediaResourceId) {
            self.stringRepresentation = id.stringRepresentation
        }
    }

    private let resource: MediaResource

    public init(_ resource: MediaResource) {
        self.resource = resource
    }

    public func _asResource() -> MediaResource {
        return self.resource
    }

    public var id: Id {
        return Id(self.resource.id)
    }

    public static func ==(lhs: EngineMediaResource, rhs: EngineMediaResource) -> Bool {
        return lhs.resource.isEqual(to: rhs.resource)
    }
}

public extension EngineMediaResource.ResourceData {
    convenience init(_ data: MediaResourceData) {
        self.init(path: data.path, availableSize: data.size, isComplete: data.complete)
    }
}

public extension EngineMediaResource.FetchStatus {
    init(_ status: MediaResourceStatus) {
        switch status {
        case let .Remote(progress):
            self = .Remote(progress: progress)
        case .Local:
            self = .Local
        case let .Fetching(isActive, progress):
            self = .Fetching(isActive: isActive, progress: progress)
        case let .Paused(progress):
            self = .Paused(progress: progress)
        }
    }

    func _asStatus() -> MediaResourceStatus {
        switch self {
        case let .Remote(progress):
            return .Remote(progress: progress)
        case .Local:
            return .Local
        case let .Fetching(isActive, progress):
            return .Fetching(isActive: isActive, progress: progress)
        case let .Paused(progress):
            return .Paused(progress: progress)
        }
    }
}

public extension TelegramEngine {
    final class Resources {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func preUpload(id: Int64, encrypt: Bool, tag: MediaResourceFetchTag?, source: Signal<EngineMediaResource.ResourceData, NoError>, onComplete: (()->Void)? = nil) {
            return self.account.messageMediaPreuploadManager.add(network: self.account.network, postbox: self.account.postbox, id: id, encrypt: encrypt, tag: tag, source: source, onComplete: onComplete)
        }

        /*
        public func collectCacheUsageStats(peerId: PeerId? = nil, additionalCachePaths: [String] = [], logFilesPath: String? = nil) -> Signal<CacheUsageStatsResult, NoError> {
            return _internal_collectCacheUsageStats(account: self.account, peerId: peerId, additionalCachePaths: additionalCachePaths, logFilesPath: logFilesPath)
        }
        
        public func collectStorageUsageStats() -> Signal<AllStorageUsageStats, NoError> {
            return _internal_collectStorageUsageStats(account: self.account)
        }

        public func renderStorageUsageStatsMessages(stats: StorageUsageStats, categories: [StorageUsageStats.CategoryKey], existingMessages: [EngineMessage.Id: Message]) -> Signal<[EngineMessage.Id: Message], NoError> {
            return _internal_renderStorageUsageStatsMessages(account: self.account, stats: stats, categories: categories, existingMessages: existingMessages)
        }
        */
        
        public func clearStorage(peerId: EnginePeer.Id?, categories: [StorageUsageStats.CategoryKey], includeMessages: [Message], excludeMessages: [Message]) -> Signal<Float, NoError> {
            return _internal_clearStorage(account: self.account, peerId: peerId, categories: categories, includeMessages: includeMessages, excludeMessages: excludeMessages)
        }
        
        /*
        public func clearStorage(peerIds: Set<EnginePeer.Id>, includeMessages: [Message], excludeMessages: [Message]) -> Signal<Float, NoError> {
            _internal_clearStorage(account: self.account, peerIds: peerIds, includeMessages: includeMessages, excludeMessages: excludeMessages)
        }
        
        public func clearStorage(messages: [Message]) -> Signal<Never, NoError> {
            _internal_clearStorage(account: self.account, messages: messages)
        }

        public func clearCachedMediaResources(mediaResourceIds: Set<MediaResourceId>) -> Signal<Float, NoError> {
            return _internal_clearCachedMediaResources(account: self.account, mediaResourceIds: mediaResourceIds)
        }
        */
        
        public func reindexCacheInBackground(lowImpact: Bool) -> Signal<Never, NoError> {
            let mediaBox = self.account.postbox.mediaBox
            
            return _internal_reindexCacheInBackground(account: self.account, lowImpact: lowImpact)
            |> then(Signal { subscriber in
                return mediaBox.updateResourceIndex(otherResourceContentType: MediaResourceUserContentType.other.rawValue, lowImpact: lowImpact, completion: {
                    subscriber.putCompletion()
                })
            })
        }

        public func data(id: EngineMediaResource.Id, attemptSynchronously: Bool = false) -> Signal<EngineMediaResource.ResourceData, NoError> {
            return self.account.postbox.mediaBox.resourceData(
                id: MediaResourceId(id.stringRepresentation),
                pathExtension: nil,
                option: .complete(waitUntilFetchStatus: false),
                attemptSynchronously: attemptSynchronously
            )
            |> map { data in
                return EngineMediaResource.ResourceData(data)
            }
        }

        public func custom(
            id: String,
            fetch: EngineMediaResource.Fetch?,
            cacheTimeout: EngineMediaResource.CacheTimeout = .default,
            attemptSynchronously: Bool = false
        ) -> Signal<EngineMediaResource.ResourceData, NoError> {
            let mappedKeepDuration: CachedMediaRepresentationKeepDuration
            switch cacheTimeout {
            case .default:
                mappedKeepDuration = .general
            case .shortLived:
                mappedKeepDuration = .shortLived
            }
            return self.account.postbox.mediaBox.customResourceData(
                id: id,
                baseResourceId: nil,
                pathExtension: nil,
                complete: true,
                fetch: fetch.flatMap { fetch in
                    return {
                        return Signal { subscriber in
                            return fetch.signal().start(next: { result in
                                let mappedResult: CachedMediaResourceRepresentationResult
                                switch result {
                                case let .moveTempFile(file):
                                    mappedResult = .tempFile(file)
                                default:
                                    assert(false)
                                    return
                                }
                                subscriber.putNext(mappedResult)
                            }, completed: {
                                subscriber.putCompletion()
                            })
                        }
                    }
                },
                keepDuration: mappedKeepDuration,
                attemptSynchronously: attemptSynchronously
            )
            |> map { data in
                return EngineMediaResource.ResourceData(data)
            }
        }

        public func httpData(url: String) -> Signal<Data, EngineMediaResource.Fetch.Error> {
            return fetchHttpResource(url: url)
            |> mapError { _ -> EngineMediaResource.Fetch.Error in
                return .generic
            }
            |> mapToSignal { value -> Signal<Data, EngineMediaResource.Fetch.Error> in
                switch value {
                case let .dataPart(_, data, _, _):
                    return .single(data)
                default:
                    return .complete()
                }
            }
        }
        
        public func fetchAlbumCover(file: FileMediaReference?, title: String, performer: String, isThumbnail: Bool) -> Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error> {
            let signal = currentWebDocumentsHostDatacenterId(postbox: self.account.postbox, isTestingEnvironment: self.account.testingEnvironment)
            |> castError(EngineMediaResource.Fetch.Error.self)
            |> take(1)
            |> mapToSignal { datacenterId -> Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error> in
                let resource = AlbumCoverResource(datacenterId: Int(datacenterId), file: file, title: title, performer: performer, isThumbnail: isThumbnail)
                
                return multipartFetch(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, mediaReferenceRevalidationContext: self.account.mediaReferenceRevalidationContext, networkStatsContext: self.account.networkStatsContext, resource: resource, datacenterId: Int(datacenterId), size: nil, intervals: .single([(0 ..< Int64.max, .default)]), parameters: MediaResourceFetchParameters(
                    tag: nil,
                    info: TelegramCloudMediaResourceFetchInfo(
                        reference: MediaResourceReference.standalone(resource: resource),
                        preferBackgroundReferenceRevalidation: false,
                        continueInBackground: false
                    ),
                    location: nil,
                    contentType: .image,
                    isRandomAccessAllowed: true
                ))
                |> map { result -> EngineMediaResource.Fetch.Result in
                    switch result {
                    case let .dataPart(resourceOffset, data, range, complete):
                        return .dataPart(resourceOffset: resourceOffset, data: data, range: range, complete: complete)
                    case let .resourceSizeUpdated(size):
                        return .resourceSizeUpdated(size)
                    case let .progressUpdated(value):
                        return .progressUpdated(value)
                    case let .replaceHeader(data, range):
                        return .replaceHeader(data: data, range: range)
                    case let .moveLocalFile(path):
                        return .moveLocalFile(path: path)
                    case let .moveTempFile(file):
                        return .moveTempFile(file: file)
                    case let .copyLocalItem(item):
                        return .copyLocalItem(item)
                    case .reset:
                        return .reset
                    }
                }
                |> mapError { error -> EngineMediaResource.Fetch.Error in
                    switch error {
                    case .generic:
                        return .generic
                    }
                }
            }
            
            return bufferedFetch(signal)
        }

        public func cancelAllFetches(id: String) {
            preconditionFailure()
        }
        
        public func pushPriorityDownload(resourceId: String, priority: Int = 1) -> Disposable {
            return self.account.network.multiplexedRequestManager.pushPriority(resourceId: resourceId, priority: priority)
        }
    }
}
