import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AccountContext
import PhoneNumberFormat
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import ChatMessageAttachedContentButtonNode
import ChatControllerInteraction

private let avatarFont = avatarPlaceholderFont(size: 16.0)

private let titleFont = Font.medium(14.0)
private let textFont = Font.regular(14.0)

public class ChatMessageContactBubbleContentNode: ChatMessageBubbleContentNode {
    private let avatarNode: AvatarNode
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private let titleNode: TextNode
    private let textNode: TextNode
    
    private var contact: TelegramMediaContact?
    private var contactInfo : String?
    
    private let buttonNode: ChatMessageAttachedContentButtonNode
    
    required public init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        self.titleNode = TextNode()
        self.textNode = TextNode()
        self.buttonNode = ChatMessageAttachedContentButtonNode()
        
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.dateAndStatusNode.reactionSelected = { [weak self] value in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            item.controllerInteraction.updateMessageReaction(item.message, .reaction(value))
        }
        
        self.dateAndStatusNode.openReactionPreview = { [weak self] gesture, sourceView, value in
            guard let strongSelf = self, let item = strongSelf.item else {
                gesture?.cancel()
                return
            }
            
            item.controllerInteraction.openMessageReactionContextMenu(item.topMessage, sourceView, gesture, value)
        }
    }
    
    override public func accessibilityActivate() -> Bool {
        self.buttonPressed()
        return true
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.contactTap(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeButtonLayout = ChatMessageAttachedContentButtonNode.asyncLayout(self.buttonNode)
        
        let previousContact = self.contact
        let previousContactInfo = self.contactInfo
        
        return { item, layoutConstants, _, _, constrainedSize, _ in
            var selectedContact: TelegramMediaContact?
            for media in item.message.media {
                if let media = media as? TelegramMediaContact {
                    selectedContact = media;
                }
            }
            
            var incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .forward = info {
                incoming = false
            }
            
            var titleString: NSAttributedString?
            var textString: NSAttributedString?
            var updatedContactInfo: String?
            
            var displayName: String = ""
            if let selectedContact = selectedContact {
                if !selectedContact.firstName.isEmpty && !selectedContact.lastName.isEmpty {
                    displayName = "\(selectedContact.firstName) \(selectedContact.lastName)"
                } else if !selectedContact.firstName.isEmpty {
                    displayName = selectedContact.firstName
                } else {
                    displayName = selectedContact.lastName
                }
                if displayName.isEmpty {
                    displayName = item.presentationData.strings.Message_Contact
                }
                
                let info: String
                if let previousContact = previousContact, previousContact.isEqual(to: selectedContact), let contactInfo = previousContactInfo {
                    info = contactInfo
                } else {
                    if let vCard = selectedContact.vCardData, let vCardData = vCard.data(using: .utf8), let contactData = DeviceContactExtendedData(vcard: vCardData) {
                        if displayName.isEmpty && !contactData.organization.isEmpty {
                            displayName = contactData.organization
                        }
                        
                        let infoLineLimit = 5
                        var infoComponents: [String] = []
                        if !contactData.basicData.phoneNumbers.isEmpty {
                            for phone in contactData.basicData.phoneNumbers {
                                if infoComponents.count < infoLineLimit {
                                    infoComponents.append(formatPhoneNumber(context: item.context, number: phone.value))
                                }
                            }
                        } else {
                             infoComponents.append(formatPhoneNumber(context: item.context, number: selectedContact.phoneNumber))
                        }
                        if infoComponents.count < infoLineLimit {
                            for email in contactData.emailAddresses {
                                if infoComponents.count < infoLineLimit {
                                    infoComponents.append(email.value)
                                }
                            }
                        }
                        if infoComponents.count < infoLineLimit {
                            if !contactData.organization.isEmpty && displayName != contactData.organization {
                                infoComponents.append(contactData.organization)
                            }
                        }
                        info = infoComponents.joined(separator: "\n")
                    } else {
                        info = formatPhoneNumber(context: item.context, number: selectedContact.phoneNumber)
                    }
                }
                
                updatedContactInfo = info
                
                titleString = NSAttributedString(string: displayName, font: titleFont, textColor: incoming ? item.presentationData.theme.theme.chat.message.incoming.accentTextColor : item.presentationData.theme.theme.chat.message.outgoing.accentTextColor)
                textString = NSAttributedString(string: info, font: textFont, textColor: incoming ? item.presentationData.theme.theme.chat.message.incoming.primaryTextColor : item.presentationData.theme.theme.chat.message.outgoing.primaryTextColor)
            } else {
                updatedContactInfo = nil
            }
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let avatarSize = CGSize(width: 40.0, height: 40.0)
                
                let sideInsets = layoutConstants.text.bubbleInsets.right * 2.0
                
                let maxTextWidth = max(1.0, constrainedSize.width - avatarSize.width - 7.0 - sideInsets)
                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: textString, backgroundColor: nil, maximumNumberOfLines: 5, truncationType: .end, constrainedSize: CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let hideReactions = item.message.isPeerBroadcastChannel && item.context.sharedContext.currentPtgSettings.with { $0.hideReactionsInChannels }
                
                var edited = false
                if item.attributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var dateReplies = 0
                var dateReactionsAndPeers = !hideReactions ? mergedMessageReactionsAndPeers(accountPeer: item.associatedData.accountPeer, message: item.message) : (reactions: [], peers: [])
                if item.message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                    dateReactionsAndPeers = ([], [])
                }
                for attribute in item.message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                        if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    }
                }
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, associatedData: item.associatedData)
                
                let statusType: ChatMessageDateAndStatusType?
                switch position {
                    case .linear(_, .None), .linear(_, .Neighbour(true, _, _)):
                        if incoming {
                            statusType = .BubbleIncoming
                        } else {
                            if item.message.flags.contains(.Failed) {
                                statusType = .BubbleOutgoing(.Failed)
                            } else if (item.message.flags.isSending && !item.message.isSentOrAcknowledged) || item.attributes.updatingMedia != nil {
                                statusType = .BubbleOutgoing(.Sending)
                            } else {
                                statusType = .BubbleOutgoing(.Sent(read: item.read))
                            }
                        }
                    default:
                        statusType = nil
                }
                
                var statusSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))?
                if let statusType = statusType {
                    var isReplyThread = false
                    if case .replyThread = item.chatLocation {
                        isReplyThread = true
                    }
                    
                    statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: item.context,
                        presentationData: item.presentationData,
                        edited: edited,
                        impressionCount: viewCount,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: .trailingContent(contentWidth: 1000.0, reactionSettings: shouldDisplayInlineDateReactions(message: item.message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) ? ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: true, preferAdditionalInset: false) : nil),
                        constrainedSize: CGSize(width: constrainedSize.width - sideInsets, height: .greatestFiniteMagnitude),
                        availableReactions: item.associatedData.availableReactions,
                        reactions: dateReactionsAndPeers.reactions,
                        reactionPeers: dateReactionsAndPeers.peers,
                        displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                        replyCount: dateReplies,
                        isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && isReplyThread,
                        hasAutoremove: item.message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: item.message),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                }
                
                let titleColor: UIColor
                let avatarPlaceholderColor: UIColor
                if incoming {
                    titleColor = item.presentationData.theme.theme.chat.message.incoming.accentTextColor
                    avatarPlaceholderColor = item.presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor
                } else {
                    titleColor = item.presentationData.theme.theme.chat.message.outgoing.accentTextColor
                    avatarPlaceholderColor = item.presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor
                }
                
                let (buttonWidth, continueLayout) = makeButtonLayout(constrainedSize.width, nil, false, item.presentationData.strings.Conversation_ViewContactDetails, titleColor, false, true)
                
                var maxContentWidth: CGFloat = avatarSize.width + 7.0
                if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                    maxContentWidth = max(maxContentWidth, statusSuggestedWidthAndContinue.0)
                }
                maxContentWidth = max(maxContentWidth, avatarSize.width + 7.0 + titleLayout.size.width)
                maxContentWidth = max(maxContentWidth, avatarSize.width + 7.0 + textLayout.size.width)
                maxContentWidth = max(maxContentWidth, buttonWidth)
                
                let contentWidth = maxContentWidth + layoutConstants.text.bubbleInsets.right * 2.0
                
                return (contentWidth, { boundingWidth in
                    let baseAvatarFrame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.right, y: layoutConstants.text.bubbleInsets.top), size: avatarSize)
                    
                    let (buttonSize, buttonApply) = continueLayout(boundingWidth - layoutConstants.text.bubbleInsets.right * 2.0, 33.0)
                    let buttonSpacing: CGFloat = 4.0
                    
                    let statusSizeAndApply = statusSuggestedWidthAndContinue?.1(boundingWidth - sideInsets)
                    
                    var layoutSize = CGSize(width: contentWidth, height: 49.0 + textLayout.size.height + buttonSize.height + buttonSpacing)
                    if let statusSizeAndApply = statusSizeAndApply {
                        layoutSize.height += statusSizeAndApply.0.height - 4.0
                    }
                    let buttonFrame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.right, y: layoutSize.height - 9.0 - buttonSize.height), size: buttonSize)
                    let avatarFrame = baseAvatarFrame.offsetBy(dx: 0.0, dy: 5.0)
                    
                    var customLetters: [String] = []
                    if let selectedContact = selectedContact, selectedContact.peerId == nil {
                        let firstName = selectedContact.firstName
                        let lastName = selectedContact.lastName
                        if !firstName.isEmpty && !lastName.isEmpty {
                            customLetters = [String(firstName[..<firstName.index(after: firstName.startIndex)]).uppercased(), String(lastName[..<lastName.index(after: lastName.startIndex)]).uppercased()]
                        } else if !firstName.isEmpty {
                            customLetters = [String(firstName[..<firstName.index(after: firstName.startIndex)]).uppercased()]
                        } else if !lastName.isEmpty {
                            customLetters = [String(lastName[..<lastName.index(after: lastName.startIndex)]).uppercased()]
                        } else if !displayName.isEmpty {
                            customLetters = [String(displayName[..<displayName.index(after: displayName.startIndex)]).uppercased()]
                        }
                    }
                    
                    return (layoutSize, { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.contact = selectedContact
                            strongSelf.contactInfo = updatedContactInfo
                            
                            strongSelf.avatarNode.frame = avatarFrame
                            
                            let _ = titleApply()
                            let _ = textApply()
                            let _ = buttonApply(animation)
                            
                            strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX + 7.0, y: avatarFrame.minY + 1.0), size: titleLayout.size)
                            strongSelf.textNode.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX + 7.0, y: avatarFrame.minY + 20.0), size: textLayout.size)
                            strongSelf.buttonNode.frame = buttonFrame
                            
                            if let statusSizeAndApply = statusSizeAndApply {
                                strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.left, y: strongSelf.textNode.frame.maxY + 2.0), size: statusSizeAndApply.0)
                                if strongSelf.dateAndStatusNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.dateAndStatusNode)
                                    statusSizeAndApply.1(.None)
                                } else {
                                    statusSizeAndApply.1(animation)
                                }
                            } else if strongSelf.dateAndStatusNode.supernode != nil {
                                strongSelf.dateAndStatusNode.removeFromSupernode()
                            }
                            
                            if let _ = titleString {
                                if strongSelf.titleNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.titleNode)
                                }
                                if strongSelf.textNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.textNode)
                                }
                            } else {
                                if strongSelf.titleNode.supernode != nil {
                                    strongSelf.titleNode.removeFromSupernode()
                                }
                                if strongSelf.textNode.supernode != nil {
                                    strongSelf.textNode.removeFromSupernode()
                                }
                            }
                            
                            if let peerId = selectedContact?.peerId, let peer = item.message.peers[peerId] {
                                strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme.theme, peer: EnginePeer(peer), emptyColor: avatarPlaceholderColor, synchronousLoad: synchronousLoads)
                            } else {
                                strongSelf.avatarNode.setCustomLetters(customLetters)
                            }
                            
                            if let forwardInfo = item.message.forwardInfo, forwardInfo.flags.contains(.isImported) {
                                strongSelf.dateAndStatusNode.pressed = {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    item.controllerInteraction.displayImportedMessageTooltip(strongSelf.dateAndStatusNode)
                                }
                            } else {
                                strongSelf.dateAndStatusNode.pressed = nil
                            }
                        }
                    })
                })
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.buttonNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .openMessage)
        }
        if self.dateAndStatusNode.supernode != nil, let _ = self.dateAndStatusNode.hitTest(self.view.convert(point, to: self.dateAndStatusNode.view), with: nil) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
    
    @objc private func contactTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item {
                let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
            }
        }
    }
    
    @objc private func buttonPressed() {
        if let item = self.item {
            let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
        }
    }
    
    override public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if !self.dateAndStatusNode.isHidden {
            return self.dateAndStatusNode.reactionView(value: value)
        }
        return nil
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.dateAndStatusNode.supernode != nil, let result = self.dateAndStatusNode.hitTest(self.view.convert(point, to: self.dateAndStatusNode.view), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
}
