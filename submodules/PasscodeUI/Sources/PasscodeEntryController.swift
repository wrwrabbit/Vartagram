import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import LocalAuth
import TelegramStringFormatting

public final class PasscodeEntryControllerPresentationArguments {
    let animated: Bool
    let fadeIn: Bool
    let lockIconInitialFrame: () -> CGRect
    let cancel: (() -> Void)?
    let modalPresentation: Bool
    
    public init(animated: Bool = true, fadeIn: Bool = false, lockIconInitialFrame: @escaping () -> CGRect = { return CGRect() }, cancel: (() -> Void)? = nil, modalPresentation: Bool = false) {
        self.animated = animated
        self.fadeIn = fadeIn
        self.lockIconInitialFrame = lockIconInitialFrame
        self.cancel = cancel
        self.modalPresentation = modalPresentation
    }
}

public enum PasscodeEntryControllerBiometricsMode {
    case none
    case enabled(Data?)
}

public final class PasscodeEntryController: ViewController {
    private var controllerNode: PasscodeEntryControllerNode {
        return self.displayNode as! PasscodeEntryControllerNode
    }
    
    private let applicationBindings: TelegramApplicationBindings
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private var energyUsageSettings: EnergyUsageSettings?
    private let appLockContext: AppLockContext
    private let presentationDataSignal: Signal<PresentationData, NoError>
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
        
    private let challengeData: PostboxAccessChallengeData
    private let biometrics: PasscodeEntryControllerBiometricsMode
    private let arguments: PasscodeEntryControllerPresentationArguments
    
    public var presentationCompleted: (() -> Void)?
    public var completed: (() -> Void)?
    
    private let biometricsDisposable = MetaDisposable()
    private var hasOngoingBiometricsRequest = false
    private var skipNextBiometricsRequest = false
    
    private var inBackground: Bool = false
    private var inBackgroundDisposable: Disposable?
    
    private var statusBarHost: StatusBarHost?
    private var previousStatusBarStyle: UIStatusBarStyle?
    
    private weak var sharedContext: SharedAccountContext?
    
    public init(applicationBindings: TelegramApplicationBindings, accountManager: AccountManager<TelegramAccountManagerTypes>, appLockContext: AppLockContext, presentationData: PresentationData, presentationDataSignal: Signal<PresentationData, NoError>, statusBarHost: StatusBarHost?, challengeData: PostboxAccessChallengeData, biometrics: PasscodeEntryControllerBiometricsMode, arguments: PasscodeEntryControllerPresentationArguments, sharedContext: SharedAccountContext?) {
        self.applicationBindings = applicationBindings
        self.accountManager = accountManager
        self.appLockContext = appLockContext
        self.presentationData = presentationData
        self.presentationDataSignal = presentationDataSignal
        self.challengeData = challengeData
        self.biometrics = biometrics
        self.arguments = arguments
        self.sharedContext = sharedContext
        
        self.statusBarHost = statusBarHost
        self.previousStatusBarStyle = statusBarHost?.statusBarStyle
        super.init(navigationBarPresentationData: nil)
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.statusBarHost?.setStatusBarStyle(.lightContent, animated: true)
        self.statusBarHost?.shouldChangeStatusBarStyle = { [weak self] style in
            if let strongSelf = self {
                strongSelf.previousStatusBarStyle = style
                return false
            }
            return true
        }
        
        self.presentationDataDisposable = (presentationDataSignal
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.inBackgroundDisposable = (applicationBindings.applicationInForeground
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.inBackground = !value
            if !value {
                strongSelf.skipNextBiometricsRequest = false
            }
        })
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.biometricsDisposable.dispose()
        self.inBackgroundDisposable?.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        let passcodeType: PasscodeEntryFieldType
        switch self.challengeData {
            case let .numericalPassword(value):
                passcodeType = value.count == 6 ? .digits6 : .digits4
            default:
                passcodeType = .alphanumeric
        }
        let biometricsType: LocalAuthBiometricAuthentication?
        if case let .enabled(data) = self.biometrics {
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                #if targetEnvironment(simulator)
                biometricsType = .touchId
                #else
                if data == LocalAuth.evaluatedPolicyDomainState || (data == nil && !self.applicationBindings.isMainApp) {
                    biometricsType = LocalAuth.biometricAuthentication
                } else {
                    biometricsType = nil
                }
                #endif
            } else {
                biometricsType = LocalAuth.biometricAuthentication
            }
        } else {
            biometricsType = nil
        }
        self.displayNode = PasscodeEntryControllerNode(accountManager: self.accountManager, presentationData: self.presentationData, theme: self.presentationData.theme, strings: self.presentationData.strings, wallpaper: self.presentationData.chatWallpaper, passcodeType: passcodeType, biometricsType: biometricsType, arguments: self.arguments, modalPresentation: self.arguments.modalPresentation)
        self.displayNodeDidLoad()
        
