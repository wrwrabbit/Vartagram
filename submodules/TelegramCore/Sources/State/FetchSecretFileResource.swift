import UIKit
import ImageCompression

import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

func fetchSecretFileResource(
    accountPeerId: PeerId,
    postbox: Postbox,
    network: Network,
    mediaReferenceRevalidationContext: MediaReferenceRevalidationContext,
    networkStatsContext: NetworkStatsContext,
    resource: SecretFileMediaResource,
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
        datacenterId: resource.datacenterId,
        size: resource.size,
        intervals: intervals,
        parameters: parameters,
        encryptionKey: resource.key,
        decryptedSize: resource.decryptedSize
    )
    |> afterCompleted {
        // some incoming images in secret chats does not contain thumbnails, so here we create tiny thumbnail after first image download
        if let parameters = parameters, parameters.location?.peerId.namespace == Namespaces.Peer.SecretChat, let fetchInfo = parameters.info as? TelegramCloudMediaResourceFetchInfo {
            if case let .media(mediaReference, mediaResource) = fetchInfo.reference {
                assert(mediaResource.id == resource.id)
                if case let .message(_, media) = mediaReference, let media = media as? TelegramMediaImage, media.immediateThumbnailData == nil, media.representations.contains(where: { $0.resource.id == resource.id }) {
                    let _ = (postbox.mediaBox.resourceData(resource)
                    |> take(1)
                    |> mapToSignal { data in
                        if data.complete, let image = UIImage(contentsOfFile: data.path), let immediateThumbnailData = compressImageMiniThumbnail(image) {
                            return postbox.transaction { transaction in
                                let _ = transaction.updateMedia(media.imageId, update: media.withUpdatedImmediateThumbnailData(immediateThumbnailData))
                            }
                        } else {
                            return .complete()
                        }
                    }).start()
                }
            }
        }
    }
}
