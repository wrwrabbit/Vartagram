import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import Markdown
import BalancedTextComponent
import TextFormat
import TelegramStringFormatting
import PlainButtonComponent
import TooltipUI
import GiftAnimationComponent
import ContextUI
import GiftItemComponent
import GlassBarButtonComponent
import ButtonComponent
import UndoUI
import LottieComponent
import AnimatedTextComponent

private final class GiftAuctionViewSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let auctionContext: GiftAuctionContext
    let animateOut: ActionSlot<Action<()>>
    let getController: () -> ViewController?
    
    init(
        context: AccountContext,
        auctionContext: GiftAuctionContext,
        animateOut: ActionSlot<Action<()>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.auctionContext = auctionContext
        self.animateOut = animateOut
        self.getController = getController
    }
    
    static func ==(lhs: GiftAuctionViewSheetContent, rhs: GiftAuctionViewSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        let averagePriceTag = GenericComponentViewTag()
        
        private let context: AccountContext
        private let auctionContext: GiftAuctionContext
        private let animateOut: ActionSlot<Action<()>>
        private let getController: () -> ViewController?
        
        private var disposable: Disposable?
        private(set) var auctionState: GiftAuctionContext.State?
        
        private var giftAuctionTimer: SwiftSignalKit.Timer?
        fileprivate var giftAuctionAcquiredGifts: [GiftAuctionAcquiredGift] = []
        private var giftAuctionAcquiredGiftsDisposable: Disposable?
                
        var cachedStarImage: (UIImage, PresentationTheme)?
        
        var cachedChevronImage: (UIImage, PresentationTheme)?
        var cachedSmallChevronImage: (UIImage, PresentationTheme)?
                                        
        init(
            context: AccountContext,
            auctionContext: GiftAuctionContext,
            animateOut: ActionSlot<Action<()>>,
            getController: @escaping () -> ViewController?
        ) {
            self.context = context
            self.auctionContext = auctionContext
            self.animateOut = animateOut
            self.getController = getController
            
            super.init()
            
            self.disposable = (auctionContext.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self else {
                    return
                }
                self.auctionState = state
                self.updated()
            })
            
            self.giftAuctionAcquiredGiftsDisposable = (context.engine.payments.getGiftAuctionAcquiredGifts(giftId: auctionContext.gift.giftId)
            |> deliverOnMainQueue).startStrict(next: { [weak self] acquiredGifts in
                guard let self else {
                    return
                }
                self.giftAuctionAcquiredGifts = acquiredGifts
                self.updated(transition: .easeInOut(duration: 0.25))
            })
            
            self.giftAuctionTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                self?.updated()
            }, queue: Queue.mainQueue())
            self.giftAuctionTimer?.start()
        }
        
        deinit {
            self.disposable?.dispose()
            self.giftAuctionAcquiredGiftsDisposable?.dispose()
            self.giftAuctionTimer?.invalidate()
        }
        
        func showAttributeInfo(tag: Any, text: String) {
            guard let controller = self.getController() as? GiftAuctionViewScreen else {
                return
            }
            controller.dismissAllTooltips()
            
            guard let sourceView = controller.node.hostView.findTaggedView(tag: tag), let absoluteLocation = sourceView.superview?.convert(sourceView.center, to: controller.view) else {
                return
            }
            
            let location = CGRect(origin: CGPoint(x: absoluteLocation.x, y: absoluteLocation.y - 12.0), size: CGSize())
            let tooltipController = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .markdown(text: text), style: .wide, location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                return .dismiss(consume: false)
            })
            controller.present(tooltipController, in: .current)
        }
        
        func openGiftResale(gift: StarGift.Gift) {
            guard let controller = self.getController() as? GiftAuctionViewScreen else {
                return
            }
            let storeController = self.context.sharedContext.makeGiftStoreController(
                context: self.context,
                peerId: self.context.account.peerId,
                gift: gift
            )
            controller.push(storeController)
        }
        
        func openGiftFragmentResale(url: String) {
            guard let controller = self.getController() as? GiftAuctionViewScreen, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
        }
        
        func proceed() {
            guard let controller = self.getController() as? GiftAuctionViewScreen else {
                return
            }
            self.dismiss(animated: true)
            
            controller.completion()
            
//            let bidController = self.context.sharedContext.makeGiftAuctionBidScreen(context: self.context, toPeerId: self.auctionContext.currentBidPeerId ?? self.toPeerId, auctionContext: self.auctionContext)
//            navigationController.pushViewController(bidController)
        }
        
        func openPeer(_ peer: EnginePeer, dismiss: Bool = true) {
            guard let controller = self.getController() as? GiftAuctionViewScreen, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
                        
            controller.dismissAllTooltips()
            
            let context = self.context
            let action = {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                    navigationController: navigationController,
                    chatController: nil,
                    context: context,
                    chatLocation: .peer(peer),
                    subject: nil,
                    botStart: nil,
                    updateTextInputState: nil,
                    keepStack: .always,
                    useExisting: true,
                    purposefulAction: nil,
                    scrollToEndIfExists: false,
                    activateMessageSearch: nil,
                    animated: true
                ))
            }
            
            if dismiss {
                self.dismiss(animated: true)
                Queue.mainQueue().after(0.4, {
                    action()
                })
            } else {
                action()
            }
        }
        
        func share() {
            guard let controller = self.getController() as? GiftAuctionViewScreen else {
                return
            }
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            var link = ""
            if case let .generic(gift) = self.auctionContext.gift, let slug = gift.auctionSlug {
                link = "https://t.me/auction/\(slug)"
            }
            
            let shareController = self.context.sharedContext.makeShareController(
                context: self.context,
                subject: .url(link),
                forceExternal: false,
                shareStory: nil,
                enqueued: { [weak self, weak controller] peerIds, _ in
                    guard let self else {
                        return
                    }
                    let _ = (self.context.engine.data.get(
                        EngineDataList(
                            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                        )
                    )
                    |> deliverOnMainQueue).startStandalone(next: { [weak self, weak controller] peerList in
                        guard let self else {
                            return
                        }
                        let peers = peerList.compactMap { $0 }
                        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                        let text: String
                        var savedMessages = false
                        if peerIds.count == 1, let peerId = peerIds.first, peerId == context.account.peerId {
                            text = presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One
                            savedMessages = true
                        } else {
                            if peers.count == 1, let peer = peers.first {
                                var peerName = peer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                peerName = peerName.replacingOccurrences(of: "**", with: "")
                                text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string
                            } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                var firstPeerName = firstPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                firstPeerName = firstPeerName.replacingOccurrences(of: "**", with: "")
                                var secondPeerName = secondPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                secondPeerName = secondPeerName.replacingOccurrences(of: "**", with: "")
                                text = presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                            } else if let peer = peers.first {
                                var peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                peerName = peerName.replacingOccurrences(of: "**", with: "")
                                text = presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                            } else {
                                text = ""
                            }
                        }
                        
                        controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: false, action: { [weak self, weak controller] action in
                            if let self, savedMessages, action == .info {
                                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                                |> deliverOnMainQueue).start(next: { [weak self, weak controller] peer in
                                    guard let peer else {
                                        return
                                    }
                                    self?.openPeer(peer)
                                    Queue.mainQueue().after(0.6) {
                                        controller?.dismiss(animated: false, completion: nil)
                                    }
                                })
                            }
                            return false
                        }, additionalView: nil), in: .current)
                    })
                },
                actionCompleted: { [weak controller] in
                    controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }
            )
            controller.present(shareController, in: .window(.root))
        }
        
        func morePressed(view: UIView, gesture: ContextGesture?) {
            guard let controller = self.getController() as? GiftAuctionViewScreen else {
                return
            }
            
            let context = self.context
            let gift = self.auctionContext.gift
            let auctionContext = self.auctionContext
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            var link = ""
            if case let .generic(gift) = gift, let slug = gift.auctionSlug {
                link = "https://t.me/auction/\(slug)"
            }
            
            var items: [ContextMenuItem] = []
          
            if let auctionState = self.auctionState, case .ongoing = auctionState.auctionState {   
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_Auction_Context_About, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.contextMenu.primaryColor) }, action: { [weak controller] c, f in
                    f(.default)
                    
                    let infoController = context.sharedContext.makeGiftAuctionInfoScreen(context: context, auctionContext: auctionContext, completion: nil)
                    controller?.push(infoController)
                })))
            }
                         
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_Auction_Context_CopyLink, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor) }, action: { [weak controller] c, f in
                f(.default)
                
                UIPasteboard.general.string = link
                
                controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            })))
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_Auction_Context_Share, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                f(.default)
                
                self?.share()
            })))

            let contextController = ContextController(presentationData: presentationData, source: .reference(GiftViewContextReferenceContentSource(controller: controller, sourceView: view)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            controller.presentInGlobalOverlay(contextController)
        }
        
        func dismiss(animated: Bool) {
            guard let controller = self.getController() as? GiftAuctionViewScreen else {
                return
            }
            if animated {
                controller.dismissAllTooltips()
                self.animateOut.invoke(Action { [weak controller] _ in
                    controller?.dismiss(completion: nil)
                })
            } else {
                controller.dismiss(animated: false)
            }
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, auctionContext: self.auctionContext, animateOut: self.animateOut, getController: self.getController)
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let moreButton = Child(GlassBarButtonComponent.self)
        let animation = Child(GiftItemComponent.self)
        
        let title = Child(MultilineTextComponent.self)
        let description = Child(BalancedTextComponent.self)

        let table = Child(TableComponent.self)

        let button = Child(ButtonComponent.self)
        
        let acquiredButton = Child(PlainButtonComponent.self)
//        let telegramSaleButton = Child(PlainButtonComponent.self)
//        let fragmentSaleButton = Child(PlainButtonComponent.self)
        
        let moreButtonPlayOnce = ActionSlot<Void>()
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let dateTimeFormat = environment.dateTimeFormat
            
            let state = context.state
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            var titleString: String = ""
            var giftIconSubject: GiftItemComponent.Subject?
            var genericGift: StarGift.Gift?
            
            switch component.auctionContext.gift {
            case let .generic(gift):
                titleString = gift.title ?? ""
                giftIconSubject = .starGift(gift: gift, price: "")
                genericGift = gift
            default:
                break
            }
            
            let _ = giftIconSubject
            let _ = genericGift
                 
            var originY: CGFloat = 0.0
                                    
            if let genericGift {
                let animation = animation.update(
                    component: GiftItemComponent(
                        context: component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        subject: .starGift(gift: genericGift, price: ""),
                        ribbon: GiftItemComponent.Ribbon(text: strings.Gift_Auction_Auction, color: .orange),
                        outline: .orange,
                        mode: .header
                    ),
                    availableSize: CGSize(width: 120.0, height: 120.0),
                    transition: context.transition
                )
                context.add(animation
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: 92.0))
                )
            }
            originY += 177.0
                       
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleString,
                        font: Font.bold(24.0),
                        textColor: theme.list.itemPrimaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 174.0))
            )
                       
            var descriptionText: String = ""
            var descriptionColor = theme.list.itemSecondaryTextColor
          
            let tableFont = Font.regular(15.0)
            let tableTextColor = theme.list.itemPrimaryTextColor
    
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            var endTime = currentTime
            
            var isEnded = false
            var tableItems: [TableComponent.Item] = []
            if let auctionState = state.auctionState, case let .generic(gift) = component.auctionContext.gift {
                endTime = auctionState.endDate
                if case .finished = auctionState.auctionState {
                    isEnded = true
                } else if auctionState.endDate < currentTime {
                    isEnded = true
                }
                
                if isEnded {
                    descriptionText = strings.Gift_Auction_Ended
                    descriptionColor = theme.list.itemDestructiveColor
                    
                    tableItems.append(.init(
                        id: "firstSale",
                        title: strings.Gift_Auction_FirstSale,
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: auctionState.startDate, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                        )
                    ))
                    tableItems.append(.init(
                        id: "lastSale",
                        title: strings.Gift_Auction_LastSale,
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: auctionState.endDate, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                        )
                    ))
                    if case let .finished(_, _, averagePrice) = auctionState.auctionState {
                        var items: [AnyComponentWithIdentity<Empty>] = []
                        
                        let valueString = "\(presentationStringsFormattedNumber(abs(Int32(clamping: averagePrice)), dateTimeFormat.groupingSeparator))⭐️"
                        let valueAttributedString = NSMutableAttributedString(string: valueString, font: tableFont, textColor: tableTextColor)
                        let range = (valueAttributedString.string as NSString).range(of: "⭐️")
                        if range.location != NSNotFound {
                            valueAttributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                            valueAttributedString.addAttribute(.baselineOffset, value: 1.0, range: range)
                        }
                        
                        let averagePriceString = strings.Gift_Auction_Stars(Int32(clamping: averagePrice))
                        items.append(AnyComponentWithIdentity(id: "value", component: AnyComponent(
                            MultilineTextWithEntitiesComponent(
                                context: component.context,
                                animationCache: component.context.animationCache,
                                animationRenderer: component.context.animationRenderer,
                                placeholderColor: theme.list.mediaPlaceholderColor,
                                text: .plain(valueAttributedString),
                                maximumNumberOfLines: 0
                            )
                        )))
                        items.append(AnyComponentWithIdentity(
                            id: AnyHashable(1),
                            component: AnyComponent(Button(
                                content: AnyComponent(ButtonContentComponent(
                                    context: component.context,
                                    text: "?",
                                    color: theme.list.itemAccentColor
                                )),
                                action: { [weak state] in
                                    guard let state else {
                                        return
                                    }
                                    state.showAttributeInfo(tag: state.averagePriceTag, text: strings.Gift_Auction_AveragePriceInfo(averagePriceString, titleString).string)
                                }
                            ).tagged(state.averagePriceTag))
                        ))
                        
                        tableItems.append(.init(
                            id: "averagePrice",
                            title: strings.Gift_Auction_AveragePrice,
                            component: AnyComponent(HStack(items, spacing: 4.0)),
                            insets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 12.0)
                        ))
                    }
                    tableItems.append(.init(
                        id: "availability",
                        title: strings.Gift_Auction_Availability,
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Auction_AvailabilityOf("0", presentationStringsFormattedNumber(gift.availability?.total ?? 0, dateTimeFormat.groupingSeparator)).string, font: tableFont, textColor: tableTextColor)))
                        )
                    ))
                } else {
                    var auctionGiftsPerRound: Int32 = 50
                    if let auctionGiftsPerRoundValue = gift.auctionGiftsPerRound {
                        auctionGiftsPerRound = auctionGiftsPerRoundValue
                    }
                    descriptionText = strings.Gift_Auction_Description("\(auctionGiftsPerRound)", gift.title ?? "").string
                    
                    tableItems.append(.init(
                        id: "start",
                        title: strings.Gift_Auction_Started,
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: auctionState.startDate, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                        )
                    ))
                    tableItems.append(.init(
                        id: "ends",
                        title: strings.Gift_Auction_Ends,
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: auctionState.endDate, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                        )
                    ))
                    if case let .ongoing(_, _, _, _, _, _, _, giftsLeft, currentRound, totalRounds) = auctionState.auctionState {
                        tableItems.append(.init(
                            id: "round",
                            title: strings.Gift_Auction_CurrentRound,
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Auction_Round("\(currentRound)", "\(totalRounds)").string, font: tableFont, textColor: tableTextColor)))
                            )
                        ))
                        tableItems.append(.init(
                            id: "availability",
                            title: strings.Gift_Auction_Availability,
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Auction_AvailabilityOf(presentationStringsFormattedNumber(giftsLeft, dateTimeFormat.groupingSeparator), presentationStringsFormattedNumber(gift.availability?.total ?? 0, dateTimeFormat.groupingSeparator)).string, font: tableFont, textColor: tableTextColor)))
                            )
                        ))
                    }
                }
            }
                        
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = descriptionColor
            let linkColor = theme.list.itemAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: linkColor)!, theme)
            }
            if state.cachedSmallChevronImage == nil || state.cachedSmallChevronImage?.1 !== environment.theme {
                state.cachedSmallChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: linkColor)!, theme)
            }
            descriptionText = descriptionText.replacingOccurrences(of: " >]", with: "\u{00A0}>]")
            
            let attributedString = parseMarkdownIntoAttributedString(descriptionText, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
            if let range = attributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                attributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: attributedString.string))
            }
            
            let description = description.update(
                component: BalancedTextComponent(
                    text: .plain(attributedString),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: linkColor.withAlphaComponent(0.1),
                    highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { attributes, _ in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                            let controller = component.context.sharedContext.makeGiftAuctionInfoScreen(
                                context: component.context,
                                auctionContext: component.auctionContext,
                                completion: nil
                            )
                            environment.controller()?.push(controller)
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 50.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(description
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 198.0 + description.size.height / 2.0))
                .appear(.default(alpha: true))
                .disappear(.default(alpha: true))
            )
            originY += description.size.height
            originY += 42.0
            
            let table = table.update(
                component: TableComponent(
                    theme: environment.theme,
                    items: tableItems
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(table
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + table.size.height / 2.0))
                .appear(.default(alpha: true))
                .disappear(.default(alpha: true))
            )
            originY += table.size.height + 26.0
            
            var hasAdditionalButtons = false
            if state.giftAuctionAcquiredGifts.count > 0, case let .generic(gift) = component.auctionContext.gift {
                originY += 5.0
                
                let acquiredButton = acquiredButton.update(
                    component: PlainButtonComponent(content: AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(id: "count", component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: presentationStringsFormattedNumber(Int32(state.giftAuctionAcquiredGifts.count), dateTimeFormat.groupingSeparator), font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor)))
                            )),
                            AnyComponentWithIdentity(id: "spacing", component: AnyComponent(
                                Rectangle(color: .clear, width: 8.0, height: 1.0)
                            )),
                            AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                GiftItemComponent(
                                    context: component.context,
                                    theme: theme,
                                    strings: strings,
                                    peer: nil,
                                    subject: .starGift(gift: gift, price: ""),
                                    mode: .buttonIcon
                                )
                            )),
                            AnyComponentWithIdentity(id: "text", component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: "  \(strings.Gift_Auction_ItemsBought(Int32(state.giftAuctionAcquiredGifts.count)))", font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor)))
                            )),
                            AnyComponentWithIdentity(id: "arrow", component: AnyComponent(
                                BundleIconComponent(name: "Chat/Context Menu/Arrow", tintColor: theme.actionSheet.controlAccentColor)
                            ))
                        ], spacing: 0.0)
                    ), action: { [weak state] in
                        guard let state else {
                            return
                        }
                        let giftController = GiftAuctionAcquiredScreen(context: component.context, gift: component.auctionContext.gift, acquiredGifts: state.giftAuctionAcquiredGifts)
                        environment.controller()?.push(giftController)
                    }, animateScale: false),
                    availableSize: CGSize(width: context.availableSize.width - 64.0, height: context.availableSize.height),
                    transition: context.transition
                )
                context.add(acquiredButton
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + acquiredButton.size.height / 2.0)))
                originY += acquiredButton.size.height
                originY += 12.0
                
                hasAdditionalButtons = true
            }
            
            if hasAdditionalButtons {
                originY += 21.0
            }
            
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let buttonSize = CGSize(width: context.availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0)
            let buttonBackground = ButtonComponent.Background(
                style: .glass,
                color: theme.list.itemCheckColors.fillColor,
                foreground: theme.list.itemCheckColors.foregroundColor,
                pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
            )
            
            let buttonChild: _UpdatedChildComponent
            if !isEnded {
                let buttonAttributedString = NSMutableAttributedString(string: strings.Gift_Auction_Join, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
                
                let endTimeout = max(0, endTime - currentTime)
                
                let hours = Int(endTimeout / 3600)
                let minutes = Int((endTimeout % 3600) / 60)
                let seconds = Int(endTimeout % 60)
                
                let rawString = hours > 0 ? strings.Gift_Auction_TimeLeftHours : strings.Gift_Auction_TimeLeftMinutes
                var buttonAnimatedTitleItems: [AnimatedTextComponent.Item] = []
                var startIndex = rawString.startIndex
                while true {
                    if let range = rawString.range(of: "{", range: startIndex ..< rawString.endIndex) {
                        if range.lowerBound != startIndex {
                            buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "prefix", content: .text(String(rawString[startIndex ..< range.lowerBound]))))
                        }
                        
                        startIndex = range.upperBound
                        if let endRange = rawString.range(of: "}", range: startIndex ..< rawString.endIndex) {
                            let controlString = rawString[range.upperBound ..< endRange.lowerBound]
                            if controlString == "h" {
                                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "h", content: .number(hours, minDigits: 2)))
                            } else if controlString == "m" {
                                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "m", content: .number(minutes, minDigits: 2)))
                            } else if controlString == "s" {
                                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "s", content: .number(seconds, minDigits: 2)))
                            }
                            
                            startIndex = endRange.upperBound
                        }
                    } else {
                        break
                    }
                }
                if startIndex != rawString.endIndex {
                    buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: "suffix", content: .text(String(rawString[startIndex ..< rawString.endIndex]))))
                }

                let items: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))),
                    AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(AnimatedTextComponent(
                        font: Font.with(size: 12.0, weight: .medium, traits: .monospacedNumbers),
                        color: theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7),
                        items: buttonAnimatedTitleItems,
                        noDelay: true
                    )))
                ]
                
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground,
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("buy"),
                            component: AnyComponent(VStack(items, spacing: 1.0))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak state] in
                            guard let state else {
                                return
                            }
                            state.proceed()
                        }),
                    availableSize: buttonSize,
                    transition: .spring(duration: 0.2)
                )
            } else {
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground,
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("ok"),
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Common_OK, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak state] in
                            guard let state else {
                                return
                            }
                            state.dismiss(animated: true)
                        }),
                    availableSize: buttonSize,
                    transition: context.transition
                )
            }
            
            context.add(buttonChild
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + buttonChild.size.height / 2.0))
            )
            originY += buttonChild.size.height
            originY += buttonInsets.bottom
            
            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 40.0, height: 40.0),
                    backgroundColor: theme.rootController.navigationBar.glassBarButtonBackgroundColor,
                    isDark: theme.overallDarkAppearance,
                    state: .generic,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.rootController.navigationBar.glassBarButtonForegroundColor
                        )
                    )),
                    action: { [weak state] _ in
                        guard let state else {
                            return
                        }
                        state.dismiss(animated: true)
                    }
                ),
                availableSize: CGSize(width: 40.0, height: 40.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )
            
            let moreButton = moreButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 40.0, height: 40.0),
                    backgroundColor: theme.rootController.navigationBar.glassBarButtonBackgroundColor,
                    isDark: theme.overallDarkAppearance,
                    state: .generic,
                    component: AnyComponentWithIdentity(id: "more", component: AnyComponent(
                        LottieComponent(
                            content: LottieComponent.AppBundleContent(
                                name: "anim_morewide"
                            ),
                            color: theme.rootController.navigationBar.glassBarButtonForegroundColor,
                            size: CGSize(width: 34.0, height: 34.0),
                            playOnce: moreButtonPlayOnce
                        )
                    )),
                    action: { [weak state] view in
                        guard let state else {
                            return
                        }
                        state.morePressed(view: view, gesture: nil)
                        moreButtonPlayOnce.invoke(Void())
                    }
                ),
                availableSize: CGSize(width: 40.0, height: 40.0),
                transition: .immediate
            )
            context.add(moreButton
                .position(CGPoint(x: context.availableSize.width - 16.0 - moreButton.size.width / 2.0, y: 16.0 + moreButton.size.height / 2.0))
            )
            
            return CGSize(width: context.availableSize.width, height: originY)
        }
    }
}

