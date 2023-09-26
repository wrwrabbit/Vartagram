import Foundation

public func delay<T, E>(_ timeout: Double, queue: Queue) -> (_ signal: Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            let timerDisposable = MetaDisposable()
            let runDisposable = MetaDisposable()
            queue.async {
                let timer = Timer(timeout: timeout, repeat: false, completion: {
                    runDisposable.set(signal.start(next: { next in
                        subscriber.putNext(next)
                    }, error: { error in
                        subscriber.putError(error)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }, queue: queue)
                
                timerDisposable.set(ActionDisposable {
                    queue.async {
                        timer.invalidate()
                    }
                })
                
                timer.start()
            }
            return ActionDisposable {
                timerDisposable.dispose()
                runDisposable.dispose()
            }
        }
    }
}

public func suspendAwareDelay<T, E>(_ timeout: Double, granularity: Double = 4.0, queue: Queue) -> (_ signal: Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            let timerDisposable = MetaDisposable()
            let runDisposable = MetaDisposable()
            
            queue.async {
                let beginTimestamp = CFAbsoluteTimeGetCurrent()
                
                let startFinalTimer: () -> Void = {
                    let finalTimeout = beginTimestamp + timeout - CFAbsoluteTimeGetCurrent()
                    // when app restored from suspended state, many timers may trigger immediately
                    // since we may need to quickly hide some secrets, delay these tasks for 0.5 seconds
                    let timer = Timer(timeout: max(0.5, finalTimeout), repeat: false, completion: {
                        runDisposable.set(signal.start(next: { next in
                            subscriber.putNext(next)
                        }, error: { error in
                            subscriber.putError(error)
                        }, completed: {
                            subscriber.putCompletion()
                        }))
                    }, queue: queue)
                    timerDisposable.set(ActionDisposable {
                        queue.async {
                            timer.invalidate()
                        }
                    })
                    timer.start()
                }
                
                if timeout <= granularity * 1.1 {
                    startFinalTimer()
                } else {
                    var invalidateImpl: (() -> Void)?
                    let timer = Timer(timeout: granularity, repeat: true, completion: {
                        let currentTimestamp = CFAbsoluteTimeGetCurrent()
                        if beginTimestamp + timeout - granularity * 1.1 <= currentTimestamp {
                            invalidateImpl?()
                            startFinalTimer()
                        }
                    }, queue: queue)
                    
                    invalidateImpl = { [weak timer] in
                        queue.async {
                            timer?.invalidate()
                        }
                    }
                    
                    timerDisposable.set(ActionDisposable {
                        queue.async {
                            timer.invalidate()
                        }
                    })
                    
                    timer.start()
                }
            }
            return ActionDisposable {
                timerDisposable.dispose()
                runDisposable.dispose()
            }
        }
    }
}

public func timeout<T, E>(_ timeout: Double, queue: Queue, alternate: Signal<T, E>) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            let disposable = MetaDisposable()
            let timer = Timer(timeout: timeout, repeat: false, completion: {
                disposable.set(alternate.start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }, queue: queue)
            
            disposable.set(signal.start(next: { next in
                timer.invalidate()
                subscriber.putNext(next)
            }, error: { error in
                timer.invalidate()
                subscriber.putError(error)
            }, completed: {
                timer.invalidate()
                subscriber.putCompletion()
            }))
            timer.start()
            
            let disposableSet = DisposableSet()
            disposableSet.add(ActionDisposable {
                timer.invalidate()
            })
            disposableSet.add(disposable)
            
            return disposableSet
        }
    }
}
