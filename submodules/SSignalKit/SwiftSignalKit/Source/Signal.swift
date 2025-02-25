import Foundation

let doNothing: () -> Void = { }

public enum NoValue {
}

public enum NoError {
}

public func identity<A>(a: A) -> A {
    return a
}

precedencegroup PipeRight {
    associativity: left
    higherThan: DefaultPrecedence
}

infix operator |> : PipeRight

public func |> <T, U>(value: T, function: ((T) -> U)) -> U {
    return function(value)
}

private final class SubscriberDisposable<T, E>: Disposable, CustomStringConvertible {
    private weak var subscriber: Subscriber<T, E>?
    
    private let lock = createOSUnfairLock()
    private var disposable: Disposable?
    
    init(subscriber: Subscriber<T, E>, disposable: Disposable) {
        self.subscriber = subscriber
        self.disposable = disposable
    }
    
    deinit {
        var disposable: Disposable?
        
        self.lock.lock()
        disposable = self.disposable
        self.disposable = nil
        self.lock.unlock()
        
        withExtendedLifetime(disposable, {})
    }
    
    func dispose() {
        var disposable: Disposable?
        
        self.lock.lock()
        disposable = self.disposable
        self.disposable = nil
        self.lock.unlock()
        
        self.subscriber?.markTerminatedWithoutDisposal()
        disposable?.dispose()
    }
    
    public var description: String {
        return "SubscriberDisposable { disposable: \(self.disposable == nil ? "nil" : "hasValue") }"
    }
}

public final class Signal<T, E> {
    private let generator: (Subscriber<T, E>) -> Disposable
    
    public init(_ generator: @escaping(Subscriber<T, E>) -> Disposable) {
        self.generator = generator
    }
    
    public func start(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) -> Disposable {
        let subscriber = Subscriber<T, E>(next: next, error: error, completed: completed)
        let disposable = self.generator(subscriber)
        subscriber.assignDisposable(disposable)
        return SubscriberDisposable(subscriber: subscriber, disposable: disposable)
    }
    
    public func startStandalone(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) -> Disposable {
        let subscriber = Subscriber<T, E>(next: next, error: error, completed: completed)
        let disposable = self.generator(subscriber)
        subscriber.assignDisposable(disposable)
        return SubscriberDisposable(subscriber: subscriber, disposable: disposable)
    }
    
    public func startStrict(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil, file: String = #file, line: Int = #line) -> Disposable {
        let subscriber = Subscriber<T, E>(next: next, error: error, completed: completed)
        let disposable = self.generator(subscriber)
        subscriber.assignDisposable(disposable)
        return SubscriberDisposable(subscriber: subscriber, disposable: disposable).strict(file: file, line: line)
    }
    
    public static func single(_ value: T) -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putNext(value)
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    public static func complete() -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putCompletion()
            
            return EmptyDisposable
        }
    }
    
    public static func fail(_ error: E) -> Signal<T, E> {
        return Signal<T, E> { subscriber in
            subscriber.putError(error)
            
            return EmptyDisposable
        }
    }
    
    public static func never() -> Signal<T, E> {
        return Signal<T, E> { _ in
            return EmptyDisposable
        }
    }
}
