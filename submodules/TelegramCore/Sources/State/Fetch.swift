import Foundation
import Postbox
import SwiftSignalKit

#if os(iOS)
import Photos
#endif


private final class MediaResourceDataCopyFile : MediaResourceDataFetchCopyLocalItem {
    let path: String
    init(path: String) {
        self.path = path
    }
    func copyTo(url: URL) -> Bool {
        do {
            try FileManager.default.copyItem(at: URL(fileURLWithPath: self.path), to: url)
            return true
        } catch {
            return false
        }
    }
}

func fetchCloudMediaLocation(
    accountPeerId: PeerId,
    postbox: Postbox,
    network: Network,
    mediaReferenceRevalidationContext: MediaReferenceRevalidationContext,
    networkStatsContext: NetworkStatsContext,
    resource: TelegramMediaResource,
    datacenterId: Int,
    size: Int64?,
    intervals: Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>,
    parameters: MediaResourceFetchParameters?
) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return multipartFetch(
        accountPeerId: accountPeerId,
        postbox: postbox,
        network: network,
        mediaReferenceRevalidationContext: mediaReferenceRevalidationContext,
        networkStatsContext: networkStatsContext,
        resource: resource,
        datacenterId: datacenterId,
        size: size,
        intervals: intervals,
        parameters: parameters
    )
}

private func fetchLocalFileResource(path: String, move: Bool) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        if !FileManager.default.fileExists(atPath: path) {
            subscriber.putError(.generic)
        } else if move {
            subscriber.putNext(.moveLocalFile(path: path))
            subscriber.putCompletion()
        } else {
            subscriber.putNext(.copyLocalItem(MediaResourceDataCopyFile(path: path)))
            subscriber.putCompletion()
        }
        return EmptyDisposable
    }
}

func fetchResource(account: Account, resource: MediaResource, intervals: Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>, parameters: MediaResourceFetchParameters?) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>? {
    return fetchResource(
        accountPeerId: account.peerId,
        postbox: account.postbox,
        network: account.network,
        mediaReferenceRevalidationContext: account.mediaReferenceRevalidationContext,
        networkStatsContext: account.networkStatsContext,
        isTestingEnvironment: account.testingEnvironment,
        resource: resource,
        intervals: intervals,
        parameters: parameters
    )
}
    
func fetchResource(
    accountPeerId: PeerId,
    postbox: Postbox,
    network: Network,
    mediaReferenceRevalidationContext: MediaReferenceRevalidationContext,
    networkStatsContext: NetworkStatsContext,
    isTestingEnvironment: Bool,
    resource: MediaResource,
    intervals: Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>,
    parameters: MediaResourceFetchParameters?
) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>? {
    if let _ = resource as? EmptyMediaResource {
        return .single(.reset)
        |> then(.never())
    } else if let secretFileResource = resource as? SecretFileMediaResource {
        return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false))
        |> then(fetchSecretFileResource(
            accountPeerId: accountPeerId,
            postbox: postbox,
            network: network,
            mediaReferenceRevalidationContext: mediaReferenceRevalidationContext,
            networkStatsContext: networkStatsContext,
            resource: secretFileResource,
            intervals: intervals,
            parameters: parameters
        ))
    } else if let cloudResource = resource as? TelegramMultipartFetchableResource {
        return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false))
        |> then(fetchCloudMediaLocation(
            accountPeerId: accountPeerId,
            postbox: postbox,
            network: network,
            mediaReferenceRevalidationContext: mediaReferenceRevalidationContext,
            networkStatsContext: networkStatsContext,
            resource: cloudResource,
            datacenterId: cloudResource.datacenterId,
            size: resource.size == 0 ? nil : resource.size,
            intervals: intervals,
            parameters: parameters
        ))
    } else if let webFileResource = resource as? MediaResourceWithWebFileReference {
        return currentWebDocumentsHostDatacenterId(postbox: postbox, isTestingEnvironment: isTestingEnvironment)
        |> castError(MediaResourceDataFetchError.self)
        |> mapToSignal { datacenterId -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> in
            return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false))
            |> then(fetchCloudMediaLocation(
                accountPeerId: accountPeerId,
                postbox: postbox,
                network: network,
                mediaReferenceRevalidationContext: mediaReferenceRevalidationContext,
                networkStatsContext: networkStatsContext,
                resource: webFileResource,
                datacenterId: Int(datacenterId),
                size: resource.size == 0 ? nil : resource.size,
                intervals: intervals,
                parameters: parameters
            ))
        }
    } else if let localFileResource = resource as? LocalFileReferenceMediaResource {
        return fetchLocalFileResource(path: localFileResource.localFilePath, move: localFileResource.isUniquelyReferencedTemporaryFile)
    } else if let httpReference = resource as? HttpReferenceMediaResource {
        return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false))
        |> then(fetchHttpResource(url: httpReference.url))
    } else if let wallpaperResource = resource as? WallpaperDataResource {
        return getWallpaper(network: network, slug: wallpaperResource.slug)
        |> mapError { _ -> MediaResourceDataFetchError in
            return .generic
        }
        |> mapToSignal { wallpaper -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> in
            guard case let .file(file) = wallpaper else {
                return .fail(.generic)
            }
            guard let cloudResource = file.file.resource as? TelegramMultipartFetchableResource else {
                return .fail(.generic)
            }
            return .single(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: false))
            |> then(fetchCloudMediaLocation(
                accountPeerId: accountPeerId,
                postbox: postbox,
                network: network,
                mediaReferenceRevalidationContext: mediaReferenceRevalidationContext,
                networkStatsContext: networkStatsContext,
                resource: cloudResource,
                datacenterId: cloudResource.datacenterId,
                size: resource.size == 0 ? nil : resource.size,
                intervals: intervals,
                parameters: MediaResourceFetchParameters(
                    tag: nil,
                    info: TelegramCloudMediaResourceFetchInfo(reference: .standalone(resource: file.file.resource), preferBackgroundReferenceRevalidation: false, continueInBackground: false),
                    location: nil,
                    contentType: .other,
                    isRandomAccessAllowed: true
                )
            ))
        }
    }
    return nil
}
