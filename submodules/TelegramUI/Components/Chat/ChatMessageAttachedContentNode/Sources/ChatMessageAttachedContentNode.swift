import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import AccountContext
import UrlEscaping
import PhotoResources
import WebsiteType
import ChatMessageInteractiveMediaBadge
import GalleryData
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import ChatControllerInteraction
import ShimmerEffect
import ChatMessageDateAndStatusNode
import ChatHistoryEntry
import ChatMessageItemCommon
import ChatMessageBubbleContentNode
import ChatMessageInteractiveInstantVideoNode
import ChatMessageInteractiveFileNode
import ChatMessageInteractiveMediaNode
import WallpaperPreviewMedia
import ChatMessageAttachedContentButtonNode
import MessageInlineBlockBackgroundView

public enum ChatMessageAttachedContentActionIcon {
    case instant
    case link
}

public struct ChatMessageAttachedContentNodeMediaFlags: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let preferMediaInline = ChatMessageAttachedContentNodeMediaFlags(rawValue: 1 << 0)
    public static let preferMediaBeforeText = ChatMessageAttachedContentNodeMediaFlags(rawValue: 1 << 1)
    public static let preferMediaAspectFilled = ChatMessageAttachedContentNodeMediaFlags(rawValue: 1 << 2)
    public static let titleBeforeMedia = ChatMessageAttachedContentNodeMediaFlags(rawValue: 1 << 3)
}

public final class ChatMessageAttachedContentNode: ASDisplayNode {
    private var backgroundView: MessageInlineBlockBackgroundView?
    
    private let transformContainer: ASDisplayNode
    private var title: TextNodeWithEntities?
    private var subtitle: TextNodeWithEntities?
    private var text: TextNodeWithEntities?
    private var inlineMedia: TransformImageNode?
    private var contentMedia: ChatMessageInteractiveMediaNode?
    private var contentInstantVideo: ChatMessageInteractiveInstantVideoNode?
    private var contentFile: ChatMessageInteractiveFileNode?
    private var actionButton: ChatMessageAttachedContentButtonNode?
    private var actionButtonSeparator: SimpleLayer?
    public var statusNode: ChatMessageDateAndStatusNode?
    
    private var inlineMediaValue: Media?
    
    //private var additionalImageBadgeNode: ChatMessageInteractiveMediaBadge?
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private var context: AccountContext?
    private var message: Message?
    private var media: Media?
    private var theme: ChatPresentationThemeData?
    
    private var isHighlighted: Bool = false
    private var highlightTimer: Foundation.Timer?
    
    public var openMedia: ((InteractiveMediaNodeActivateContent) -> Void)?
    public var activateAction: (() -> Void)?
    public var requestUpdateLayout: (() -> Void)?
    
    private var currentProgressDisposable: Disposable?
    
    public var defaultContentAction: () -> ChatMessageBubbleContentTapAction = { return ChatMessageBubbleContentTapAction(content: .none) }
    
    public var visibility: ListViewItemNodeVisibility = .none {
        didSet {
            if oldValue != self.visibility {
                self.contentMedia?.visibility = self.visibility != .none
                self.contentInstantVideo?.visibility = self.visibility != .none
                
                switch self.visibility {
                case .none:
                    self.text?.visibilityRect = nil
                case let .visible(_, subRect):
                    var subRect = subRect
                    subRect.origin.x = 0.0
                    subRect.size.width = 10000.0
                    self.text?.visibilityRect = subRect
                }
            }
        }
    }
    
    override public init() {
        self.transformContainer = ASDisplayNode()
        
        super.init()
        
        self.addSubnode(self.transformContainer)
    }
    
    deinit {
        self.highlightTimer?.invalidate()
    }
    
    @objc private func pressed() {
        self.activateAction?()
    }
    
