import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import WallpaperBackgroundNode
import ListItemComponentAdaptor

final class PeerNameColorChatPreviewItem: ListViewItem, ItemListItem, ListItemComponentAdaptor.ItemGenerator {
    struct MessageItem: Equatable {
        static func ==(lhs: MessageItem, rhs: MessageItem) -> Bool {
            if lhs.outgoing != rhs.outgoing {
                return false
            }
            if lhs.peerId != rhs.peerId {
                return false
            }
            if lhs.author != rhs.author {
                return false
            }
            if lhs.photo != rhs.photo {
                return false
            }
            if lhs.nameColor != rhs.nameColor {
                return false
            }
            if lhs.backgroundEmojiId != rhs.backgroundEmojiId {
                return false
            }
            if let lhsReply = lhs.reply, let rhsReply = rhs.reply, lhsReply.0 != rhsReply.0 || lhsReply.1 != rhsReply.1 {
                return false
            } else if (lhs.reply == nil) != (rhs.reply == nil) {
                return false
            }
            if let lhsLinkPreview = lhs.linkPreview, let rhsLinkPreview = rhs.linkPreview, lhsLinkPreview.0 != rhsLinkPreview.0 || lhsLinkPreview.1 != rhsLinkPreview.1 || lhsLinkPreview.2 != rhsLinkPreview.2 {
                return false
            } else if (lhs.linkPreview == nil) != (rhs.linkPreview == nil) {
                return false
            }
            if lhs.text != rhs.text {
                return false
            }
            return true
        }
        
        let outgoing: Bool
        let peerId: EnginePeer.Id
        let author: String
        let photo: [TelegramMediaImageRepresentation]
        let nameColor: PeerNameColor
        let backgroundEmojiId: Int64?
        let reply: (String, String)?
        let linkPreview: (String, String, String)?
        let text: String
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let componentTheme: PresentationTheme
    let strings: PresentationStrings
    let sectionId: ItemListSectionId
    let fontSize: PresentationFontSize
    let chatBubbleCorners: PresentationChatBubbleCorners
    let wallpaper: TelegramWallpaper
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let messageItems: [MessageItem]
    
    init(context: AccountContext, theme: PresentationTheme, componentTheme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, wallpaper: TelegramWallpaper, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, messageItems: [MessageItem]) {
        self.context = context
        self.theme = theme
        self.componentTheme = componentTheme
        self.strings = strings
        self.sectionId = sectionId
        self.fontSize = fontSize
        self.chatBubbleCorners = chatBubbleCorners
        self.wallpaper = wallpaper
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.messageItems = messageItems
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = PeerNameColorChatPreviewItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? PeerNameColorChatPreviewItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    public func item() -> ListViewItem {
        return self
    }
    
    public static func ==(lhs: PeerNameColorChatPreviewItem, rhs: PeerNameColorChatPreviewItem) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.componentTheme !== rhs.componentTheme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.chatBubbleCorners != rhs.chatBubbleCorners {
            return false
        }
        if lhs.wallpaper != rhs.wallpaper {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.nameDisplayOrder != rhs.nameDisplayOrder {
            return false
        }
        if lhs.messageItems != rhs.messageItems {
            return false
        }
        return true
    }
}

final class PeerNameColorChatPreviewItemNode: ListViewItemNode {
    private var backgroundNode: WallpaperBackgroundNode?
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let containerNode: ASDisplayNode
    private var messageNodes: [ListViewItemNode]?
    private var itemHeaderNodes: [ListViewItemNode.HeaderId: ListViewItemHeaderNode] = [:]
    
    private var item: PeerNameColorChatPreviewItem?
    
    private let disposable = MetaDisposable()
    
    init() {
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.containerNode = ASDisplayNode()
        self.containerNode.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.containerNode)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func asyncLayout() -> (_ item: PeerNameColorChatPreviewItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentNodes = self.messageNodes

        var currentBackgroundNode = self.backgroundNode
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            if currentBackgroundNode == nil {
                currentBackgroundNode = createWallpaperBackgroundNode(context: item.context, forChatDisplay: false)
                currentBackgroundNode?.update(wallpaper: item.wallpaper, animated: false)
                currentBackgroundNode?.updateBubbleTheme(bubbleTheme: item.componentTheme, bubbleCorners: item.chatBubbleCorners)
            }

            var insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1))
            
