import Foundation
import UIKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import TelegramCore
import AccountContext
import TelegramPresentationData
import PeerListItemComponent

final class ContextResultPanelComponent: Component {
    enum Results: Equatable {
        case mentions([EnginePeer])
        case hashtags([String])
       
        var count: Int {
            switch self {
            case let .hashtags(hashtags):
                return hashtags.count
            case let .mentions(peers):
                return peers.count
            }
        }
    }
    
    enum ResultAction {
        case mention(EnginePeer)
        case hashtag(String)
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let results: Results
    let action: (ResultAction) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        results: Results,
        action: @escaping (ResultAction) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.results = results
        self.action = action
    }
    
    static func ==(lhs: ContextResultPanelComponent, rhs: ContextResultPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.results != rhs.results {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var bottomInset: CGFloat
        var topInset: CGFloat
        var sideInset: CGFloat
        var itemSize: CGSize
        var itemCount: Int
        
        var contentSize: CGSize
        
        init(containerSize: CGSize, bottomInset: CGFloat, topInset: CGFloat, sideInset: CGFloat, itemSize: CGSize, itemCount: Int) {
            self.containerSize = containerSize
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.sideInset = sideInset
            self.itemSize = itemSize
            self.itemCount = itemCount
            
            self.contentSize = CGSize(width: containerSize.width, height: topInset + CGFloat(itemCount) * itemSize.height + bottomInset)
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let offsetRect = rect.offsetBy(dx: 0.0, dy: -self.topInset)
            var minVisibleRow = Int(floor((offsetRect.minY) / (self.itemSize.height)))
            minVisibleRow = max(0, minVisibleRow)
            let maxVisibleRow = Int(ceil((offsetRect.maxY) / (self.itemSize.height)))
            
            let minVisibleIndex = minVisibleRow
            let maxVisibleIndex = maxVisibleRow
            
            if maxVisibleIndex >= minVisibleIndex {
                return minVisibleIndex ..< (maxVisibleIndex + 1)
            } else {
                return nil
            }
        }
        
        func itemFrame(for index: Int) -> CGRect {
            return CGRect(origin: CGPoint(x: 0.0, y: self.topInset + CGFloat(index) * self.itemSize.height), size: CGSize(width: self.containerSize.width, height: self.itemSize.height))
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result === self {
                return nil
            }
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class View: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private let backgroundView: BlurredBackgroundView
        private let scrollView: UIScrollView
        
        private var itemLayout: ItemLayout?
        
        private let measureItem = ComponentView<Empty>()
        
        private var visibleItems: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var ignoreScrolling = false
        
        private var component: ContextResultPanelComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            
            self.scrollView = ScrollView()
            self.scrollView.canCancelContentTouches = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.indicatorStyle = .white
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.scrollView.delegate = self
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func animateIn(transition: Transition) {
            let offset = self.scrollView.contentOffset.y * -1.0 + 10.0
            Transition.immediate.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: -offset))
            transition.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: 0.0))
        }
        
        func animateOut(transition: Transition, completion: @escaping () -> Void) {
            let offset = self.scrollView.contentOffset.y * -1.0 + 10.0
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            transition.setBoundsOrigin(view: self, origin: CGPoint(x: 0.0, y: -offset), completion: { _ in
                completion()
            })
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        private func updateScrolling(transition: Transition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -200.0)
            
//            var synchronousLoad = false
//            if let hint = transition.userData(PeerListItemComponent.TransitionHint.self) {
//                synchronousLoad = hint.synchronousLoad
//            }
            
            var validIds: [AnyHashable] = []
            if let range = itemLayout.visibleItems(for: visibleBounds), case let .mentions(peers) = component.results {
                for index in range.lowerBound ..< range.upperBound {
                    guard index < peers.count else {
                        continue
                    }
                    
                    let itemFrame = itemLayout.itemFrame(for: index)
                                        
                    var itemTransition = transition
                    let peer = peers[index]
                    validIds.append(peer.id)
                    
                    let visibleItem: ComponentView<Empty>
                    if let current = self.visibleItems[peer.id] {
                        visibleItem = current
                    } else {
                        if !transition.animation.isImmediate {
                            itemTransition = .immediate
                        }
                        visibleItem = ComponentView()
                        self.visibleItems[peer.id] = visibleItem
                    }
                                       
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(PeerListItemComponent(
                            context: component.context,
                            theme: component.theme,
                            strings: component.strings,
                            style: .compact,
                            sideInset: itemLayout.sideInset,
                            title: peer.displayTitle(strings: component.strings, displayOrder: .firstLast),
                            peer: peer,
                            subtitle: peer.addressName.flatMap { "@\($0)" },
                            subtitleAccessory: .none,
                            presence: nil,
                            selectionState: .none,
                            hasNext: index != peers.count - 1,
                            action: { [weak self] peer in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.action(.mention(peer))
                            }
                        )),
                        environment: {},
                        containerSize: itemFrame.size
                    )
                    if let itemView = visibleItem.view {
//                        var animateIn = false
                        if itemView.superview == nil {
//                            animateIn = true
                            self.scrollView.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                        
//                        if animateIn {
//                            itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
//                        }
                    }
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, visibleItem) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemView = visibleItem.view {
                        itemView.removeFromSuperview()
                    }
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
            
            let backgroundSize = CGSize(width: self.scrollView.frame.width, height: self.scrollView.frame.height + 20.0)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(x: 0.0, y: max(0.0, self.scrollView.contentOffset.y * -1.0)), size: backgroundSize))
            self.backgroundView.update(size: backgroundSize, cornerRadius: 11.0, transition: transition.containedViewLayoutTransition)
        }
        
        func update(component: ContextResultPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            var transition = transition
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            let minimizedHeight = min(availableSize.height, 500.0)
                        
            let sideInset: CGFloat = 3.0
            self.backgroundView.updateColor(color: UIColor(white: 0.0, alpha: 0.7), transition: transition.containedViewLayoutTransition)
            
            let measureItemSize = self.measureItem.update(
                transition: .immediate,
                component: AnyComponent(PeerListItemComponent(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    style: .compact,
                    sideInset: sideInset,
                    title: "AAAAAAAAAAAA",
                    peer: nil,
                    subtitle: "BBBBBBB",
                    subtitleAccessory: .none,
                    presence: nil,
                    selectionState: .none,
                    hasNext: true,
                    action: { _ in
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            
            if previousComponent?.results != component.results {
                transition = transition.withUserData(PeerListItemComponent.TransitionHint(synchronousLoad: true))
            }
            
            let itemLayout = ItemLayout(
                containerSize: CGSize(width: availableSize.width, height: minimizedHeight),
                bottomInset: 0.0,
                topInset: 0.0,
                sideInset: sideInset,
                itemSize: measureItemSize,
                itemCount: component.results.count
            )
            self.itemLayout = itemLayout
            
            let scrollContentSize = itemLayout.contentSize
            
            self.ignoreScrolling = true
            
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: minimizedHeight)))

            let visibleTopContentHeight = min(scrollContentSize.height, measureItemSize.height * 3.5)
            let topInset = availableSize.height - visibleTopContentHeight
            
            let scrollContentInsets = UIEdgeInsets(top: topInset, left: 0.0, bottom: 0.0, right: 0.0)
            let scrollIndicatorInsets = UIEdgeInsets(top: topInset + 17.0, left: 0.0, bottom: 19.0, right: 0.0)
            if self.scrollView.contentInset != scrollContentInsets {
                self.scrollView.contentInset = scrollContentInsets
            }
            if self.scrollView.scrollIndicatorInsets != scrollIndicatorInsets {
                self.scrollView.scrollIndicatorInsets = scrollIndicatorInsets
            }
            if self.scrollView.contentSize != scrollContentSize {
                self.scrollView.contentSize = scrollContentSize
            }
            
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