    public typealias AsyncLayout = (_ presentationData: ChatPresentationData, _ automaticDownloadSettings: MediaAutoDownloadSettings, _ associatedData: ChatMessageItemAssociatedData, _ attributes: ChatMessageEntryAttributes, _ context: AccountContext, _ controllerInteraction: ChatControllerInteraction, _ message: Message, _ messageRead: Bool, _ chatLocation: ChatLocation, _ title: String?, _ subtitle: NSAttributedString?, _ text: String?, _ entities: [MessageTextEntity]?, _ media: (Media, ChatMessageAttachedContentNodeMediaFlags)?, _ mediaBadge: String?, _ actionIcon: ChatMessageAttachedContentActionIcon?, _ actionTitle: String?, _ displayLine: Bool, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ constrainedSize: CGSize, _ animationCache: AnimationCache, _ animationRenderer: MultiAnimationRenderer) -> (CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void)))
    
    public func makeProgress() -> Promise<Bool> {
        let progress = Promise<Bool>()
        self.currentProgressDisposable?.dispose()
        self.currentProgressDisposable = (progress.get()
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] hasProgress in
            guard let self else {
                return
            }
            self.backgroundView?.displayProgress = hasProgress
        })
        return progress
    }
    
    public func asyncLayout() -> AsyncLayout {
        let makeTitleLayout = TextNodeWithEntities.asyncLayout(self.title)
        let makeSubtitleLayout = TextNodeWithEntities.asyncLayout(self.subtitle)
        let makeTextLayout = TextNodeWithEntities.asyncLayout(self.text)
        let makeContentMedia = ChatMessageInteractiveMediaNode.asyncLayout(self.contentMedia)
        let makeContentFile = ChatMessageInteractiveFileNode.asyncLayout(self.contentFile)
        let makeActionButtonLayout = ChatMessageAttachedContentButtonNode.asyncLayout(self.actionButton)
        let makeStatusLayout = ChatMessageDateAndStatusNode.asyncLayout(self.statusNode)
        
        return { [weak self] presentationData, automaticDownloadSettings, associatedData, attributes, context, controllerInteraction, message, messageRead, chatLocation, title, subtitle, text, entities, mediaAndFlags, mediaBadge, actionIcon, actionTitle, displayLine, layoutConstants, preparePosition, constrainedSize, animationCache, animationRenderer in
            let isPreview = presentationData.isPreview
            let fontSize: CGFloat
            if message.adAttribute != nil {
                fontSize = floor(presentationData.fontSize.baseDisplaySize)
            } else {
                fontSize = floor(presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
            }
            
            let titleFont = Font.semibold(fontSize)
            let textFont = Font.regular(fontSize)
            let textBoldFont = Font.semibold(fontSize)
            let textItalicFont = Font.italic(fontSize)
            let textBoldItalicFont = Font.semiboldItalic(fontSize)
            let textFixedFont = Font.regular(fontSize)
            let textBlockQuoteFont = Font.regular(fontSize)
            
            var incoming = message.effectivelyIncoming(context.account.peerId)
            if let subject = associatedData.subject, case let .messageOptions(_, _, info) = subject, case .forward = info {
                incoming = false
            }
            
            var isReplyThread = false
            if case .replyThread = chatLocation {
                isReplyThread = true
            }
            
            let messageTheme = incoming ? presentationData.theme.theme.chat.message.incoming : presentationData.theme.theme.chat.message.outgoing
            let author = message.author
            let nameColors = author?.nameColor.flatMap { context.peerNameColors.get($0, dark: presentationData.theme.theme.overallDarkAppearance) }
            
            let mainColor: UIColor
            var secondaryColor: UIColor?
            var tertiaryColor: UIColor?
            if !incoming {
                mainColor = messageTheme.accentTextColor
                if let _ = nameColors?.secondary {
                    secondaryColor = .clear
                }
                if let _ = nameColors?.tertiary {
                    tertiaryColor = .clear
                }
            } else {
                var authorNameColor: UIColor?
                authorNameColor = nameColors?.main
                secondaryColor = nameColors?.secondary
                tertiaryColor = nameColors?.tertiary
                
                if let authorNameColor {
                    mainColor = authorNameColor
                } else {
                    mainColor = messageTheme.accentTextColor
                }
            }
            
            let textTopSpacing: CGFloat
            let textBottomSpacing: CGFloat
            
            if displayLine {
                textTopSpacing = 3.0
                textBottomSpacing = 3.0
            } else {
                textTopSpacing = -2.0
                textBottomSpacing = 0.0
            }
            
            let textLineSpacing: CGFloat = 0.09
            let titleTextSpacing: CGFloat = 0.0
            let textContentMediaSpacing: CGFloat = 6.0
            let contentMediaTopSpacing: CGFloat = 6.0
            let contentMediaBottomSpacing: CGFloat = 6.0
            let contentMediaButtonSpacing: CGFloat = 7.0
            let textButtonSpacing: CGFloat = 7.0
            let buttonBottomSpacing: CGFloat = 0.0
            let statusBackgroundSpacing: CGFloat = 9.0
            let inlineMediaEdgeInset: CGFloat = 6.0
            
            var insets = UIEdgeInsets()
            insets.left = layoutConstants.text.bubbleInsets.left
            insets.right = layoutConstants.text.bubbleInsets.right
            
            if case let .linear(top, _) = preparePosition {
                switch top {
                case .None:
                    break
                default:
                    break
                }
            }
            
            if displayLine {
                insets.left += 9.0
                insets.right += 6.0
            }
            
            var contentMediaValue: Media?
            var contentFileValue: TelegramMediaFile?
            
            var contentMediaAutomaticPlayback: Bool = false
            var contentMediaAutomaticDownload: InteractiveMediaNodeAutodownloadMode = .none
            
            var mediaAndFlags = mediaAndFlags
            if let mediaAndFlagsValue = mediaAndFlags {
                if mediaAndFlagsValue.0 is TelegramMediaStory || mediaAndFlagsValue.0 is WallpaperPreviewMedia {
                    var flags = mediaAndFlagsValue.1
                    flags.remove(.preferMediaInline)
                    mediaAndFlags = (mediaAndFlagsValue.0, flags)
                }
            }
            
            var contentMediaAspectFilled = false
            if let (_, flags) = mediaAndFlags {
                contentMediaAspectFilled = flags.contains(.preferMediaAspectFilled)
            }
            var contentMediaInline = false
            
            if let (media, flags) = mediaAndFlags {
                contentMediaInline = flags.contains(.preferMediaInline)
                
                if let file = media as? TelegramMediaFile {
                    if file.mimeType == "application/x-tgtheme-ios", let size = file.size, size < 16 * 1024 {
                        contentMediaValue = file
                    } else if file.isInstantVideo {
                        contentMediaValue = file
                    } else if file.isVideo {
                        contentMediaValue = file
                    } else if file.isSticker || file.isAnimatedSticker {
                        contentMediaValue = file
                    } else {
                        contentFileValue = file
                    }
                    
                    if shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, authorPeerId: message.author?.id, contactsPeerIds: associatedData.contactsPeerIds, media: file) {
                        contentMediaAutomaticDownload = .full
                    } else if shouldPredownloadMedia(settings: automaticDownloadSettings, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, media: file) {
                        contentMediaAutomaticDownload = .prefetch
                    }
                    
                    if file.isAnimated {
                        contentMediaAutomaticPlayback = context.sharedContext.energyUsageSettings.autoplayGif
                    } else if file.isVideo && context.sharedContext.energyUsageSettings.autoplayVideo {
                        var willDownloadOrLocal = false
                        if case .full = contentMediaAutomaticDownload {
                            willDownloadOrLocal = true
                        } else {
                            willDownloadOrLocal = context.account.postbox.mediaBox.completedResourcePath(file.resource) != nil
                        }
                        if willDownloadOrLocal {
                            contentMediaAutomaticPlayback = true
                            contentMediaAspectFilled = true
                        }
                    }
                } else if let _ = media as? TelegramMediaImage {
                    contentMediaValue = media
                } else if let _ = media as? TelegramMediaWebFile {
                    contentMediaValue = media
                } else if let _ = media as? WallpaperPreviewMedia {
                    contentMediaValue = media
                } else if let _ = media as? TelegramMediaStory {
                    contentMediaValue = media
                }
            }
            
            var maxWidth: CGFloat = .greatestFiniteMagnitude
            
            let contentMediaContinueLayout: ((CGSize, Bool, Bool, ImageCorners) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> ChatMessageInteractiveMediaNode)))?
            let inlineMediaAndSize: (Media, CGSize)?
            
            if let contentMediaValue {
                if contentMediaInline {
                    contentMediaContinueLayout = nil
                    
                    if let image = contentMediaValue as? TelegramMediaImage {
                        inlineMediaAndSize = (image, CGSize(width: 54.0, height: 54.0))
                    } else if let file = contentMediaValue as? TelegramMediaFile, !file.previewRepresentations.isEmpty {
                        inlineMediaAndSize = (file, CGSize(width: 54.0, height: 54.0))
                    } else {
                        inlineMediaAndSize = nil
                    }
                } else {
                    let contentMode: InteractiveMediaNodeContentMode = contentMediaAspectFilled ? .aspectFill : .aspectFit
                    
                    let (_, initialImageWidth, refineLayout) = makeContentMedia(
                        context,
                        presentationData,
                        presentationData.dateTimeFormat,
                        message, associatedData,
                        attributes,
                        contentMediaValue,
                        nil,
                        .full,
                        associatedData.automaticDownloadPeerType,
                        associatedData.automaticDownloadPeerId,
                        .constrained(CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height)),
                        layoutConstants,
                        contentMode,
                        controllerInteraction.presentationContext
                    )
                    contentMediaContinueLayout = refineLayout
                    maxWidth = initialImageWidth + insets.left + insets.right
                    
                    inlineMediaAndSize = nil
                }
            } else {
                contentMediaContinueLayout = nil
                inlineMediaAndSize = nil
            }
            
            let contentFileContinueLayout: ChatMessageInteractiveFileNode.ContinueLayout?
            if let contentFileValue {
                let automaticDownload = shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, authorPeerId: message.author?.id, contactsPeerIds: associatedData.contactsPeerIds, media: contentFileValue)
                
                let (_, refineLayout) = makeContentFile(ChatMessageInteractiveFileNode.Arguments(
                    context: context,
                    presentationData: presentationData,
                    customTintColor: incoming ? mainColor : nil,
                    message: message,
                    topMessage: message,
                    associatedData: associatedData,
                    chatLocation: chatLocation,
                    attributes: attributes,
                    isPinned: message.tags.contains(.pinned) && !associatedData.isInPinnedListMode && !isReplyThread,
                    forcedIsEdited: false,
                    file: contentFileValue,
                    automaticDownload: automaticDownload,
                    incoming: incoming,
                    isRecentActions: false,
                    forcedResourceStatus: associatedData.forcedResourceStatus,
                    dateAndStatusType: nil,
                    displayReactions: false,
                    messageSelection: nil,
                    isAttachedContentBlock: true,
                    layoutConstants: layoutConstants,
                    constrainedSize: CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height),
                    controllerInteraction: controllerInteraction
                ))
                contentFileContinueLayout = refineLayout
            } else {
                contentFileContinueLayout = nil
            }
            
            return (maxWidth, { constrainedSize, position in
                enum ContentLayoutOrderItem {
                    case title
                    case subtitle
                    case text
                    case media
                    case file
                    case actionButton
                }
                var contentLayoutOrder: [ContentLayoutOrderItem] = []
                
                if let title = title, !title.isEmpty {
                    contentLayoutOrder.append(.title)
                }
                if let subtitle = subtitle, !subtitle.string.isEmpty {
                    contentLayoutOrder.append(.subtitle)
                }
                if let text = text, !text.isEmpty {
                    contentLayoutOrder.append(.text)
                }
                if contentMediaContinueLayout != nil {
                    if let (_, flags) = mediaAndFlags {
                        if flags.contains(.titleBeforeMedia) {
                            if let index = contentLayoutOrder.firstIndex(of: .title) {
                                contentLayoutOrder.insert(.media, at: index + 1)
                            } else {
                                contentLayoutOrder.insert(.media, at: 0)
                            }
                        } else if flags.contains(.preferMediaBeforeText) {
                            contentLayoutOrder.insert(.media, at: 0)
                        } else {
                            contentLayoutOrder.append(.media)
                        }
                    } else {
                        contentLayoutOrder.append(.media)
                    }
                }
                if contentFileContinueLayout != nil {
                    contentLayoutOrder.append(.file)
                }
                if !isPreview, actionTitle != nil {
                    contentLayoutOrder.append(.actionButton)
                }
                
                var actualWidth: CGFloat = 0.0
                
                let maxContentsWidth: CGFloat = constrainedSize.width - insets.left - insets.right
                
                var titleLayoutAndApply: (TextNodeLayout, (TextNodeWithEntities.Arguments?) -> TextNodeWithEntities)?
                var subtitleLayoutAndApply: (TextNodeLayout, (TextNodeWithEntities.Arguments?) -> TextNodeWithEntities)?
                var textLayoutAndApply: (TextNodeLayout, (TextNodeWithEntities.Arguments?) -> TextNodeWithEntities)?
                
                var remainingCutoutHeight: CGFloat = 0.0
                var cutoutWidth: CGFloat = 0.0
                if let (_, inlineMediaSize) = inlineMediaAndSize {
                    remainingCutoutHeight = inlineMediaSize.height
                    cutoutWidth = inlineMediaSize.width + inlineMediaEdgeInset
                }
                for item in contentLayoutOrder {
                    switch item {
                    case .title:
                        if let title = title, !title.isEmpty {
                            var cutout: TextNodeCutout?
                            if remainingCutoutHeight > 0.0 {
                                cutout = TextNodeCutout(topRight: CGSize(width: cutoutWidth, height: remainingCutoutHeight))
                            }
                            
                            let titleString = NSAttributedString(string: title, font: titleFont, textColor: mainColor)
                            let titleLayoutAndApplyValue = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: maxContentsWidth, height: 10000.0), alignment: .natural, lineSpacing: textLineSpacing, cutout: cutout, insets: UIEdgeInsets()))
                            titleLayoutAndApply = titleLayoutAndApplyValue
                            
                            remainingCutoutHeight -= titleLayoutAndApplyValue.0.size.height
                        }
                    case .subtitle:
                        if let subtitle = subtitle, !subtitle.string.isEmpty {
                            var cutout: TextNodeCutout?
                            if remainingCutoutHeight > 0.0 {
                                cutout = TextNodeCutout(topRight: CGSize(width: cutoutWidth, height: remainingCutoutHeight))
                            }
                            
                            let subtitleString = NSMutableAttributedString(attributedString: subtitle)
                            subtitleString.addAttribute(.foregroundColor, value: messageTheme.primaryTextColor, range: NSMakeRange(0, subtitle.length))
                            subtitleString.addAttribute(.font, value: titleFont, range: NSMakeRange(0, subtitle.length))
                            
                            let subtitleLayoutAndApplyValue = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: subtitleString, backgroundColor: nil, maximumNumberOfLines: 5, truncationType: .end, constrainedSize: CGSize(width: maxContentsWidth, height: 10000.0), alignment: .natural, lineSpacing: textLineSpacing, cutout: cutout, insets: UIEdgeInsets()))
                            subtitleLayoutAndApply = subtitleLayoutAndApplyValue
                            
                            remainingCutoutHeight -= subtitleLayoutAndApplyValue.0.size.height
                        }
                    case .text:
                        if let text = text, !text.isEmpty {
                            var cutout: TextNodeCutout?
                            if remainingCutoutHeight > 0.0 {
                                cutout = TextNodeCutout(topRight: CGSize(width: cutoutWidth, height: remainingCutoutHeight))
                            }
                            
                            let textString = stringWithAppliedEntities(text, entities: entities ?? [], baseColor: messageTheme.primaryTextColor, linkColor: incoming ? mainColor : messageTheme.linkTextColor, baseFont: textFont, linkFont: textFont, boldFont: textBoldFont, italicFont: textItalicFont, boldItalicFont: textBoldItalicFont, fixedFont: textFixedFont, blockQuoteFont: textBlockQuoteFont, message: nil, adjustQuoteFontSize: true)
                            let textLayoutAndApplyValue = makeTextLayout(TextNodeLayoutArguments(attributedString: textString, backgroundColor: nil, maximumNumberOfLines: 12, truncationType: .end, constrainedSize: CGSize(width: maxContentsWidth, height: 10000.0), alignment: .natural, lineSpacing: textLineSpacing, cutout: cutout, insets: UIEdgeInsets()))
                            textLayoutAndApply = textLayoutAndApplyValue
                            
                            remainingCutoutHeight -= textLayoutAndApplyValue.0.size.height
                        }
                    case .media, .file, .actionButton:
                        break
                    }
                }
                
                if let (titleLayout, _) = titleLayoutAndApply {
                    actualWidth = max(actualWidth, titleLayout.size.width)
                }
                if let (subtitleLayout, _) = subtitleLayoutAndApply {
                    actualWidth = max(actualWidth, subtitleLayout.size.width)
                }
                if let (textLayout, _) = textLayoutAndApply {
                    actualWidth = max(actualWidth, textLayout.size.width)
                }
                
                let actionButtonMinWidthAndFinalizeLayout: (CGFloat, ((CGFloat, CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageAttachedContentButtonNode)))?
                if !isPreview, let actionTitle {
                    var buttonIconImage: UIImage?
                    var cornerIcon = false
                    
                    if incoming {
                        if let actionIcon {
                            switch actionIcon {
                            case .instant:
                                buttonIconImage = PresentationResourcesChat.chatMessageAttachedContentButtonIconInstantIncoming(presentationData.theme.theme)!
                            case .link:
                                buttonIconImage = PresentationResourcesChat.chatMessageAttachedContentButtonIconLinkIncoming(presentationData.theme.theme)!
                                cornerIcon = true
                            }
                        }
                    } else {
                        if let actionIcon {
                            switch actionIcon {
                            case .instant:
                                buttonIconImage = PresentationResourcesChat.chatMessageAttachedContentButtonIconInstantOutgoing(presentationData.theme.theme)!
                            case .link:
                                buttonIconImage = PresentationResourcesChat.chatMessageAttachedContentButtonIconLinkOutgoing(presentationData.theme.theme)!
                                cornerIcon = true
                            }
                        }
                    }
                                                
                    let (buttonWidth, continueLayout) = makeActionButtonLayout(
                        maxContentsWidth,
                        buttonIconImage,
                        cornerIcon,
                        actionTitle,
                        mainColor,
                        false,
                        message.adAttribute != nil
                    )
                    actionButtonMinWidthAndFinalizeLayout = (buttonWidth, continueLayout)
                    actualWidth = max(actualWidth, buttonWidth)
                } else {
                    actionButtonMinWidthAndFinalizeLayout = nil
                }
                
                let contentMediaFinalizeLayout: ((CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> ChatMessageInteractiveMediaNode))?
                if let contentMediaContinueLayout {
                    let (refinedWidth, finalizeImageLayout) = contentMediaContinueLayout(CGSize(width: constrainedSize.width, height: constrainedSize.height), contentMediaAutomaticPlayback, true, ImageCorners(radius: 4.0))
                    actualWidth = max(actualWidth, refinedWidth)
                    contentMediaFinalizeLayout = finalizeImageLayout
                } else {
                    contentMediaFinalizeLayout = nil
                }
                
                let contentFileFinalizeLayout: ChatMessageInteractiveFileNode.FinalizeLayout?
                if let contentFileContinueLayout {
                    let (refinedWidth, finalizeFileLayout) = contentFileContinueLayout(CGSize(width: constrainedSize.width, height: constrainedSize.height))
                    actualWidth = max(actualWidth, refinedWidth)
                    contentFileFinalizeLayout = finalizeFileLayout
                } else {
                    contentFileFinalizeLayout = nil
                }
                
                var edited = false
                if attributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var dateReplies = 0
                var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeer: associatedData.accountPeer, message: message)
                if message.isRestricted(platform: "ios", contentSettings: context.currentContentSettings.with { $0 }) {
                    dateReactionsAndPeers = ([], [])
                }
                for attribute in message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = chatLocation {
                        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    }
                }
                
                let dateText = stringForMessageTimestampStatus(accountPeerId: context.account.peerId, message: message, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, strings: presentationData.strings, associatedData: associatedData)
                
                let statusType: ChatMessageDateAndStatusType
                if incoming {
                    statusType = .BubbleIncoming
                } else {
                    if message.flags.contains(.Failed) {
                        statusType = .BubbleOutgoing(.Failed)
                    } else if (message.flags.isSending && !message.isSentOrAcknowledged) || attributes.updatingMedia != nil {
                        statusType = .BubbleOutgoing(.Sending)
                    } else {
                        statusType = .BubbleOutgoing(.Sent(read: messageRead))
                    }
                }
                
                let maxStatusContentWidth: CGFloat = constrainedSize.width - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right
                
                var trailingContentWidth: CGFloat?
                if let _ = message.adAttribute, let (textLayout, _) = textLayoutAndApply {
                    if textLayout.hasRTL {
                        trailingContentWidth = 10000.0
                    } else {
                        trailingContentWidth = textLayout.trailingLineWidth
                    }
                } else {
                    if !displayLine, let (actionButtonMinWidth, _) = actionButtonMinWidthAndFinalizeLayout {
                        trailingContentWidth = actionButtonMinWidth
                    }
                }
                
                var statusLayoutAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageDateAndStatusNode))?
                if case let .linear(_, bottom) = position {
                    switch bottom {
                    case .None, .Neighbour(_, .footer, _):
                        let statusLayoutAndContinueValue = makeStatusLayout(ChatMessageDateAndStatusNode.Arguments(
                            context: context,
                            presentationData: presentationData,
                            edited: edited,
                            impressionCount: viewCount,
                            dateText: dateText,
                            type: statusType,
                            layoutInput: .trailingContent(
                                contentWidth: trailingContentWidth,
                                reactionSettings: ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: shouldDisplayInlineDateReactions(message: message, isPremium: associatedData.isPremium, forceInline: associatedData.forceInlineReactions), preferAdditionalInset: false)
                            ),
                            constrainedSize: CGSize(width: maxStatusContentWidth, height: CGFloat.greatestFiniteMagnitude),
                            availableReactions: associatedData.availableReactions,
                            reactions: dateReactionsAndPeers.reactions,
                            reactionPeers: dateReactionsAndPeers.peers,
                            displayAllReactionPeers: message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                            replyCount: dateReplies,
                            isPinned: message.tags.contains(.pinned) && !associatedData.isInPinnedListMode && !isReplyThread,
                            hasAutoremove: message.isSelfExpiring,
                            canViewReactionList: canViewMessageReactionList(message: message),
                            animationCache: controllerInteraction.presentationContext.animationCache,
                            animationRenderer: controllerInteraction.presentationContext.animationRenderer
                        ))
                        statusLayoutAndContinue = statusLayoutAndContinueValue
                        actualWidth = max(actualWidth, statusLayoutAndContinueValue.0)
                    default:
                        break
                    }
                }
                
                actualWidth += insets.left + insets.right
                
                return (actualWidth, { resultingWidth in
                    let statusSizeAndApply = statusLayoutAndContinue?.1(resultingWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right - 6.0)
                    
                    let contentMediaSizeAndApply: (CGSize, (ListViewItemUpdateAnimation, Bool) -> ChatMessageInteractiveMediaNode)?
                    if let contentMediaFinalizeLayout {
                        let (size, apply) = contentMediaFinalizeLayout(resultingWidth - insets.left - insets.right)
                        contentMediaSizeAndApply = (size, apply)
                    } else {
                        contentMediaSizeAndApply = nil
                    }
                    
                    let contentFileSizeAndApply: (CGSize, ChatMessageInteractiveFileNode.Apply)?
                    if let contentFileFinalizeLayout {
                        let (size, apply) = contentFileFinalizeLayout(resultingWidth - insets.left - insets.right)
                        contentFileSizeAndApply = (size, apply)
                    } else {
                        contentFileSizeAndApply = nil
                    }
                    
                    let actionButtonSizeAndApply: ((CGSize, (ListViewItemUpdateAnimation) -> ChatMessageAttachedContentButtonNode))?
                    if let (_, actionButtonFinalizeLayout) = actionButtonMinWidthAndFinalizeLayout {
                        let (size, apply) = actionButtonFinalizeLayout(resultingWidth - insets.left - insets.right, 36.0)
                        actionButtonSizeAndApply = (size, apply)
                    } else {
                        actionButtonSizeAndApply = nil
                    }
                    
                    var actualSize = CGSize()
                    
                    var backgroundInsets = UIEdgeInsets()
                    backgroundInsets.left += layoutConstants.text.bubbleInsets.left
                    backgroundInsets.right += layoutConstants.text.bubbleInsets.right
                    
                    if case let .linear(top, _) = position {
                        switch top {
                        case .None:
                            actualSize.height += 11.0
                            backgroundInsets.top = actualSize.height
                        default:
                            break
                        }
                    }
                    
                    actualSize.width = resultingWidth
                    
                    struct ContentDisplayOrderItem {
                        let item: ContentLayoutOrderItem
                        let offsetY: CGFloat
                    }
                    var contentDisplayOrder: [ContentDisplayOrderItem] = []
                    
                    for i in 0 ..< contentLayoutOrder.count {
                        let item = contentLayoutOrder[i]
                        switch item {
                        case .title:
                            if let (titleLayout, _) = titleLayoutAndApply {
                                if i == 0 {
                                    actualSize.height += textTopSpacing
                                } else if contentLayoutOrder[i - 1] == .media || contentLayoutOrder[i - 1] == .file {
                                    actualSize.height += textContentMediaSpacing
                                }
                                
                                contentDisplayOrder.append(ContentDisplayOrderItem(
                                    item: item,
                                    offsetY: actualSize.height
                                ))
                                
                                actualSize.height += titleLayout.size.height - titleLayout.insets.top - titleLayout.insets.bottom
                            }
                        case .subtitle:
                            if let (subtitleLayout, _) = subtitleLayoutAndApply {
                                if i == 0 {
                                    actualSize.height += textTopSpacing
                                } else if contentLayoutOrder[i - 1] == .title {
                                    actualSize.height += titleTextSpacing
                                } else if contentLayoutOrder[i - 1] == .media || contentLayoutOrder[i - 1] == .file {
                                    actualSize.height += textContentMediaSpacing
                                }
                                
                                contentDisplayOrder.append(ContentDisplayOrderItem(
                                    item: item,
                                    offsetY: actualSize.height
                                ))
                                
                                actualSize.height += subtitleLayout.size.height - subtitleLayout.insets.top - subtitleLayout.insets.bottom
                            }
                        case .text:
                            if let (textLayout, _) = textLayoutAndApply {
                                if i == 0 {
                                    actualSize.height += textTopSpacing
                                } else if contentLayoutOrder[i - 1] == .title || contentLayoutOrder[i - 1] == .subtitle {
                                    actualSize.height += titleTextSpacing
                                } else if contentLayoutOrder[i - 1] == .media || contentLayoutOrder[i - 1] == .file {
                                    actualSize.height += textContentMediaSpacing
                                }
                                
                                contentDisplayOrder.append(ContentDisplayOrderItem(
                                    item: item,
                                    offsetY: actualSize.height
                                ))
                                
                                actualSize.height += textLayout.size.height - textLayout.insets.top - textLayout.insets.bottom
                            }
                        case .media:
                            if let (contentMediaSize, _) = contentMediaSizeAndApply {
                                if i == 0 {
                                    actualSize.height += contentMediaTopSpacing
                                } else if contentLayoutOrder[i - 1] == .title || contentLayoutOrder[i - 1] == .subtitle || contentLayoutOrder[i - 1] == .text {
                                    actualSize.height += textContentMediaSpacing
                                }
                                
                                contentDisplayOrder.append(ContentDisplayOrderItem(
                                    item: item,
                                    offsetY: actualSize.height
                                ))
                                
                                actualSize.height += contentMediaSize.height
                            }
                        case .file:
                            if let (contentFileSize, _) = contentFileSizeAndApply {
                                if i == 0 {
                                    actualSize.height += contentMediaTopSpacing
                                } else if contentLayoutOrder[i - 1] == .title || contentLayoutOrder[i - 1] == .subtitle || contentLayoutOrder[i - 1] == .text {
                                    actualSize.height += textContentMediaSpacing
                                }
                                
                                contentDisplayOrder.append(ContentDisplayOrderItem(
                                    item: item,
                                    offsetY: actualSize.height
                                ))
                                
                                actualSize.height += contentFileSize.height
                            }
                        case .actionButton:
                            if let (actionButtonSize, _) = actionButtonSizeAndApply {
                                if i != 0 {
                                    switch contentLayoutOrder[i - 1] {
                                    case .title, .subtitle, .text:
                                        actualSize.height += textButtonSpacing
                                    case .media, .file:
                                        actualSize.height += contentMediaButtonSpacing
                                    default:
                                        break
                                    }
                                }
                                
                                if let (_, inlineMediaSize) = inlineMediaAndSize {
                                    if actualSize.height < insets.top + inlineMediaEdgeInset + inlineMediaSize.height + contentMediaButtonSpacing {
                                        actualSize.height = insets.top + inlineMediaEdgeInset + inlineMediaSize.height + contentMediaButtonSpacing
                                    }
                                }
                                
                                contentDisplayOrder.append(ContentDisplayOrderItem(
                                    item: item,
                                    offsetY: actualSize.height
                                ))
                                
                                actualSize.height += actionButtonSize.height
                            }
                        }
                    }
                    
                    if !contentLayoutOrder.isEmpty {
                        switch contentLayoutOrder[contentLayoutOrder.count - 1] {
                        case .title, .subtitle, .text:
                            actualSize.height += textBottomSpacing
                            
                            if let (_, inlineMediaSize) = inlineMediaAndSize {
                                if actualSize.height < backgroundInsets.top + inlineMediaEdgeInset + inlineMediaSize.height + inlineMediaEdgeInset {
                                    actualSize.height = backgroundInsets.top + inlineMediaEdgeInset + inlineMediaSize.height + inlineMediaEdgeInset
                                }
                            }
                        case .media, .file:
                            actualSize.height += contentMediaBottomSpacing
                        case .actionButton:
                            actualSize.height += buttonBottomSpacing
                        }
                    } else {
                        if let (_, inlineMediaSize) = inlineMediaAndSize {
                            if actualSize.height < backgroundInsets.top + inlineMediaEdgeInset + inlineMediaSize.height + inlineMediaEdgeInset {
                                actualSize.height = backgroundInsets.top + inlineMediaEdgeInset + inlineMediaSize.height + inlineMediaEdgeInset
                            }
                        }
                    }
                    
                    if case let .linear(_, bottom) = position, let statusSizeAndApply {
                        switch bottom {
                        case .None, .Neighbour(_, .footer, _):
                            let bottomStatusContentHeight = statusBackgroundSpacing + statusSizeAndApply.0.height
                            actualSize.height += bottomStatusContentHeight
                            backgroundInsets.bottom += bottomStatusContentHeight
                        default:
                            break
                        }
                    }
                    
                    if let _ = message.adAttribute {
                        actualSize.height += 2.0
                        backgroundInsets.bottom += 2.0
                    }
                    
                    return (actualSize, { animation, synchronousLoads, applyInfo in
                        guard let self else {
                            return
                        }
                        
                        self.context = context
                        self.message = message
                        self.media = mediaAndFlags?.0
                        self.theme = presentationData.theme
                        
                        animation.animator.updateFrame(layer: self.transformContainer.layer, frame: CGRect(origin: CGPoint(), size: actualSize), completion: nil)
                        
                        if displayLine {
                            let backgroundFrame = CGRect(origin: CGPoint(x: backgroundInsets.left, y: backgroundInsets.top), size: CGSize(width: actualSize.width - backgroundInsets.left - backgroundInsets.right, height: actualSize.height - backgroundInsets.top - backgroundInsets.bottom))
                            
                            let backgroundView: MessageInlineBlockBackgroundView
                            if let current = self.backgroundView {
                                backgroundView = current
                                animation.animator.updateFrame(layer: backgroundView.layer, frame: backgroundFrame, completion: nil)
                                backgroundView.update(size: backgroundFrame.size, isTransparent: false, primaryColor: mainColor, secondaryColor: secondaryColor, thirdColor: tertiaryColor, backgroundColor: nil, pattern: nil, animation: animation)
                            } else {
                                backgroundView = MessageInlineBlockBackgroundView()
                                self.backgroundView = backgroundView
                                backgroundView.frame = backgroundFrame
                                self.transformContainer.view.insertSubview(backgroundView, at: 0)
                                backgroundView.update(size: backgroundFrame.size, isTransparent: false, primaryColor: mainColor, secondaryColor: secondaryColor, thirdColor: tertiaryColor, backgroundColor: nil, pattern: nil, animation: .None)
                            }
                        } else {
                            if let backgroundView = self.backgroundView {
                                self.backgroundView = nil
                                backgroundView.removeFromSuperview()
                            }
                        }
                        
                        if let (inlineMediaValue, inlineMediaSize) = inlineMediaAndSize {
                            var inlineMediaFrame = CGRect(origin: CGPoint(x: actualSize.width - insets.right - inlineMediaSize.width, y: backgroundInsets.top + inlineMediaEdgeInset), size: inlineMediaSize)
                            if contentLayoutOrder.isEmpty {
                                inlineMediaFrame.origin.x = insets.left
                            }
                            
                            let inlineMedia: TransformImageNode
                            var updateMedia = false
                            if let current = self.inlineMedia {
                                inlineMedia = current
                                
                                if let curentInlineMediaValue = self.inlineMediaValue {
                                    updateMedia = !curentInlineMediaValue.isSemanticallyEqual(to: inlineMediaValue)
                                } else {
                                    updateMedia = true
                                }
                                
                                animation.animator.updateFrame(layer: inlineMedia.layer, frame: inlineMediaFrame, completion: nil)
                            } else {
                                inlineMedia = TransformImageNode()
                                inlineMedia.contentAnimations = .subsequentUpdates
                                self.inlineMedia = inlineMedia
                                self.transformContainer.addSubnode(inlineMedia)
                                
                                inlineMedia.frame = inlineMediaFrame
                                
                                updateMedia = true
                                
                                inlineMedia.alpha = 0.0
                                animation.animator.updateAlpha(layer: inlineMedia.layer, alpha: 1.0, completion: nil)
                                animation.animator.animateScale(layer: inlineMedia.layer, from: 0.01, to: 1.0, completion: nil)
                            }
                            self.inlineMediaValue = inlineMediaValue
                            
                            var fittedImageSize = inlineMediaSize
                            if let image = inlineMediaValue as? TelegramMediaImage {
                                if let dimensions = image.representations.last?.dimensions.cgSize {
                                    fittedImageSize = dimensions.aspectFilled(inlineMediaSize)
                                }
                            } else if let file = inlineMediaValue as? TelegramMediaFile {
                                if let dimensions = file.dimensions?.cgSize {
                                    fittedImageSize = dimensions.aspectFilled(inlineMediaSize)
                                }
                            }
                            
                            if updateMedia {
                                let resolvedInlineMediaValue = inlineMediaValue
                                
                                if let image = resolvedInlineMediaValue as? TelegramMediaImage {
                                    let updateInlineImageSignal = chatWebpageSnippetPhoto(account: context.account, userLocation: .peer(message.id.peerId), photoReference: .message(message: MessageReference(message), media: image), placeholderColor: mainColor.withMultipliedAlpha(0.1))
                                    inlineMedia.setSignal(updateInlineImageSignal)
                                } else if let file = resolvedInlineMediaValue as? TelegramMediaFile, let representation = file.previewRepresentations.last {
                                    let updateInlineImageSignal = chatWebpageSnippetFile(account: context.account, userLocation: .peer(message.id.peerId), mediaReference: .message(message: MessageReference(message), media: file), representation: representation)
                                    inlineMedia.setSignal(updateInlineImageSignal)
                                }
                            }
                            
                            inlineMedia.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 4.0), imageSize: fittedImageSize, boundingSize: inlineMediaSize, intrinsicInsets: UIEdgeInsets(), emptyColor: mainColor.withMultipliedAlpha(0.1)))()
                        } else {
                            if let inlineMedia = self.inlineMedia {
                                self.inlineMedia = nil
                                
                                let inlineMediaFrame = CGRect(origin: CGPoint(x: actualSize.width - insets.right - inlineMedia.bounds.width, y: backgroundInsets.top + inlineMediaEdgeInset), size: inlineMedia.bounds.size)
                                animation.animator.updateFrame(layer: inlineMedia.layer, frame: inlineMediaFrame, completion: nil)
                                animation.animator.updateAlpha(layer: inlineMedia.layer, alpha: 0.0, completion: nil)
                                animation.animator.updateScale(layer: inlineMedia.layer, scale: 0.01, completion: { [weak inlineMedia] _ in
                                    inlineMedia?.removeFromSupernode()
                                })
                            }
                        }
                        
                        if let item = contentDisplayOrder.first(where: { $0.item == .title }), let (titleLayout, titleApply) = titleLayoutAndApply {
                            let title = titleApply(TextNodeWithEntities.Arguments(
                                context: context,
                                cache: animationCache,
                                renderer: animationRenderer,
                                placeholderColor: messageTheme.mediaPlaceholderColor,
                                attemptSynchronous: synchronousLoads
                            ))
                            
                            let titleFrame = CGRect(origin: CGPoint(x: -titleLayout.insets.left + insets.left, y: -titleLayout.insets.top + item.offsetY), size: titleLayout.size)
                            
                            if self.title !== title {
                                self.title?.textNode.removeFromSupernode()
                                self.title = title
                                title.textNode.layer.anchorPoint = CGPoint()
                                self.transformContainer.addSubnode(title.textNode)
                                
                                title.textNode.frame = titleFrame
                            } else {
                                title.textNode.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                                animation.animator.updatePosition(layer: title.textNode.layer, position: titleFrame.origin, completion: nil)
                            }
                        } else {
                            if let title = self.title {
                                self.title = nil
                                title.textNode.removeFromSupernode()
                            }
                        }
                        
                        if let item = contentDisplayOrder.first(where: { $0.item == .subtitle }), let (subtitleLayout, subtitleApply) = subtitleLayoutAndApply {
                            let subtitle = subtitleApply(TextNodeWithEntities.Arguments(
                                context: context,
                                cache: animationCache,
                                renderer: animationRenderer,
                                placeholderColor: messageTheme.mediaPlaceholderColor,
                                attemptSynchronous: synchronousLoads
                            ))
                            
                            let subtitleFrame = CGRect(origin: CGPoint(x: -subtitleLayout.insets.left + insets.left, y: -subtitleLayout.insets.top + item.offsetY), size: subtitleLayout.size)
                            
                            if self.subtitle !== subtitle {
                                self.subtitle?.textNode.removeFromSupernode()
                                self.subtitle = subtitle
                                subtitle.textNode.layer.anchorPoint = CGPoint()
                                self.transformContainer.addSubnode(subtitle.textNode)
                                
                                subtitle.textNode.frame = subtitleFrame
                            } else {
                                subtitle.textNode.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
                                animation.animator.updatePosition(layer: subtitle.textNode.layer, position: subtitleFrame.origin, completion: nil)
                            }
                        } else {
                            if let subtitle = self.subtitle {
                                self.subtitle = nil
                                subtitle.textNode.removeFromSupernode()
                            }
                        }
                        
                        if let item = contentDisplayOrder.first(where: { $0.item == .text }), let (textLayout, textApply) = textLayoutAndApply {
                            let text = textApply(TextNodeWithEntities.Arguments(
                                context: context,
                                cache: animationCache,
                                renderer: animationRenderer,
                                placeholderColor: messageTheme.mediaPlaceholderColor,
                                attemptSynchronous: synchronousLoads
                            ))
                            
                            let textFrame = CGRect(origin: CGPoint(x: -textLayout.insets.left + insets.left, y: -textLayout.insets.top + item.offsetY), size: textLayout.size)
                            
                            if self.text !== text {
                                self.text?.textNode.removeFromSupernode()
                                self.text = text
                                text.textNode.layer.anchorPoint = CGPoint()
                                self.transformContainer.addSubnode(text.textNode)
                                
                                text.textNode.frame = textFrame
                            } else {
                                text.textNode.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
                                animation.animator.updatePosition(layer: text.textNode.layer, position: textFrame.origin, completion: nil)
                            }
                        } else {
                            if let text = self.text {
                                self.text = nil
                                text.textNode.removeFromSupernode()
                            }
                        }
                        
                        if let item = contentDisplayOrder.first(where: { $0.item == .media }), let (contentMediaSize, contentMediaApply) = contentMediaSizeAndApply {
                            let contentMediaFrame = CGRect(origin: CGPoint(x: insets.left, y: item.offsetY), size: contentMediaSize)
                            
                            let contentMedia = contentMediaApply(animation, synchronousLoads)
                            if self.contentMedia !== contentMedia {
                                self.contentMedia?.removeFromSupernode()
                                self.contentMedia = contentMedia
                                
                                contentMedia.activateLocalContent = { [weak self] mode in
                                    guard let self else {
                                        return
                                    }
                                    self.openMedia?(mode)
                                }
                                contentMedia.updateMessageReaction = { [weak controllerInteraction] message, value in
                                    guard let controllerInteraction else {
                                        return
                                    }
                                    controllerInteraction.updateMessageReaction(message, value)
                                }
                                contentMedia.visibility = self.visibility != .none
                                
                                self.transformContainer.addSubnode(contentMedia)
                                
                                contentMedia.frame = contentMediaFrame
                                
                                contentMedia.alpha = 0.0
                                animation.animator.updateAlpha(layer: contentMedia.layer, alpha: 1.0, completion: nil)
                                animation.animator.animateScale(layer: contentMedia.layer, from: 0.01, to: 1.0, completion: nil)
                            } else {
                                animation.animator.updateFrame(layer: contentMedia.layer, frame: contentMediaFrame, completion: nil)
                            }
                        } else {
                            if let contentMedia = self.contentMedia {
                                self.contentMedia = nil
                                
                                animation.animator.updateAlpha(layer: contentMedia.layer, alpha: 0.0, completion: nil)
                                animation.animator.updateScale(layer: contentMedia.layer, scale: 0.01, completion: { [weak contentMedia] _ in
                                    contentMedia?.removeFromSupernode()
                                })
                            }
                        }
                        
                        if let item = contentDisplayOrder.first(where: { $0.item == .file }), let (contentFileSize, contentFileApply) = contentFileSizeAndApply {
                            let contentFileFrame = CGRect(origin: CGPoint(x: insets.left, y: item.offsetY), size: contentFileSize)
                            
                            let contentFile = contentFileApply(synchronousLoads, animation, applyInfo)
                            if self.contentFile !== contentFile {
                                self.contentFile?.removeFromSupernode()
                                self.contentFile = contentFile
                                
                                contentFile.activateLocalContent = { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.openMedia?(.default)
                                }
                                contentFile.visibility = self.visibility != .none
                                
                                self.transformContainer.addSubnode(contentFile)
                                
                                contentFile.frame = contentFileFrame
                                
                                contentFile.alpha = 0.0
                                animation.animator.updateAlpha(layer: contentFile.layer, alpha: 1.0, completion: nil)
                                animation.animator.animateScale(layer: contentFile.layer, from: 0.01, to: 1.0, completion: nil)
                            } else {
                                animation.animator.updateFrame(layer: contentFile.layer, frame: contentFileFrame, completion: nil)
                            }
                        } else {
                            if let contentFile = self.contentFile {
                                self.contentFile = nil
                                
                                animation.animator.updateAlpha(layer: contentFile.layer, alpha: 0.0, completion: nil)
                                animation.animator.updateScale(layer: contentFile.layer, scale: 0.01, completion: { [weak contentFile] _ in
                                    contentFile?.removeFromSupernode()
                                })
                            }
                        }
                        
                        if let item = contentDisplayOrder.first(where: { $0.item == .actionButton }), let (actionButtonSize, actionButtonApply) = actionButtonSizeAndApply {
                            var actionButtonFrame = CGRect(origin: CGPoint(x: insets.left, y: item.offsetY), size: actionButtonSize)
                            if let _ = message.adAttribute, let statusSizeAndApply {
                                actionButtonFrame.origin.y += statusSizeAndApply.0.height
                            }
                            
                            let actionButton = actionButtonApply(animation)
                            
                            if self.actionButton !== actionButton {
                                self.actionButton?.removeFromSupernode()
                                self.actionButton = actionButton
                                self.transformContainer.addSubnode(actionButton)
                                actionButton.frame = actionButtonFrame
                                
                                actionButton.pressed = { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.activateAction?()
                                }
                            } else {
                                animation.animator.updateFrame(layer: actionButton.layer, frame: actionButtonFrame, completion: nil)
                            }
                            
                            if let _ = message.adAttribute {
                                
                            } else {
                                let separatorFrame = CGRect(origin: CGPoint(x: actionButtonFrame.minX, y: actionButtonFrame.minY - 1.0), size: CGSize(width: actionButtonFrame.width, height: UIScreenPixel))
                                
                                let actionButtonSeparator: SimpleLayer
                                if let current = self.actionButtonSeparator {
                                    actionButtonSeparator = current
                                    animation.animator.updateFrame(layer: actionButtonSeparator, frame: separatorFrame, completion: nil)
                                } else {
                                    actionButtonSeparator = SimpleLayer()
                                    self.actionButtonSeparator = actionButtonSeparator
                                    self.layer.addSublayer(actionButtonSeparator)
                                    actionButtonSeparator.frame = separatorFrame
                                }
                                
                                actionButtonSeparator.backgroundColor = mainColor.withMultipliedAlpha(0.2).cgColor
                            }
                        } else {
                            if let actionButton = self.actionButton {
                                self.actionButton = nil
                                actionButton.removeFromSupernode()
                            }
                        }
                        
                        if self.actionButton == nil, let actionButtonSeparator = self.actionButtonSeparator {
                            self.actionButtonSeparator = nil
                            actionButtonSeparator.removeFromSuperlayer()
                        }
                        
                        if let statusSizeAndApply {
                            var statusFrame = CGRect(origin: CGPoint(x: actualSize.width - backgroundInsets.right - statusSizeAndApply.0.width, y: actualSize.height - layoutConstants.text.bubbleInsets.bottom - statusSizeAndApply.0.height), size: statusSizeAndApply.0)
                            if let _ = message.adAttribute, let (actionButtonSize, _) = actionButtonSizeAndApply {
                                statusFrame.origin.y -= actionButtonSize.height + statusBackgroundSpacing
                            }
                            
                            let statusNode = statusSizeAndApply.1(self.statusNode == nil ? .None : animation)
                            if self.statusNode !== statusNode {
                                self.statusNode?.removeFromSupernode()
                                self.statusNode = statusNode
                                self.addSubnode(statusNode)
                                
                                statusNode.reactionSelected = { [weak self] value in
                                    guard let self, let message = self.message else {
                                        return
                                    }
                                    controllerInteraction.updateMessageReaction(message, .reaction(value))
                                }
                                
                                statusNode.openReactionPreview = { [weak self] gesture, sourceNode, value in
                                    guard let self, let message = self.message else {
                                        gesture?.cancel()
                                        return
                                    }
                                    controllerInteraction.openMessageReactionContextMenu(message, sourceNode, gesture, value)
                                }
                                
                                statusNode.frame = statusFrame
                            } else {
                                animation.animator.updateFrame(layer: statusNode.layer, frame: statusFrame, completion: nil)
                            }
                        } else if let statusNode = self.statusNode {
                            self.statusNode = nil
                            statusNode.removeFromSupernode()
                        }
                    })
                })
            })
        }
    }
    
    public func updateHiddenMedia(_ media: [Media]?) -> Bool {
        if let currentMedia = self.media {
            if let media = media {
                var found = false
                for m in media {
                    if currentMedia.isEqual(to: m) {
                        found = true
                        break
                    }
                }
                if let contentImageNode = self.contentMedia {
                    contentImageNode.isHidden = found
                    contentImageNode.updateIsHidden(found)
                    return found
                }
            } else if let contentImageNode = self.contentMedia {
                contentImageNode.isHidden = false
                contentImageNode.updateIsHidden(false)
            }
        }
        return false
    }
    
    public func transitionNode(media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if let contentImageNode = self.contentMedia, let image = self.media as? TelegramMediaImage, image.isEqual(to: media) {
            return (contentImageNode, contentImageNode.bounds, { [weak contentImageNode] in
                return (contentImageNode?.view.snapshotContentTree(unhide: true), nil)
            })
        } else if let contentImageNode = self.contentMedia, let file = self.media as? TelegramMediaFile, file.isEqual(to: media) {
            return (contentImageNode, contentImageNode.bounds, { [weak contentImageNode] in
                return (contentImageNode?.view.snapshotContentTree(unhide: true), nil)
            })
        } else if let contentImageNode = self.contentMedia, let story = self.media as? TelegramMediaStory, story.isEqual(to: media) {
            return (contentImageNode, contentImageNode.bounds, { [weak contentImageNode] in
                return (contentImageNode?.view.snapshotContentTree(unhide: true), nil)
            })
        }
        return nil
    }
    
    public func hasActionAtPoint(_ point: CGPoint) -> Bool {
        if let buttonNode = self.actionButton, buttonNode.frame.contains(point) {
            return true
        }
        return false
    }
    
    public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if let text = self.text {
            let textNodeFrame = text.textNode.frame
            if let (index, attributes) = text.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                    var concealed = true
                    if let (attributeText, fullText) = text.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                        concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                    }
                    return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: url, concealed: concealed)))
                } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                    return ChatMessageBubbleContentTapAction(content: .peerMention(peerId: peerMention.peerId, mention: peerMention.mention, openProfile: false))
                } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                    return ChatMessageBubbleContentTapAction(content: .textMention(peerName))
                } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                    return ChatMessageBubbleContentTapAction(content: .botCommand(botCommand))
                } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                    return ChatMessageBubbleContentTapAction(content: .hashtag(hashtag.peerName, hashtag.hashtag))
                }
            }
        }
        
        if let actionButton = self.actionButton, actionButton.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        
        if let backgroundView = self.backgroundView, backgroundView.frame.contains(point) {
            return self.defaultContentAction()
        } else {
            return .init(content: .none)
        }
    }
    
    public func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let context = self.context, let message = self.message, let theme = self.theme else {
            return
        }
        var rects: [CGRect]?
        if let point = point {
            if let text = self.text {
                let textNodeFrame = text.textNode.frame
                if let (index, attributes) = text.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag,
                        TelegramTextAttributes.BankCard
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = text.textNode.attributeRects(name: name, at: index)
                            break
                        }
                    }
                }
            }
        }
        
        if let rects = rects, let text = self.text {
            let linkHighlightingNode: LinkHighlightingNode
            if let current = self.linkHighlightingNode {
                linkHighlightingNode = current
            } else {
                linkHighlightingNode = LinkHighlightingNode(color: message.effectivelyIncoming(context.account.peerId) ? theme.theme.chat.message.incoming.linkHighlightColor : theme.theme.chat.message.outgoing.linkHighlightColor)
                self.linkHighlightingNode = linkHighlightingNode
                self.transformContainer.insertSubnode(linkHighlightingNode, belowSubnode: text.textNode)
            }
            linkHighlightingNode.frame = text.textNode.frame
            linkHighlightingNode.updateRects(rects)
        } else if let linkHighlightingNode = self.linkHighlightingNode {
            self.linkHighlightingNode = nil
            linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                linkHighlightingNode?.removeFromSupernode()
            })
        }
        
        var isHighlighted = false
        if rects == nil, let point {
            if let actionButton = self.actionButton, actionButton.frame.contains(point) {
            } else if let backgroundView = self.backgroundView, backgroundView.frame.contains(point) {
                isHighlighted = true
            }
        }
        
        if self.isHighlighted != isHighlighted {
            self.isHighlighted = isHighlighted
            
            if isHighlighted {
                /*self.highlightTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false, block: { [weak self] timer in
                    guard let self else {
                        return
                    }
                    if self.highlightTimer === timer {
                        self.highlightTimer = nil
                    }
                    self.applyIsHighlighted()
                })*/
                self.applyIsHighlighted()
            } else {
                self.applyIsHighlighted()
            }
        }
    }
    
    private func applyIsHighlighted() {
        if let highlightTimer = self.highlightTimer {
            self.highlightTimer = nil
            highlightTimer.invalidate()
        }
        
        let transition: ContainedViewLayoutTransition = .animated(duration: self.isHighlighted ? 0.3 : 0.2, curve: .easeInOut)
        let scale: CGFloat = self.isHighlighted ? ((self.bounds.width - 5.0) / self.bounds.width) : 1.0
        transition.updateSublayerTransformScale(node: self.transformContainer, scale: scale, beginWithCurrentState: true)
    }
    
    public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if let statusNode = self.statusNode, !statusNode.isHidden {
            if let result = statusNode.reactionView(value: value) {
                return result
            }
        }
        if let result = self.contentFile?.dateAndStatusNode.reactionView(value: value) {
            return result
        }
        if let result = self.contentMedia?.dateAndStatusNode.reactionView(value: value) {
            return result
        }
        if let result = self.contentInstantVideo?.dateAndStatusNode.reactionView(value: value) {
            return result
        }
        return nil
    }
    
    public func playMediaWithSound() -> ((Double?) -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        return self.contentMedia?.playMediaWithSound()
    }
}