            var items: [ListViewItem] = []
            for messageItem in item.messageItems.reversed() {
                let authorPeerId = messageItem.peerId
                
                var peers = SimpleDictionary<PeerId, Peer>()
                var messages = SimpleDictionary<MessageId, Message>()
                
                peers[authorPeerId] = TelegramUser(id: authorPeerId, accessHash: nil, firstName: messageItem.author, lastName: "", username: nil, phone: nil, photo: messageItem.photo, botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: messageItem.nameColor, backgroundEmojiId: messageItem.backgroundEmojiId, profileColor: nil, profileBackgroundEmojiId: nil)
                
                let replyMessageId = MessageId(peerId: peerId, namespace: 0, id: 3)
                if let (_, text) = messageItem.reply {
                    messages[replyMessageId] = Message(stableId: 3, stableVersion: 0, id: replyMessageId, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66000, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[authorPeerId], text: text, attributes: [], media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                }
                
                var media: [Media] = []
                if let (site, title, text) = messageItem.linkPreview, params.width > 320.0 {
                    media.append(TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(url: "", displayUrl: "", hash: 0, type: nil, websiteName: site, title: title, text: text, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, image: nil, file: nil, story: nil, attributes: [], instantPage: nil))))
                }
                
                let message = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66000, flags: messageItem.outgoing ? [] : [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[authorPeerId], text: messageItem.text, attributes: messageItem.reply != nil ? [ReplyMessageAttribute(messageId: replyMessageId, threadMessageId: nil, quote: nil, isQuote: false)] : [], media: media, peers: peers, associatedMessages: messages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
                items.append(item.context.sharedContext.makeChatMessagePreviewItem(context: item.context, messages: [message], theme: item.componentTheme, strings: item.strings, wallpaper: item.wallpaper, fontSize: item.fontSize, chatBubbleCorners: item.chatBubbleCorners, dateTimeFormat: item.dateTimeFormat, nameOrder: item.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: currentBackgroundNode, availableReactions: nil, accountPeer: nil, isCentered: false))
            }
            