final class GiftAuctionViewSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let auctionContext: GiftAuctionContext
    
    init(
        context: AccountContext,
        auctionContext: GiftAuctionContext
    ) {
        self.context = context
        self.auctionContext = auctionContext
    }
    
    static func ==(lhs: GiftAuctionViewSheetComponent, rhs: GiftAuctionViewSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(GiftAuctionViewSheetContent(
                        context: context.component.context,
                        auctionContext: context.component.auctionContext,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                        if let controller = controller() as? GiftAuctionViewScreen {
                            controller.dismissAllTooltips()
                        }
                    },
                    willDismiss: {
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                if let controller = controller() as? GiftAuctionViewScreen {
                                    controller.dismissAllTooltips()
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? GiftAuctionViewScreen {
                                    controller.dismissAllTooltips()
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }
                
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}

public final class GiftAuctionViewScreen: ViewControllerComponentContainer {
    fileprivate let completion: () -> Void
    
    public init(
        context: AccountContext,
        auctionContext: GiftAuctionContext,
        completion: @escaping () -> Void
    ) {
        self.completion = completion
        
        super.init(
            context: context,
            component: GiftAuctionViewSheetComponent(
                context: context,
                auctionContext: auctionContext
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }
        
    public func dismissAnimated() {
        self.dismissAllTooltips()

        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
            
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            return true
        })
    }
}

private final class GiftViewContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    
    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
