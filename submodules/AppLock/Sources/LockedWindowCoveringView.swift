import TelegramCore
import PasscodeUI
import GradientBackground

import Foundation
import Display
import TelegramPresentationData
import AsyncDisplayKit

final class LockedWindowCoveringView: WindowCoveringView {
    private let theme: PresentationTheme
    private let wallpaper: TelegramWallpaper
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private var contentView: UIView?
    
    init(theme: PresentationTheme, wallpaper: TelegramWallpaper, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        self.theme = theme
        self.wallpaper = wallpaper
        self.accountManager = accountManager
        
        super.init(frame: CGRect())
        
        self.backgroundColor =  theme.chatList.backgroundColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func duplicate() -> LockedWindowCoveringView {
        let result = LockedWindowCoveringView(theme: self.theme, wallpaper: self.wallpaper, accountManager: self.accountManager)
        result.contentView = self.contentView?.snapshotView(afterScreenUpdates: true)
        if let contentView = result.contentView {
            result.addSubview(contentView)
        }
        return result
    }
    
    override func updateLayout(_ size: CGSize) {
        if let contentView = self.contentView, contentView.frame.size == size {
            return
        }

        let background = PasscodeEntryControllerNode.background(size: size, wallpaper: self.wallpaper, theme: self.theme, accountManager: self.accountManager)
        if let backgroundImage = background.backgroundImage {
            let imageView = UIImageView(image: backgroundImage)
            imageView.frame = CGRect(origin: CGPoint(), size: size)
            self.addSubview(imageView)
            self.contentView?.removeFromSuperview()
            self.contentView = imageView
        } else if let customBackgroundNode = background.makeBackgroundNode() {
            customBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
            (customBackgroundNode as? GradientBackgroundNode)?.updateLayout(size: size, transition: .immediate, extendAnimation: false, backwards: false, completion: {})
            let backgroundDimNode = ASDisplayNode()
            if let background = background as? CustomPasscodeBackground, background.inverted {
                backgroundDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.75)
            } else {
                backgroundDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.15)
            }
            backgroundDimNode.frame = customBackgroundNode.frame
            customBackgroundNode.addSubnode(backgroundDimNode)
            self.addSubview(customBackgroundNode.view)
            self.contentView?.removeFromSuperview()
            self.contentView = customBackgroundNode.view
        }
    }
}