        self.controllerNode.checkPasscode = { [weak self] passcode in
            guard let sharedContext = self?.sharedContext else {
                return
            }
            
            let _ = (sharedContext.ptgSecretPasscodes
            |> take(1)
            |> deliverOnMainQueue).start(next: { ptgSecretPasscodes in
                guard let strongSelf = self else {
                    return
                }
                
                guard let passcodeAttemptAccounter = strongSelf.sharedContext?.passcodeAttemptAccounter else {
                    return
                }
                
                if let _ = passcodeAttemptAccounter.preAttempt() {
                    strongSelf.controllerNode.animateError()
                    strongSelf.controllerNode.updateAttemptWaitText(passcodeAttemptAccounter)
                    return
                }
                
                var succeed = false
                switch strongSelf.challengeData {
                case .none:
                    succeed = true
                case let .numericalPassword(code):
                    succeed = passcode == normalizeArabicNumeralString(code, type: .western)
                case let .plaintextPassword(code):
                    succeed = passcode == code
                }
                
                if !succeed {
                    // check secret codes only if passcode is not matched
                    // otherwise it may be used to brute-force secret codes by endlessly changing passcode and entering it on lock screen
                    // you can't call secretCodeAttemptAccounter.attemptMissed() to prevent it, because this will lock out secretCodeAttemptAccounter when only passcode is matched
                    if let secretCodeAttemptAccounter = strongSelf.sharedContext?.secretCodeAttemptAccounter {
                        if secretCodeAttemptAccounter.preAttempt() == nil {
                            if let sp = ptgSecretPasscodes.secretPasscodes.first(where: { $0.passcode == passcode }) {
                                strongSelf.sharedContext?.activateSecretPasscode(sp)
                                succeed = true
                            } else {
                                secretCodeAttemptAccounter.attemptMissed()
                            }
                        }
                    }
                }
                
                if succeed {
                    if let completed = strongSelf.completed {
                        completed()
                    } else {
                        strongSelf.appLockContext.unlock()
                    }
                    
                    let isMainApp = strongSelf.applicationBindings.isMainApp
                    let _ = updatePresentationPasscodeSettingsInteractively(accountManager: strongSelf.accountManager, { settings in
                        if isMainApp {
                            return settings.withUpdatedBiometricsDomainState(LocalAuth.evaluatedPolicyDomainState)
                        } else {
                            return settings.withUpdatedShareBiometricsDomainState(LocalAuth.evaluatedPolicyDomainState)
                        }
                    }).start()
                } else {
                    passcodeAttemptAccounter.attemptMissed()
                    strongSelf.controllerNode.animateError()
                }
            })
        }
        self.controllerNode.requestBiometrics = { [weak self] in
            if let strongSelf = self {
                strongSelf.requestBiometrics(force: true)
            }
        }
        
        #if TEST_BUILD
        self.controllerNode.debugAction = { [weak self] in
            if let strongSelf = self, let passcodeAttemptAccounter = strongSelf.sharedContext?.passcodeAttemptAccounter {
                passcodeAttemptAccounter.debugResetAllCounters()
                strongSelf.controllerNode.updateAttemptWaitText(passcodeAttemptAccounter)
            }
        }
        #endif
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.controllerNode.activateInput()
        if self.arguments.animated {
            self.controllerNode.animateIn(iconFrame: self.arguments.lockIconInitialFrame(), completion: { [weak self] in
                self?.presentationCompleted?()
            })
        } else {
            self.controllerNode.initialAppearance(fadeIn: self.arguments.fadeIn)
            self.presentationCompleted?()
        }
    }
    
    public func ensureInputFocused() {
        self.controllerNode.activateInput()
    }
    
    public func requestBiometrics(force: Bool = false) {
        guard case let .enabled(data) = self.biometrics, let _ = LocalAuth.biometricAuthentication else {
            return
        }
        
        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            if data == nil && self.applicationBindings.isMainApp {
                return
            }
        }
        
        if self.skipNextBiometricsRequest {
            self.skipNextBiometricsRequest = false
            if !force {
                return
            }
        }
        
        if self.hasOngoingBiometricsRequest {
            if !force {
                return
            }
        }
        
        self.hasOngoingBiometricsRequest = true
        
        self.biometricsDisposable.set((LocalAuth.auth(reason: self.presentationData.strings.EnterPasscode_TouchId) |> deliverOnMainQueue).start(next: { [weak self] result, evaluatedPolicyDomainState in
            guard let strongSelf = self else {
                return
            }
            
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                if case let .enabled(storedDomainState) = strongSelf.biometrics, evaluatedPolicyDomainState != nil {
                    if !strongSelf.applicationBindings.isMainApp && storedDomainState == nil {
                        let _ = updatePresentationPasscodeSettingsInteractively(accountManager: strongSelf.accountManager, { settings in
                            return settings.withUpdatedShareBiometricsDomainState(LocalAuth.evaluatedPolicyDomainState)
                        }).start()
                    } else if storedDomainState != evaluatedPolicyDomainState {
                        strongSelf.controllerNode.hideBiometrics()
                        return
                    }
                }
            }
            
            if result {
                strongSelf.controllerNode.animateSuccess()
                
                if let completed = strongSelf.completed {
                    Queue.mainQueue().after(1.5) {
                        completed()
                    }
                    strongSelf.hasOngoingBiometricsRequest = false
                } else {
                    strongSelf.appLockContext.unlock()
                    // PTG: currently biometric unlock preserves last unlock status
                    strongSelf.hasOngoingBiometricsRequest = false
                }
            } else {
                strongSelf.hasOngoingBiometricsRequest = false
                strongSelf.skipNextBiometricsRequest = true
            }
        }))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    public override func dismiss(completion: (() -> Void)? = nil) {
        self.dismiss(animated: true, completion: completion)
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.statusBarHost?.shouldChangeStatusBarStyle = nil
        if let statusBarHost = self.statusBarHost, let previousStatusBarStyle = self.previousStatusBarStyle {
            statusBarHost.setStatusBarStyle(previousStatusBarStyle, animated: flag)
        }
        self.view.endEditing(true)
        if flag {
            self.controllerNode.animateOut { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.view.endEditing(true)
                strongSelf.presentingViewController?.dismiss(animated: false, completion: completion)
            }
        } else {
            self.presentingViewController?.dismiss(animated: false, completion: completion)
        }
    }
}
