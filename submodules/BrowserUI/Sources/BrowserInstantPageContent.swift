//import Foundation
//import UIKit
//import AsyncDisplayKit
//import TelegramCore
//import Postbox
//import SwiftSignalKit
//import Display
//import ComponentFlow
//import TelegramPresentationData
//import TelegramUIPreferences
//import AccountContext
//import AppBundle
//import InstantPageUI
//
//final class InstantPageView: UIView, UIScrollViewDelegate {
//    private let webPage: TelegramMediaWebpage
//    private var initialAnchor: String?
//    private var pendingAnchor: String?
//    private var initialState: InstantPageStoredState?
//    
//    private let scrollNode: ASScrollNode
//    private let scrollNodeHeader: ASDisplayNode
//    private let scrollNodeFooter: ASDisplayNode
//    private var linkHighlightingNode: LinkHighlightingNode?
//    private var textSelectionNode: LinkHighlightingNode?
//    
//    var currentLayout: InstantPageLayout?
//    var currentLayoutTiles: [InstantPageTile] = []
//    var currentLayoutItemsWithNodes: [InstantPageItem] = []
//    var distanceThresholdGroupCount: [Int: Int] = [:]
//    
//    var visibleTiles: [Int: InstantPageTileNode] = [:]
//    var visibleItemsWithNodes: [Int: InstantPageNode] = [:]
//    
//    var currentWebEmbedHeights: [Int : CGFloat] = [:]
//    var currentExpandedDetails: [Int : Bool]?
//    var currentDetailsItems: [InstantPageDetailsItem] = []
//    
//    var currentAccessibilityAreas: [AccessibilityAreaNode] = []
//    
//    init(webPage: TelegramMediaWebpage) {
//        self.webPage = webPage
//        
//        self.scrollNode = ASScrollNode()
//        
//        super.init(frame: frame)
//        
//        self.addSubview(self.scrollNode.view)
//        
//        self.scrollNode.view.delaysContentTouches = false
//        self.scrollNode.view.delegate = self
//        
//        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
//            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
//        }
//        
//        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
//        recognizer.delaysTouchesBegan = false
//        recognizer.tapActionAtPoint = { [weak self] point in
//            if let strongSelf = self {
//                return strongSelf.tapActionAtPoint(point)
//            }
//            return .waitForSingleTap
//        }
//        recognizer.highlight = { [weak self] point in
//            if let strongSelf = self {
//                strongSelf.updateTouchesAtPoint(point)
//            }
//        }
//        self.scrollNode.view.addGestureRecognizer(recognizer)
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    func tapActionAtPoint(_ point: CGPoint) -> TapLongTapOrDoubleTapGestureRecognizerAction {
//        if let currentLayout = self.currentLayout {
//            for item in currentLayout.items {
//                let frame = self.effectiveFrameForItem(item)
//                if frame.contains(point) {
//                    if item is InstantPagePeerReferenceItem {
//                        return .fail
//                    } else if item is InstantPageAudioItem {
//                        return .fail
//                    } else if item is InstantPageArticleItem {
//                        return .fail
//                    } else if item is InstantPageFeedbackItem {
//                        return .fail
//                    } else if let item = item as? InstantPageDetailsItem {
//                        for (_, itemNode) in self.visibleItemsWithNodes {
//                            if let itemNode = itemNode as? InstantPageDetailsNode, itemNode.item === item {
//                                return itemNode.tapActionAtPoint(point.offsetBy(dx: -itemNode.frame.minX, dy: -itemNode.frame.minY))
//                            }
//                        }
//                    }
//                    if !(item is InstantPageImageItem || item is InstantPagePlayableVideoItem) {
//                        break
//                    }
//                }
//            }
//        }
//        return .waitForSingleTap
//    }
//    
//    private func updateTouchesAtPoint(_ location: CGPoint?) {
//        var rects: [CGRect]?
//        if let location = location, let currentLayout = self.currentLayout {
//            for item in currentLayout.items {
//                let itemFrame = self.effectiveFrameForItem(item)
//                if itemFrame.contains(location) {
//                    var contentOffset = CGPoint()
//                    if let item = item as? InstantPageScrollableItem {
//                        contentOffset = self.scrollableContentOffset(item: item)
//                    }
//                    var itemRects = item.linkSelectionRects(at: location.offsetBy(dx: -itemFrame.minX + contentOffset.x, dy: -itemFrame.minY))
//                    
//                    for i in 0 ..< itemRects.count {
//                        itemRects[i] = itemRects[i].offsetBy(dx: itemFrame.minX - contentOffset.x, dy: itemFrame.minY).insetBy(dx: -2.0, dy: -2.0)
//                    }
//                    if !itemRects.isEmpty {
//                        rects = itemRects
//                        break
//                    }
//                }
//            }
//        }
//        
//        if let rects = rects {
//            let linkHighlightingNode: LinkHighlightingNode
//            if let current = self.linkHighlightingNode {
//                linkHighlightingNode = current
//            } else {
//                let highlightColor = self.theme?.linkHighlightColor ?? UIColor(rgb: 0x007aff).withAlphaComponent(0.4)
//                linkHighlightingNode = LinkHighlightingNode(color: highlightColor)
//                linkHighlightingNode.isUserInteractionEnabled = false
//                self.linkHighlightingNode = linkHighlightingNode
//                self.scrollNode.addSubnode(linkHighlightingNode)
//            }
//            linkHighlightingNode.frame = CGRect(origin: CGPoint(), size: self.scrollNode.bounds.size)
//            linkHighlightingNode.updateRects(rects)
//        } else if let linkHighlightingNode = self.linkHighlightingNode {
//            self.linkHighlightingNode = nil
//            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
//                linkHighlightingNode?.removeFromSupernode()
//            })
//        }
//    }
//    
//    private func updatePageLayout() {
//        guard let containerLayout = self.containerLayout, let webPage = self.webPage, let theme = self.theme else {
//            return
//        }
//        
//        let currentLayout = instantPageLayoutForWebPage(webPage, userLocation: self.sourceLocation.userLocation, boundingWidth: containerLayout.size.width, safeInset: containerLayout.safeInsets.left, strings: self.strings, theme: theme, dateTimeFormat: self.dateTimeFormat, webEmbedHeights: self.currentWebEmbedHeights)
//        
//        for (_, tileNode) in self.visibleTiles {
//            tileNode.removeFromSupernode()
//        }
//        self.visibleTiles.removeAll()
//        
//        let currentLayoutTiles = instantPageTilesFromLayout(currentLayout, boundingWidth: containerLayout.size.width)
//        
//        var currentDetailsItems: [InstantPageDetailsItem] = []
//        var currentLayoutItemsWithNodes: [InstantPageItem] = []
//        var distanceThresholdGroupCount: [Int : Int] = [:]
//        
//        var expandedDetails: [Int : Bool] = [:]
//        
//        var detailsIndex = -1
//        for item in currentLayout.items {
//            if item.wantsNode {
//                currentLayoutItemsWithNodes.append(item)
//                if let group = item.distanceThresholdGroup() {
//                    let count: Int
//                    if let currentCount = distanceThresholdGroupCount[Int(group)] {
//                        count = currentCount
//                    } else {
//                        count = 0
//                    }
//                    distanceThresholdGroupCount[Int(group)] = count + 1
//                }
//                if let detailsItem = item as? InstantPageDetailsItem {
//                    detailsIndex += 1
//                    expandedDetails[detailsIndex] = detailsItem.initiallyExpanded
//                    currentDetailsItems.append(detailsItem)
//                }
//            }
//        }
//        
//        if var currentExpandedDetails = self.currentExpandedDetails {
//            for (index, expanded) in expandedDetails {
//                if currentExpandedDetails[index] == nil {
//                    currentExpandedDetails[index] = expanded
//                }
//            }
//            self.currentExpandedDetails = currentExpandedDetails
//        } else {
//            self.currentExpandedDetails = expandedDetails
//        }
//        
//        let accessibilityAreas = instantPageAccessibilityAreasFromLayout(currentLayout, boundingWidth: containerLayout.size.width)
//        
//        self.currentLayout = currentLayout
//        self.currentLayoutTiles = currentLayoutTiles
//        self.currentLayoutItemsWithNodes = currentLayoutItemsWithNodes
//        self.currentDetailsItems = currentDetailsItems
//        self.distanceThresholdGroupCount = distanceThresholdGroupCount
//        
//        for areaNode in self.currentAccessibilityAreas {
//            areaNode.removeFromSupernode()
//        }
//        for areaNode in accessibilityAreas {
//            self.scrollNode.addSubnode(areaNode)
//        }
//        self.currentAccessibilityAreas = accessibilityAreas
//        
//        self.scrollNode.view.contentSize = currentLayout.contentSize
//        self.scrollNodeFooter.frame = CGRect(origin: CGPoint(x: 0.0, y: currentLayout.contentSize.height), size: CGSize(width: containerLayout.size.width, height: 2000.0))
//    }
//    
//    func updateVisibleItems(visibleBounds: CGRect, animated: Bool = false) {
//        guard let theme = self.theme else {
//            return
//        }
//        
//        var visibleTileIndices = Set<Int>()
//        var visibleItemIndices = Set<Int>()
//        
//        var topNode: ASDisplayNode?
//        let topTileNode = topNode
//        if let scrollSubnodes = self.scrollNode.subnodes {
//            for node in scrollSubnodes.reversed() {
//                if let node = node as? InstantPageTileNode {
//                    topNode = node
//                    break
//                }
//            }
//        }
//        
//        var collapseOffset: CGFloat = 0.0
//        let transition: ContainedViewLayoutTransition
//        if animated {
//            transition = .animated(duration: 0.3, curve: .spring)
//        } else {
//            transition = .immediate
//        }
//        
//        var itemIndex = -1
//        var embedIndex = -1
//        var detailsIndex = -1
//        
//        var previousDetailsNode: InstantPageDetailsNode?
//        
//        for item in self.currentLayoutItemsWithNodes {
//            itemIndex += 1
//            if item is InstantPageWebEmbedItem {
//                embedIndex += 1
//            }
//            if let imageItem = item as? InstantPageImageItem, imageItem.media.media is TelegramMediaWebpage {
//                embedIndex += 1
//            }
//            if item is InstantPageDetailsItem {
//                detailsIndex += 1
//            }
//    
//            var itemThreshold: CGFloat = 0.0
//            if let group = item.distanceThresholdGroup() {
//                var count: Int = 0
//                if let currentCount = self.distanceThresholdGroupCount[group] {
//                    count = currentCount
//                }
//                itemThreshold = item.distanceThresholdWithGroupCount(count)
//            }
//            
//            var itemFrame = item.frame.offsetBy(dx: 0.0, dy: -collapseOffset)
//            var thresholdedItemFrame = itemFrame
//            thresholdedItemFrame.origin.y -= itemThreshold
//            thresholdedItemFrame.size.height += itemThreshold * 2.0
//            
//            if let detailsItem = item as? InstantPageDetailsItem, let expanded = self.currentExpandedDetails?[detailsIndex] {
//                let height = expanded ? self.effectiveSizeForDetails(detailsItem).height : detailsItem.titleHeight
//                collapseOffset += itemFrame.height - height
//                itemFrame = CGRect(origin: itemFrame.origin, size: CGSize(width: itemFrame.width, height: height))
//            }
//            
//            if visibleBounds.intersects(thresholdedItemFrame) {
//                visibleItemIndices.insert(itemIndex)
//                
//                var itemNode = self.visibleItemsWithNodes[itemIndex]
//                if let currentItemNode = itemNode {
//                    if !item.matchesNode(currentItemNode) {
//                        currentItemNode.removeFromSupernode()
//                        self.visibleItemsWithNodes.removeValue(forKey: itemIndex)
//                        itemNode = nil
//                    }
//                }
//                
//                if itemNode == nil {
//                    let itemIndex = itemIndex
//                    let embedIndex = embedIndex
//                    let detailsIndex = detailsIndex
//                    if let newNode = item.node(context: self.context, strings: self.strings, nameDisplayOrder: self.nameDisplayOrder, theme: theme, sourceLocation: self.sourceLocation, openMedia: { [weak self] media in
//                        self?.openMedia(media)
//                    }, longPressMedia: { [weak self] media in
//                        self?.longPressMedia(media)
//                    }, activatePinchPreview: { [weak self] sourceNode in
//                        guard let strongSelf = self, let controller = strongSelf.controller else {
//                            return
//                        }
//                        let pinchController = PinchController(sourceNode: sourceNode, getContentAreaInScreenSpace: {
//                            guard let strongSelf = self else {
//                                return CGRect()
//                            }
//
//                            let localRect = CGRect(origin: CGPoint(x: 0.0, y: strongSelf.navigationBar.frame.maxY), size: CGSize(width: strongSelf.bounds.width, height: strongSelf.bounds.height - strongSelf.navigationBar.frame.maxY))
//                            return strongSelf.view.convert(localRect, to: nil)
//                        })
//                        controller.window?.presentInGlobalOverlay(pinchController)
//                    }, pinchPreviewFinished: { [weak self] itemNode in
//                        guard let strongSelf = self else {
//                            return
//                        }
//                        for (_, listItemNode) in strongSelf.visibleItemsWithNodes {
//                            if let listItemNode = listItemNode as? InstantPagePeerReferenceNode {
//                                if listItemNode.frame.intersects(itemNode.frame) && listItemNode.frame.maxY <= itemNode.frame.maxY + 2.0 {
//                                    listItemNode.layer.animateAlpha(from: 0.0, to: listItemNode.alpha, duration: 0.25)
//                                    break
//                                }
//                            }
//                        }
//                    }, openPeer: { [weak self] peerId in
//                        self?.openPeer(peerId)
//                    }, openUrl: { [weak self] url in
//                        self?.openUrl(url)
//                    }, updateWebEmbedHeight: { [weak self] height in
//                        self?.updateWebEmbedHeight(embedIndex, height)
//                    }, updateDetailsExpanded: { [weak self] expanded in
//                        self?.updateDetailsExpanded(detailsIndex, expanded)
//                    }, currentExpandedDetails: self.currentExpandedDetails) {
//                        newNode.frame = itemFrame
//                        newNode.updateLayout(size: itemFrame.size, transition: transition)
//                        if let topNode = topNode {
//                            self.scrollNode.insertSubnode(newNode, aboveSubnode: topNode)
//                        } else {
//                            self.scrollNode.insertSubnode(newNode, at: 0)
//                        }
//                        topNode = newNode
//                        self.visibleItemsWithNodes[itemIndex] = newNode
//                        itemNode = newNode
//                        
//                        if let itemNode = itemNode as? InstantPageDetailsNode {
//                            itemNode.requestLayoutUpdate = { [weak self] animated in
//                                if let strongSelf = self {
//                                    strongSelf.updateVisibleItems(visibleBounds: strongSelf.scrollNode.view.bounds, animated: animated)
//                                }
//                            }
//                            
//                            if let previousDetailsNode = previousDetailsNode {
//                                if itemNode.frame.minY - previousDetailsNode.frame.maxY < 1.0 {
//                                    itemNode.previousNode = previousDetailsNode
//                                }
//                            }
//                            previousDetailsNode = itemNode
//                        }
//                    }
//                } else {
//                    if let itemNode = itemNode, itemNode.frame != itemFrame {
//                        transition.updateFrame(node: itemNode, frame: itemFrame)
//                        itemNode.updateLayout(size: itemFrame.size, transition: transition)
//                    }
//                }
//                
//                if let itemNode = itemNode as? InstantPageDetailsNode {
//                    itemNode.updateVisibleItems(visibleBounds: visibleBounds.offsetBy(dx: -itemNode.frame.minX, dy: -itemNode.frame.minY), animated: animated)
//                }
//            }
//        }
//        
//        topNode = topTileNode
//        
//        var tileIndex = -1
//        for tile in self.currentLayoutTiles {
//            tileIndex += 1
//            
//            let tileFrame = effectiveFrameForTile(tile)
//            var tileVisibleFrame = tileFrame
//            tileVisibleFrame.origin.y -= 400.0
//            tileVisibleFrame.size.height += 400.0 * 2.0
//            if tileVisibleFrame.intersects(visibleBounds) {
//                visibleTileIndices.insert(tileIndex)
//                
//                if self.visibleTiles[tileIndex] == nil {
//                    let tileNode = InstantPageTileNode(tile: tile, backgroundColor: theme.pageBackgroundColor)
//                    tileNode.frame = tileFrame
//                    if let topNode = topNode {
//                        self.scrollNode.insertSubnode(tileNode, aboveSubnode: topNode)
//                    } else {
//                        self.scrollNode.insertSubnode(tileNode, at: 0)
//                    }
//                    topNode = tileNode
//                    self.visibleTiles[tileIndex] = tileNode
//                } else {
//                    if visibleTiles[tileIndex]!.frame != tileFrame {
//                        transition.updateFrame(node: self.visibleTiles[tileIndex]!, frame: tileFrame)
//                    }
//                }
//            }
//        }
//    
//        if let currentLayout = self.currentLayout {
//            let effectiveContentHeight = currentLayout.contentSize.height - collapseOffset
//            if effectiveContentHeight != self.scrollNode.view.contentSize.height {
//                transition.animateView {
//                    self.scrollNode.view.contentSize = CGSize(width: currentLayout.contentSize.width, height: effectiveContentHeight)
//                }
//                let previousFrame = self.scrollNodeFooter.frame
//                self.scrollNodeFooter.frame = CGRect(origin: CGPoint(x: 0.0, y: effectiveContentHeight), size: CGSize(width: previousFrame.width, height: 2000.0))
//                transition.animateFrame(node: self.scrollNodeFooter, from: previousFrame)
//            }
//        }
//        
//        var removeTileIndices: [Int] = []
//        for (index, tileNode) in self.visibleTiles {
//            if !visibleTileIndices.contains(index) {
//                removeTileIndices.append(index)
//                tileNode.removeFromSupernode()
//            }
//        }
//        for index in removeTileIndices {
//            self.visibleTiles.removeValue(forKey: index)
//        }
//        
//        var removeItemIndices: [Int] = []
//        for (index, itemNode) in self.visibleItemsWithNodes {
//            if !visibleItemIndices.contains(index) {
//                removeItemIndices.append(index)
//                itemNode.removeFromSupernode()
//            } else {
//                var itemFrame = itemNode.frame
//                let itemThreshold: CGFloat = 200.0
//                itemFrame.origin.y -= itemThreshold
//                itemFrame.size.height += itemThreshold * 2.0
//                itemNode.updateIsVisible(visibleBounds.intersects(itemFrame))
//            }
//        }
//        for index in removeItemIndices {
//            self.visibleItemsWithNodes.removeValue(forKey: index)
//        }
//    }
//    
//    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        self.updateVisibleItems(visibleBounds: self.scrollNode.view.bounds)
//        self.previousContentOffset = self.scrollNode.view.contentOffset
//    }
//    
//    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
//        self.isDeceleratingBecauseOfDragging = decelerate
//        if !decelerate {
//            self.updateNavigationBar(forceState: true)
//        }
//    }
//    
//    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
//        self.isDeceleratingBecauseOfDragging = false
//    }
//    
//    private func scrollableContentOffset(item: InstantPageScrollableItem) -> CGPoint {
//        var contentOffset = CGPoint()
//        for (_, itemNode) in self.visibleItemsWithNodes {
//            if let itemNode = itemNode as? InstantPageScrollableNode, itemNode.item === item {
//                contentOffset = itemNode.contentOffset
//                break
//            }
//        }
//        return contentOffset
//    }
//    
//    private func nodeForDetailsItem(_ item: InstantPageDetailsItem) -> InstantPageDetailsNode? {
//        for (_, itemNode) in self.visibleItemsWithNodes {
//            if let detailsNode = itemNode as? InstantPageDetailsNode, detailsNode.item === item {
//                return detailsNode
//            }
//        }
//        return nil
//    }
//    
//    private func effectiveSizeForDetails(_ item: InstantPageDetailsItem) -> CGSize {
//        if let node = nodeForDetailsItem(item) {
//            return CGSize(width: item.frame.width, height: node.effectiveContentSize.height + item.titleHeight)
//        } else {
//            return item.frame.size
//        }
//    }
//    
//    private func effectiveFrameForTile(_ tile: InstantPageTile) -> CGRect {
//        let layoutOrigin = tile.frame.origin
//        var origin = layoutOrigin
//        for item in self.currentDetailsItems {
//            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
//            if layoutOrigin.y >= item.frame.maxY {
//                let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
//                origin.y += height - item.frame.height
//            }
//        }
//        return CGRect(origin: origin, size: tile.frame.size)
//    }
//    
//    private func effectiveFrameForItem(_ item: InstantPageItem) -> CGRect {
//        let layoutOrigin = item.frame.origin
//        var origin = layoutOrigin
//        
//        for item in self.currentDetailsItems {
//            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
//            if layoutOrigin.y >= item.frame.maxY {
//                let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
//                origin.y += height - item.frame.height
//            }
//        }
//        
//        if let item = item as? InstantPageDetailsItem {
//            let expanded = self.currentExpandedDetails?[item.index] ?? item.initiallyExpanded
//            let height = expanded ? self.effectiveSizeForDetails(item).height : item.titleHeight
//            return CGRect(origin: origin, size: CGSize(width: item.frame.width, height: height))
//        } else {
//            return CGRect(origin: origin, size: item.frame.size)
//        }
//    }
//    
//    private func textItemAtLocation(_ location: CGPoint) -> (InstantPageTextItem, CGPoint)? {
//        if let currentLayout = self.currentLayout {
//            for item in currentLayout.items {
//                let itemFrame = self.effectiveFrameForItem(item)
//                if itemFrame.contains(location) {
//                    if let item = item as? InstantPageTextItem, item.selectable {
//                        return (item, CGPoint(x: itemFrame.minX - item.frame.minX, y: itemFrame.minY - item.frame.minY))
//                    } else if let item = item as? InstantPageScrollableItem {
//                        let contentOffset = scrollableContentOffset(item: item)
//                        if let (textItem, parentOffset) = item.textItemAtLocation(location.offsetBy(dx: -itemFrame.minX + contentOffset.x, dy: -itemFrame.minY)) {
//                            return (textItem, itemFrame.origin.offsetBy(dx: parentOffset.x - contentOffset.x, dy: parentOffset.y))
//                        }
//                    } else if let item = item as? InstantPageDetailsItem {
//                        for (_, itemNode) in self.visibleItemsWithNodes {
//                            if let itemNode = itemNode as? InstantPageDetailsNode, itemNode.item === item {
//                                if let (textItem, parentOffset) = itemNode.textItemAtLocation(location.offsetBy(dx: -itemFrame.minX, dy: -itemFrame.minY)) {
//                                    return (textItem, itemFrame.origin.offsetBy(dx: parentOffset.x, dy: parentOffset.y))
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        return nil
//    }
//    
//    private func urlForTapLocation(_ location: CGPoint) -> InstantPageUrlItem? {
//        if let (item, parentOffset) = self.textItemAtLocation(location) {
//            return item.urlAttribute(at: location.offsetBy(dx: -item.frame.minX - parentOffset.x, dy: -item.frame.minY - parentOffset.y))
//        }
//        return nil
//    }
//    
//    private func longPressMedia(_ media: InstantPageMedia) {
//        let controller = makeContextMenuController(actions: [ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.strings.Conversation_ContextMenuCopy), action: { [weak self] in
//            if let strongSelf = self, let image = media.media as? TelegramMediaImage {
//                let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: image.representations, immediateThumbnailData: image.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
//                let _ = copyToPasteboard(context: strongSelf.context, postbox: strongSelf.context.account.postbox, userLocation: strongSelf.sourceLocation.userLocation, mediaReference: .standalone(media: media)).start()
//            }
//        }), ContextMenuAction(content: .text(title: self.strings.Conversation_LinkDialogSave, accessibilityLabel: self.strings.Conversation_LinkDialogSave), action: { [weak self] in
//            if let strongSelf = self, let image = media.media as? TelegramMediaImage {
//                let media = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: image.representations, immediateThumbnailData: image.immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
//                let _ = saveToCameraRoll(context: strongSelf.context, postbox: strongSelf.context.account.postbox, userLocation: strongSelf.sourceLocation.userLocation, mediaReference: .standalone(media: media)).start()
//            }
//        }), ContextMenuAction(content: .text(title: self.strings.Conversation_ContextMenuShare, accessibilityLabel: self.strings.Conversation_ContextMenuShare), action: { [weak self] in
//            if let strongSelf = self, let webPage = strongSelf.webPage, let image = media.media as? TelegramMediaImage {
//                strongSelf.present(ShareController(context: strongSelf.context, subject: .image(image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.media(media: .webPage(webPage: WebpageReference(webPage), media: image), resource: $0.resource)) }))), nil)
//            }
//        })], catchTapsOutside: true)
//        self.present(controller, ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
//            if let strongSelf = self {
//                for (_, itemNode) in strongSelf.visibleItemsWithNodes {
//                    if let (node, _, _) = itemNode.transitionNode(media: media) {
//                        return (strongSelf.scrollNode, node.convert(node.bounds, to: strongSelf.scrollNode), strongSelf, strongSelf.bounds)
//                    }
//                }
//            }
//            return nil
//        }))
//    }
//    
//    @objc private func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
//        switch recognizer.state {
//            case .ended:
//                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
//                    switch gesture {
//                        case .tap:
//                            break
////                            if let url = self.urlForTapLocation(location) {
////                                self.openUrl(url)
////                            }
//                        case .longTap:
//                            break
////                            if let theme = self.theme, let url = self.urlForTapLocation(location) {
////                                let canOpenIn = availableOpenInOptions(context: self.context, item: .url(url: url.url)).count > 1
////                                let openText = canOpenIn ? self.strings.Conversation_FileOpenIn : self.strings.Conversation_LinkDialogOpen
////                                let actionSheet = ActionSheetController(instantPageTheme: theme)
////                                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
////                                    ActionSheetTextItem(title: url.url),
////                                    ActionSheetButtonItem(title: openText, color: .accent, action: { [weak self, weak actionSheet] in
////                                        actionSheet?.dismissAnimated()
////                                        if let strongSelf = self {
////                                            if canOpenIn {
////                                                strongSelf.openUrlIn(url)
////                                            } else {
////                                                strongSelf.openUrl(url)
////                                            }
////                                        }
////                                    }),
////                                    ActionSheetButtonItem(title: self.strings.ShareMenu_CopyShareLink, color: .accent, action: { [weak actionSheet] in
////                                        actionSheet?.dismissAnimated()
////                                        UIPasteboard.general.string = url.url
////                                    }),
////                                    ActionSheetButtonItem(title: self.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
////                                        actionSheet?.dismissAnimated()
////                                        if let link = URL(string: url.url) {
////                                            let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
////                                        }
////                                    })
////                                ]), ActionSheetItemGroup(items: [
////                                    ActionSheetButtonItem(title: self.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
////                                        actionSheet?.dismissAnimated()
////                                    })
////                                ])])
////                                self.present(actionSheet, nil)
////                            } else if let (item, parentOffset) = self.textItemAtLocation(location) {
////                                let textFrame = item.frame
////                                var itemRects = item.lineRects()
////                                for i in 0 ..< itemRects.count {
////                                    itemRects[i] = itemRects[i].offsetBy(dx: parentOffset.x + textFrame.minX, dy: parentOffset.y + textFrame.minY).insetBy(dx: -2.0, dy: -2.0)
////                                }
////                                self.updateTextSelectionRects(itemRects, text: item.plainText())
////                            }
//                        default:
//                            break
//                    }
//                }
//            default:
//                break
//        }
//    }
//    
//    private func updateTextSelectionRects(_ rects: [CGRect], text: String?) {
//        if let text = text, !rects.isEmpty {
//            let textSelectionNode: LinkHighlightingNode
//            if let current = self.textSelectionNode {
//                textSelectionNode = current
//            } else {
//                textSelectionNode = LinkHighlightingNode(color: UIColor.lightGray.withAlphaComponent(0.4))
//                textSelectionNode.isUserInteractionEnabled = false
//                self.textSelectionNode = textSelectionNode
//                self.scrollNode.addSubnode(textSelectionNode)
//            }
//            textSelectionNode.frame = CGRect(origin: CGPoint(), size: self.scrollNode.bounds.size)
//            textSelectionNode.updateRects(rects)
//            
//            var coveringRect = rects[0]
//            for i in 1 ..< rects.count {
//                coveringRect = coveringRect.union(rects[i])
//            }
//            
//            let context = self.context
//            let strings = self.strings
//            let _ = (context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
//            |> take(1)
//            |> deliverOnMainQueue).start(next: { [weak self] sharedData in
//                let translationSettings: TranslationSettings
//                if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
//                    translationSettings = current
//                } else {
//                    translationSettings = TranslationSettings.defaultSettings
//                }
//                
//                var actions: [ContextMenuAction] = [ContextMenuAction(content: .text(title: strings.Conversation_ContextMenuCopy, accessibilityLabel: strings.Conversation_ContextMenuCopy), action: { [weak self] in
//                    UIPasteboard.general.string = text
//                    
//                    if let strongSelf = self {
//                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
//                        strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
//                    }
//                }), ContextMenuAction(content: .text(title: strings.Conversation_ContextMenuShare, accessibilityLabel: strings.Conversation_ContextMenuShare), action: { [weak self] in
//                    if let strongSelf = self, let webPage = strongSelf.webPage, case let .Loaded(content) = webPage.content {
//                        strongSelf.present(ShareController(context: strongSelf.context, subject: .quote(text: text, url: content.url)), nil)
//                    }
//                })]
//                
//                let (canTranslate, language) = canTranslateText(context: context, text: text, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: false, ignoredLanguages: translationSettings.ignoredLanguages)
//                if canTranslate {
//                    actions.append(ContextMenuAction(content: .text(title: strings.Conversation_ContextMenuTranslate, accessibilityLabel: strings.Conversation_ContextMenuTranslate), action: { [weak self] in
//                        let controller = TranslateScreen(context: context, text: text, canCopy: true, fromLanguage: language)
//                        controller.pushController = { [weak self] c in
//                            (self?.controller?.navigationController as? NavigationController)?._keepModalDismissProgress = true
//                            self?.controller?.push(c)
//                        }
//                        controller.presentController = { [weak self] c in
//                            self?.controller?.present(c, in: .window(.root))
//                        }
//                        self?.present(controller, nil)
//                    }))
//                }
//                
//                let controller = makeContextMenuController(actions: actions)
//                controller.dismissed = { [weak self] in
//                    self?.updateTextSelectionRects([], text: nil)
//                }
//                self?.present(controller, ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
//                    if let strongSelf = self {
//                        return (strongSelf.scrollNode, coveringRect.insetBy(dx: -3.0, dy: -3.0), strongSelf, strongSelf.bounds)
//                    } else {
//                        return nil
//                    }
//                }))
//            })
//            
//            textSelectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
//        } else if let textSelectionNode = self.textSelectionNode {
//            self.textSelectionNode = nil
//            textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
//                textSelectionNode?.removeFromSupernode()
//            })
//        }
//    }
//    
//    private func findAnchorItem(_ anchor: String, items: [InstantPageItem]) -> (InstantPageItem, CGFloat, Bool, [InstantPageDetailsItem])? {
//        for item in items {
//            if let item = item as? InstantPageAnchorItem, item.anchor == anchor {
//                return (item, -10.0, false, [])
//            } else if let item = item as? InstantPageTextItem {
//                if let (lineIndex, empty) = item.anchors[anchor] {
//                    return (item, item.lines[lineIndex].frame.minY - 10.0, !empty, [])
//                }
//            }
//            else if let item = item as? InstantPageTableItem {
//                if let (offset, empty) = item.anchors[anchor] {
//                    return (item, offset - 10.0, !empty, [])
//                }
//            }
//            else if let item = item as? InstantPageDetailsItem {
//                if let (foundItem, offset, reference, detailsItems) = self.findAnchorItem(anchor, items: item.items) {
//                    var detailsItems = detailsItems
//                    detailsItems.insert(item, at: 0)
//                    return (foundItem, offset, reference, detailsItems)
//                }
//            }
//        }
//        return nil
//    }
//    
//    private func presentReferenceView(item: InstantPageTextItem, referenceAnchor: String) {
////        guard let theme = self.theme, let webPage = self.webPage else {
////            return
////        }
////        
////        var targetAnchor: InstantPageTextAnchorItem?
////        for (name, (line, _)) in item.anchors {
////            if name == referenceAnchor {
////                let anchors = item.lines[line].anchorItems
////                for anchor in anchors {
////                    if anchor.name == referenceAnchor {
////                        targetAnchor = anchor
////                        break
////                    }
////                }
////            }
////        }
////        
////        guard let anchorText = targetAnchor?.anchorText else {
////            return
////        }
////        
////        let controller = InstantPageReferenceController(context: self.context, sourceLocation: self.sourceLocation, theme: theme, webPage: webPage, anchorText: anchorText, openUrl: { [weak self] url in
////            self?.openUrl(url)
////        }, openUrlIn: { [weak self] url in
////            self?.openUrlIn(url)
////        }, present: { [weak self] c, a in
////            self?.present(c, a)
////        })
////        self.present(controller, nil)
//    }
//    
//    private func scrollToAnchor(_ anchor: String) {
//        guard let items = self.currentLayout?.items else {
//            return
//        }
//        
//        if !anchor.isEmpty {
//            if let (item, lineOffset, reference, detailsItems) = findAnchorItem(String(anchor), items: items) {
//                if let item = item as? InstantPageTextItem, reference {
//                    self.presentReferenceView(item: item, referenceAnchor: anchor)
//                } else {
//                    var previousDetailsNode: InstantPageDetailsNode?
//                    var containerOffset: CGFloat = 0.0
//                    for detailsItem in detailsItems {
//                        if let previousNode = previousDetailsNode {
//                            previousNode.contentNode.updateDetailsExpanded(detailsItem.index, true, animated: false)
//                            let frame = previousNode.effectiveFrameForItem(detailsItem)
//                            containerOffset += frame.minY
//                            
//                            previousDetailsNode = previousNode.contentNode.nodeForDetailsItem(detailsItem)
//                            previousDetailsNode?.setExpanded(true, animated: false)
//                        } else {
//                            self.updateDetailsExpanded(detailsItem.index, true, animated: false)
//                            let frame = self.effectiveFrameForItem(detailsItem)
//                            containerOffset += frame.minY
//                            
//                            previousDetailsNode = self.nodeForDetailsItem(detailsItem)
//                            previousDetailsNode?.setExpanded(true, animated: false)
//                        }
//                    }
//                    
//                    let frame: CGRect
//                    if let previousDetailsNode = previousDetailsNode {
//                        frame = previousDetailsNode.effectiveFrameForItem(item)
//                    } else {
//                        frame = self.effectiveFrameForItem(item)
//                    }
//                    
//                    var targetY = min(containerOffset + frame.minY + lineOffset, self.scrollNode.view.contentSize.height - self.scrollNode.frame.height)
//                    if targetY < self.scrollNode.view.contentOffset.y {
//                        targetY -= self.scrollNode.view.contentInset.top
//                    } else {
//                        targetY -= self.containerLayout?.statusBarHeight ?? 20.0
//                    }
//                    self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: targetY), animated: true)
//                }
//            } else if let webPage = self.webPage, case let .Loaded(content) = webPage.content, let instantPage = content.instantPage, !instantPage.isComplete {
//                self.loadProgress.set(0.5)
//                self.pendingAnchor = anchor
//            }
//        } else {
//            self.scrollNode.view.setContentOffset(CGPoint(x: 0.0, y: -self.scrollNode.view.contentInset.top), animated: true)
//        }
//    }
//    
//    private func updateWebEmbedHeight(_ index: Int, _ height: CGFloat) {
//        let currentHeight = self.currentWebEmbedHeights[index]
//        if height != currentHeight {
//            if let currentHeight = currentHeight, currentHeight > height {
//                return
//            }
//            self.currentWebEmbedHeights[index] = height
//            
//            let signal: Signal<Void, NoError> = (.complete() |> delay(0.08, queue: Queue.mainQueue()))
//            self.updateLayoutDisposable.set(signal.start(completed: { [weak self] in
//                if let strongSelf = self {
//                    strongSelf.updateLayout()
//                    strongSelf.updateVisibleItems(visibleBounds: strongSelf.scrollNode.view.bounds)
//                }
//            }))
//        }
//    }
//    
//    private func updateDetailsExpanded(_ index: Int, _ expanded: Bool, animated: Bool = true) {
//        if var currentExpandedDetails = self.currentExpandedDetails {
//            currentExpandedDetails[index] = expanded
//            self.currentExpandedDetails = currentExpandedDetails
//        }
//        self.updateVisibleItems(visibleBounds: self.scrollNode.view.bounds, animated: animated)
//    }
//    
//}
//
//final class BrowserInstantPageContent: UIView, BrowserContent {
//    var onScrollingUpdate: (ContentScrollingUpdate) -> Void
//    
//    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ComponentFlow.Transition) {
//        
//    }
//    
//    private var _state: BrowserContentState
//    private let statePromise: Promise<BrowserContentState>
//    
//    private let webPage: TelegramMediaWebpage
//    private var initialized = false
//    
//    var state: Signal<BrowserContentState, NoError> {
//        return self.statePromise.get()
//    }
//    
//    init(context: AccountContext, webPage: TelegramMediaWebpage, url: String) {
//        self.webPage = webPage
//        
//        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
//
//        let title: String
//        if case let .Loaded(content) = webPage.content {
//            title = content.title ?? ""
//        } else {
//            title = ""
//        }
//        
//        self._state = BrowserContentState(title: title, url: url, estimatedProgress: 0.0, contentType: .instantPage)
//        self.statePromise = Promise<BrowserContentState>(self._state)
//        
//        super.init()
//        
//        
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    func navigateBack() {
//        
//    }
//    
//    func navigateForward() {
//        
//    }
//    
//    func setFontSize(_ fontSize: CGFloat) {
//        
//    }
//    
//    func setForceSerif(_ force: Bool) {
//        
//    }
//    
//    func setSearch(_ query: String?, completion: ((Int) -> Void)?) {
//        
//    }
//    
//    func scrollToPreviousSearchResult(completion: ((Int, Int) -> Void)?) {
//        
//    }
//    
//    func scrollToNextSearchResult(completion: ((Int, Int) -> Void)?) {
//        
//    }
//    
//    func scrollToTop() {
//        
//    }
//    
//    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
////        let layout = ContainerViewLayout(size: size, metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: insets.bottom, right: 0.0), safeInsets: UIEdgeInsets(top: 0.0, left: insets.left, bottom: 0.0, right: insets.right), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false)
////        self.instantPageNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
////        self.instantPageNode.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height)
////        //transition.updateFrame(view: self.webView, frame: CGRect(origin: CGPoint(x: 0.0, y: 56.0), size: CGSize(width: size.width, height: size.height - 56.0)))
////
////        if !self.initialized {
////            self.initialized = true
////            self.instantPageNode.updateWebPage(self.webPage, anchor: nil)
////        }
//    }
//}
