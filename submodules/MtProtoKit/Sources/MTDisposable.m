#import <MtProtoKit/MTDisposable.h>

#import <os/lock.h>
#import <objc/runtime.h>

@interface MTBlockDisposable () {
    void (^_action)();
    os_unfair_lock _lock;
}

@end

@implementation MTBlockDisposable

- (instancetype)initWithBlock:(void (^)())block
{
    self = [super init];
    if (self != nil)
    {
        _action = [block copy];
    }
    return self;
}

- (void)dealloc {
    void (^freeAction)() = nil;
    os_unfair_lock_lock(&_lock);
    freeAction = _action;
    _action = nil;
    os_unfair_lock_unlock(&_lock);
    
    if (freeAction) {
    }
}

- (void)dispose {
    void (^disposeAction)() = nil;
    
    os_unfair_lock_lock(&_lock);
    disposeAction = _action;
    _action = nil;
    os_unfair_lock_unlock(&_lock);
    
    if (disposeAction) {
        disposeAction();
    }
}

@end

@interface MTMetaDisposable ()
{
    os_unfair_lock _lock;
    bool _disposed;
    id<MTDisposable> _disposable;
}

@end

@implementation MTMetaDisposable

- (instancetype)init {
    self = [super init];
    if (self != nil) {
    }
    return self;
}

- (void)dealloc {
    id<MTDisposable> freeDisposable = nil;
    os_unfair_lock_lock(&_lock);
    if (_disposable) {
        freeDisposable = _disposable;
        _disposable = nil;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (freeDisposable) {
    }
}

- (void)setDisposable:(id<MTDisposable>)disposable {
    id<MTDisposable> previousDisposable = nil;
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
    id<MTDisposable> disposable = nil;
    
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

@interface MTDisposableSet ()
{
    os_unfair_lock _lock;
    bool _disposed;
    NSMutableArray<id<MTDisposable>> *_disposables;
}

@end

@implementation MTDisposableSet

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _disposables = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    NSArray<id<MTDisposable>> *disposables = nil;
    os_unfair_lock_lock(&_lock);
    disposables = _disposables;
    _disposables = nil;
    os_unfair_lock_unlock(&_lock);
    
    if (disposables) {
    }
}

- (void)add:(id<MTDisposable>)disposable {
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

- (void)remove:(id<MTDisposable>)disposable {
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
    NSArray<id<MTDisposable>> *disposables = nil;
    os_unfair_lock_lock(&_lock);
    if (!_disposed) {
        _disposed = true;
        disposables = _disposables;
        _disposables = nil;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (disposables) {
        for (id<MTDisposable> disposable in disposables) {
            [disposable dispose];
        }
    }
}

@end
