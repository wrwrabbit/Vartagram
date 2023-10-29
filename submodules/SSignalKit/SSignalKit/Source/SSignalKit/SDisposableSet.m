#import "SDisposableSet.h"

#import "SSignal.h"

#import <os/lock.h>

@interface SDisposableSet ()
{
    os_unfair_lock _lock;
    bool _disposed;
    NSMutableArray<id<SDisposable>> *_disposables;
}

@end

@implementation SDisposableSet

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _disposables = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    NSArray<id<SDisposable>> *disposables = nil;
    os_unfair_lock_lock(&_lock);
    disposables = _disposables;
    _disposables = nil;
    os_unfair_lock_unlock(&_lock);
    
    if (disposables) {
    }
}

- (void)add:(id<SDisposable>)disposable {
    bool disposeImmediately = false;
    
    os_unfair_lock_lock(&_lock);
    if (_disposed) {
        disposeImmediately = true;
    } else {
        [_disposables addObject:disposable];
    }
    os_unfair_lock_unlock(&_lock);
    
    if (disposeImmediately) {
        [disposable dispose];
    }
}

- (void)remove:(id<SDisposable>)disposable {
    os_unfair_lock_lock(&_lock);
    for (NSInteger i = 0; i < _disposables.count; i++) {
        if (_disposables[i] == disposable) {
            [_disposables removeObjectAtIndex:i];
            break;
        }
    }
    os_unfair_lock_unlock(&_lock);
}

- (void)dispose {
    NSArray<id<SDisposable>> *disposables = nil;
    os_unfair_lock_lock(&_lock);
    if (!_disposed) {
        _disposed = true;
        disposables = _disposables;
        _disposables = nil;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (disposables) {
        for (id<SDisposable> disposable in disposables) {
            [disposable dispose];
        }
    }
}

@end