            var nodes: [ListViewItemNode] = []
            if let messageNodes = currentNodes {
                nodes = messageNodes
                for i in 0 ..< items.count {
                    let itemNode = messageNodes[i]
                    items[i].updateNode(async: { $0() }, node: {
                        return itemNode
                    }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                        let nodeFrame = CGRect(origin: itemNode.frame.origin, size: CGSize(width: layout.size.width, height: layout.size.height))
                        
                        itemNode.contentSize = layout.contentSize
                        itemNode.insets = layout.insets
                        itemNode.frame = nodeFrame
                        itemNode.isUserInteractionEnabled = false
                        
                        Queue.mainQueue().after(0.01) {
                            apply(ListViewItemApply(isOnScreen: true))
                        }
                    })
                }
            } else {
                var messageNodes: [ListViewItemNode] = []
                for i in 0 ..< items.count {
                    var itemNode: ListViewItemNode?
                    items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                        itemNode = node
                        apply().1(ListViewItemApply(isOnScreen: true))
                    })
                    itemNode!.isUserInteractionEnabled = false
                    messageNodes.append(itemNode!)
                }
                nodes = messageNodes
            }
            
            var contentSize = CGSize(width: params.width, height: 4.0 + 4.0)
            for node in nodes {
                contentSize.height += node.frame.size.height
            }
            insets = itemListNeighborsGroupedInsets(neighbors, params)
            if params.width <= 320.0 {
                insets.top = 0.0
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let leftInset = params.leftInset
            let rightInset = params.leftInset
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let currentBackgroundNode {
                        currentBackgroundNode.update(wallpaper: item.wallpaper, animated: false)
                        currentBackgroundNode.updateBubbleTheme(bubbleTheme: item.theme, bubbleCorners: item.chatBubbleCorners)
                    }
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                    
                    if let currentItem, currentItem.messageItems.first?.nameColor != item.messageItems.first?.nameColor || currentItem.messageItems.first?.backgroundEmojiId != item.messageItems.first?.backgroundEmojiId || currentItem.theme !== item.theme || currentItem.wallpaper != item.wallpaper {
                        if let snapshot = strongSelf.view.snapshotView(afterScreenUpdates: false) {
                            snapshot.frame = CGRect(origin: CGPoint(x: 0.0, y: -insets.top), size: snapshot.frame.size)
                            strongSelf.view.addSubview(snapshot)
                            snapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: 0.25, removeOnCompletion: false, completion: { _ in
                                snapshot.removeFromSuperview()
                            })
                        }
                    }
                    
                    strongSelf.messageNodes = nodes
                    var topOffset: CGFloat = 4.0
                    for node in nodes {
                        if node.supernode == nil {
                            strongSelf.containerNode.addSubnode(node)
                        }
                        node.updateFrame(CGRect(origin: CGPoint(x: 0.0, y: topOffset), size: node.frame.size), within: layoutSize)
                        topOffset += node.frame.size.height
                        
                        if let header = node.headers()?.last {
                            let headerFrame = CGRect(origin: CGPoint(x: 0.0, y: 7.0), size: CGSize(width: layoutSize.width, height: header.height))
                            let stickLocationDistanceFactor: CGFloat = 0.0
                            
                            let id = header.id
                            let headerNode: ListViewItemHeaderNode
                            if let current = strongSelf.itemHeaderNodes[id] {
                                headerNode = current
                                headerNode.updateFrame(headerFrame, within: layoutSize)
                                
                                if headerNode.item !== header {
                                    header.updateNode(headerNode, previous: nil, next: nil)
                                    headerNode.item = header
                                }
                                headerNode.updateLayoutInternal(size: headerFrame.size, leftInset: leftInset, rightInset: rightInset)
                                headerNode.updateStickDistanceFactor(stickLocationDistanceFactor, transition: .immediate)
                            } else {
                                headerNode = header.node(synchronousLoad: true)
                                if headerNode.item !== header {
                                    header.updateNode(headerNode, previous: nil, next: nil)
                                    headerNode.item = header
                                }
                                headerNode.frame = headerFrame
                                headerNode.updateLayoutInternal(size: headerFrame.size, leftInset: leftInset, rightInset: rightInset)
                                strongSelf.itemHeaderNodes[id] = headerNode

                                strongSelf.containerNode.addSubnode(headerNode)
                                headerNode.updateStickDistanceFactor(stickLocationDistanceFactor, transition: .immediate)
                            }
                        }
                    }
                    
                    if let currentBackgroundNode = currentBackgroundNode, strongSelf.backgroundNode !== currentBackgroundNode {
                        strongSelf.backgroundNode = currentBackgroundNode
                        strongSelf.insertSubnode(currentBackgroundNode, at: 0)
                    }
                    
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor

                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
                    }
                    
                    if params.isStandalone {
                        strongSelf.topStripeNode.isHidden = true
                        strongSelf.bottomStripeNode.isHidden = true
                        strongSelf.maskNode.isHidden = true
                    } else {
                        let hasCorners = itemListHasRoundedBlockLayout(params)
                        
                        var hasTopCorners = false
                        var hasBottomCorners = false
                        
                        switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            hasTopCorners = true
                            strongSelf.topStripeNode.isHidden = hasCorners
                        }
                        let bottomStripeInset: CGFloat
                        let bottomStripeOffset: CGFloat
                        switch neighbors.bottom {
                            case .sameSection(false):
                                bottomStripeInset = 0.0
                                bottomStripeOffset = -separatorHeight
                                strongSelf.bottomStripeNode.isHidden = false
                            default:
                                bottomStripeInset = 0.0
                                bottomStripeOffset = 0.0
                                hasBottomCorners = true
                                strongSelf.bottomStripeNode.isHidden = hasCorners
                        }
                        
                        strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.componentTheme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                        
                        strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    
                    let displayMode: WallpaperDisplayMode
                    if abs(params.availableHeight - params.width) < 100.0, params.availableHeight > 700.0 {
                        displayMode = .halfAspectFill
                    } else {
                        if backgroundFrame.width > backgroundFrame.height * 4.0 {
                            if params.availableHeight < 700.0 {
                                displayMode = .halfAspectFill
                            } else {
                                displayMode = .aspectFill
                            }
                        } else {
                            displayMode = .aspectFill
                        }
                    }
                    
                    if let backgroundNode = strongSelf.backgroundNode {
                        backgroundNode.frame = backgroundFrame
                        backgroundNode.updateLayout(size: backgroundNode.bounds.size, displayMode: displayMode, transition: .immediate)
                    }
                    strongSelf.maskNode.frame = backgroundFrame.insetBy(dx: params.leftInset, dy: 0.0)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
