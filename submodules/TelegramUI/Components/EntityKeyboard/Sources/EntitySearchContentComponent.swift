import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox
import AnimationCache
import MultiAnimationRenderer
import AccountContext
import AsyncDisplayKit
import ComponentDisplayAdapters

public protocol EntitySearchContainerNode: ASDisplayNode {
    var onCancel: (() -> Void)? { get set }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition)
}

public final class EntitySearchContainerController: ViewController {
    private var node: Node {
        return self.displayNode as! Node
    }
    
    private let containerNode: EntitySearchContainerNode
    
    public init(containerNode: EntitySearchContainerNode) {
        self.containerNode = containerNode
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .modal
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(containerNode: self.containerNode, controller: self)
        self.displayNodeDidLoad()
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.node.containerLayoutUpdated(layout, transition: transition)
    }
    
    private class Node: ViewControllerTracingNode, UIScrollViewDelegate {
        private weak var controller: EntitySearchContainerController?
        
        private let containerNode: EntitySearchContainerNode
        
        init(containerNode: EntitySearchContainerNode, controller: EntitySearchContainerController) {
            self.containerNode = containerNode
            self.controller = controller
            
            super.init()
            
            self.addSubnode(containerNode)
            
            containerNode.onCancel = { [weak self] in
                self?.controller?.dismiss()
            }
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.containerNode.updateLayout(size: layout.size, leftInset: 0.0, rightInset: 0.0, bottomInset: layout.intrinsicInsets.bottom, inputHeight: layout.inputHeight ?? 0.0, deviceMetrics: layout.deviceMetrics, transition: transition)
            transition.updateFrame(node: self.containerNode, frame: CGRect(origin: .zero, size: layout.size))
        }
    }
}

final class EntitySearchContentEnvironment: Equatable {
    let context: AccountContext
    let theme: PresentationTheme
    let deviceMetrics: DeviceMetrics
    let inputHeight: CGFloat
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        deviceMetrics: DeviceMetrics,
        inputHeight: CGFloat
    ) {
        self.context = context
        self.theme = theme
        self.deviceMetrics = deviceMetrics
        self.inputHeight = inputHeight
    }
    
    static func ==(lhs: EntitySearchContentEnvironment, rhs: EntitySearchContentEnvironment) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        if lhs.inputHeight != rhs.inputHeight {
            return false
        }
        return true
    }
}

final class EntitySearchContentComponent: Component {
    typealias EnvironmentType = EntitySearchContentEnvironment
    
    let makeContainerNode: () -> EntitySearchContainerNode?
    let dismissSearch: () -> Void
    
    init(
        makeContainerNode: @escaping () -> EntitySearchContainerNode?,
        dismissSearch: @escaping () -> Void
    ) {
        self.makeContainerNode = makeContainerNode
        self.dismissSearch = dismissSearch
    }
    
    static func ==(lhs: EntitySearchContentComponent, rhs: EntitySearchContentComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private var containerNode: EntitySearchContainerNode?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: EntitySearchContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let containerNode: EntitySearchContainerNode?
            if let current = self.containerNode {
                containerNode = current
            } else {
                containerNode = component.makeContainerNode()
                if let containerNode = containerNode {
                    self.containerNode = containerNode
                    self.addSubnode(containerNode)
                }
            }
            
            if let containerNode = containerNode {
                let environmentValue = environment[EntitySearchContentEnvironment.self].value
                transition.setFrame(view: containerNode.view, frame: CGRect(origin: CGPoint(), size: availableSize))
                containerNode.updateLayout(
                    size: availableSize,
                    leftInset: 0.0,
                    rightInset: 0.0,
                    bottomInset: 0.0,
                    inputHeight: environmentValue.inputHeight,
                    deviceMetrics: environmentValue.deviceMetrics,
                    transition: transition.containedViewLayoutTransition
                )
                containerNode.onCancel = {
                    component.dismissSearch()
                }
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
