import Display
import UIKit
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatListUI
import SegmentedControlNode
import ChatListSearchItemHeader

final class HashtagSearchControllerNode: ASDisplayNode {
    private let context: AccountContext
    private weak var controller: HashtagSearchController?
    private let query: String
    
    private let navigationBar: NavigationBar?

    private let segmentedControlNode: SegmentedControlNode
    let listNode: ListView
    let shimmerNode: ChatListSearchShimmerNode
    
    let chatController: ChatController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    private var enqueuedTransitions: [(ChatListSearchContainerTransition, Bool)] = []
    private var hasValidLayout = false
    
    init(context: AccountContext, controller: HashtagSearchController, peer: EnginePeer?, query: String, navigationBar: NavigationBar?, navigationController: NavigationController?) {
        self.context = context
        self.controller = controller
        self.query = query
        self.navigationBar = navigationBar
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.shimmerNode = ChatListSearchShimmerNode(key: .chats)
        self.shimmerNode.isUserInteractionEnabled = false
        self.shimmerNode.allowsGroupOpacity = true
        
        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
       
        var items: [String] = []
        if peer?.id == context.account.peerId {
            items.append(presentationData.strings.Conversation_SavedMessages)
        } else if let id = peer?.id, id.isReplies {
            items.append(presentationData.strings.DialogList_Replies)
        } else {
            items.append(peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) ?? "")
        }
        items.append(presentationData.strings.HashtagSearch_AllChats)
        self.segmentedControlNode = SegmentedControlNode(theme: SegmentedControlTheme(theme: presentationData.theme), items: items.map { SegmentedControlItem(title: $0) }, selectedIndex: controller.all ? 1 : 0)
        
        if let peer = peer {
            self.chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .inline(navigationController))
        } else {
            self.chatController = nil
        }
    
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.listNode)
//        self.addSubnode(self.shimmerNode)
        
        if controller.all {
            self.chatController?.displayNode.isHidden = true
            self.listNode.isHidden = false
        } else {
            self.chatController?.displayNode.isHidden = false
            self.listNode.isHidden = true
        }
        
        self.segmentedControlNode.selectedIndexChanged = { [weak self] index in
            if let strongSelf = self {
                if index == 0 {
                    strongSelf.chatController?.displayNode.isHidden = false
                    strongSelf.listNode.isHidden = true
                } else {
                    strongSelf.chatController?.displayNode.isHidden = true
                    strongSelf.listNode.isHidden = false
                }
            }
        }
        
        self.chatController?.isSelectingMessagesUpdated = { [weak self] isSelecting in
            if let strongSelf = self {
                let button: UIBarButtonItem? = isSelecting ? UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .done, target: self, action: #selector(strongSelf.cancelPressed)) : nil
                strongSelf.controller?.navigationItem.setRightBarButton(button, animated: true)
            }
        }
    }
    
    @objc private func cancelPressed() {
        self.chatController?.cancelSelectingMessages()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.backgroundColor = theme.chatList.backgroundColor
        
        self.segmentedControlNode.updateTheme(SegmentedControlTheme(theme: theme))
        
        self.listNode.forEachItemHeaderNode({ itemHeaderNode in
            if let itemHeaderNode = itemHeaderNode as? ChatListSearchItemHeaderNode {
                itemHeaderNode.updateTheme(theme: theme)
            }
        })
    }
    
    func enqueueTransition(_ transition: ChatListSearchContainerTransition, firstTime: Bool) {
        self.enqueuedTransitions.append((transition, firstTime))
        
        if self.hasValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            let options = ListViewDeleteAndInsertOptions()
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
    
    func scrollToTop() {
        if self.segmentedControlNode.selectedIndex == 0 {
            self.chatController?.scrollToTop?()
        } else {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.containerLayout = (layout, navigationBarHeight)
        
        if self.chatController != nil && self.segmentedControlNode.supernode == nil {
            self.navigationBar?.additionalContentNode.addSubnode(self.segmentedControlNode)
        }
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        let toolbarHeight: CGFloat = 40.0
        let panelY: CGFloat = insets.top - UIScreenPixel - 4.0
        
        let controlSize = self.segmentedControlNode.updateLayout(.stretchToFill(width: layout.size.width - 14.0 * 2.0), transition: transition)
        transition.updateFrame(node: self.segmentedControlNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - controlSize.width) / 2.0), y: panelY + 2.0 + floor((toolbarHeight - controlSize.height) / 2.0)), size: controlSize))
        
        if let chatController = self.chatController {
            insets.top += toolbarHeight - 4.0
            let chatSize = CGSize(width: layout.size.width, height: layout.size.height)
            transition.updateFrame(node: chatController.displayNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: chatSize))
            chatController.containerLayoutUpdated(ContainerViewLayout(size: chatSize, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(top: insets.top, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), safeInsets: layout.safeInsets, additionalInsets: layout.additionalInsets, statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
            
            if chatController.displayNode.supernode == nil {
                chatController.viewWillAppear(false)
                self.insertSubnode(chatController.displayNode, at: 0)
                chatController.viewDidAppear(false)
                
                chatController.beginMessageSearch(self.query)
            }
        }
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        let overflowInset: CGFloat = 0.0
        let topInset = navigationBarHeight
        self.shimmerNode.frame = CGRect(origin: CGPoint(x: overflowInset, y: topInset), size: CGSize(width: layout.size.width - overflowInset * 2.0, height: layout.size.height))
        self.shimmerNode.update(context: self.context, size: CGSize(width: layout.size.width - overflowInset * 2.0, height: layout.size.height), presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, animationCache: self.context.animationCache, animationRenderer: self.context.animationRenderer, key: .chats, hasSelection: false, transition: transition)
        
        insets.top += 4.0
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: curve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !self.hasValidLayout {
            self.hasValidLayout = true
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }

        if self.chatController != nil {
            return toolbarHeight
        } else {
            return 0.0
        }
    }
}
