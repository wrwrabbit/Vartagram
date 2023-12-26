import Foundation
import TelegramPresentationData

public func passcodeAttemptWaitString(strings: PresentationStrings, waitTime: Int32) -> String {
    let timeString = timeIntervalString(strings: strings, value: waitTime, usage: .afterTime)
    return strings.PasscodeAttempts_TryAgainIn(timeString).string.replacingOccurrences(of: #"\.\.$"#, with: ".", options: .regularExpression)
}

public func passcodeAttemptShortWaitString(strings: PresentationStrings, waitTime: Int32) -> String {
    let timeString = timeIntervalString(strings: strings, value: waitTime, usage: .afterTime)
    return strings.PasscodeAttempts_ShortTryAgainIn(timeString).string
}
