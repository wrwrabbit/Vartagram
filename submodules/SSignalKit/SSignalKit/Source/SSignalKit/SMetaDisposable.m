#import "SMetaDisposable.h"

#import <os/lock.h>

@interface SMetaDisposable ()
{
    os_unfair_lock _lock;
    bool _disposed;
    id<SDisposable> _disposable;
}

@end

@implementation SMetaDisposable

- (instancetype)init {
    self = [super init];
    if (self != nil) {
    }
    return self;
}

- (void)dealloc {
    id<SDisposable> freeDisposable = nil;
    os_unfair_lock_lock(&_lock);
    if (_disposable) {
        freeDisposable = _disposable;
        _disposable = nil;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (freeDisposable) {
    }
}

- (void)setDisposable:(id<SDisposable>)disposable {
    id<SDisposable> previousDisposable = nil;
    bool disposeImmediately = false;
    
    os_unfair_lock_lock(&_lock);
    disposeImmediately = _disposed;
    if (!disposeImmediately) {
        previousDisposable = _disposable;
        _disposable = disposable;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (previousDisposable) {
        [previousDisposable dispose];
    }
    
    if (disposeImmediately) {
        [disposable dispose];
    }
}

- (void)dispose {
    id<SDisposable> disposable = nil;
    
    os_unfair_lock_lock(&_lock);
    if (!_disposed) {
        _disposed = true;
        disposable = _disposable;
        _disposable = nil;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (disposable) {
        [disposable dispose];
    }
}

@end
