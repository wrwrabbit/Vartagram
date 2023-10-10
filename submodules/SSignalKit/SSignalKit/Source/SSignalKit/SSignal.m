#import "SSignal.h"

#import "SBlockDisposable.h"

#import <os/lock.h>
#import <pthread/pthread.h>

@interface SSubscriberDisposable : NSObject <SDisposable>
{
    __weak SSubscriber *_subscriber;
    id<SDisposable> _disposable;
    os_unfair_lock _lock;
}

@end

@implementation SSubscriberDisposable

- (instancetype)initWithSubscriber:(SSubscriber *)subscriber disposable:(id<SDisposable>)disposable {
    self = [super init];
    if (self != nil) {
        _subscriber = subscriber;
        _disposable = disposable;
    }
    return self;
}

- (void)dealloc {
}

- (void)dispose {
    id<SDisposable> disposeItem = nil;
    
    os_unfair_lock_lock(&_lock);
    disposeItem = _disposable;
    _disposable = nil;
    os_unfair_lock_unlock(&_lock);
    
    [_subscriber _markTerminatedWithoutDisposal];
    [disposeItem dispose];
}

@end

@interface SStrictDisposable : NSObject<SDisposable> {
    id<SDisposable> _disposable;
#if DEBUG
    const char *_file;
    int _line;
    
    pthread_mutex_t _lock;
    bool _isDisposed;
#endif
}

- (instancetype)initWithDisposable:(id<SDisposable>)disposable file:(const char *)file line:(int)line;
- (void)dispose;

@end

@implementation SStrictDisposable

- (instancetype)initWithDisposable:(id<SDisposable>)disposable file:(const char *)file line:(int)line {
    self = [super init];
    if (self != nil) {
        _disposable = disposable;
#if DEBUG
        _file = file;
        _line = line;
        
        pthread_mutex_init(&_lock, nil);
#endif
    }
    return self;
}

- (void)dealloc {
#if DEBUG
    pthread_mutex_lock(&_lock);
    if (!_isDisposed) {
        NSLog(@"Leaked disposable from %s:%d", _file, _line);
        assert(false);
    }
    pthread_mutex_unlock(&_lock);
    
    pthread_mutex_destroy(&_lock);
#endif
}

- (void)dispose {
#if DEBUG
    pthread_mutex_lock(&_lock);
    _isDisposed = true;
    pthread_mutex_unlock(&_lock);
#endif
    
    [_disposable dispose];
}

@end

@interface SSignal ()
{
}

@end

@implementation SSignal

- (instancetype)initWithGenerator:(id<SDisposable> (^)(SSubscriber *))generator {
    self = [super init];
    if (self != nil) {
        _generator = [generator copy];
    }
    return self;
}

- (id<SDisposable>)startWithNext:(void (^)(id next))next error:(void (^)(id error))error completed:(void (^)())completed {
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:error completed:completed];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[SSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

- (id<SDisposable>)startStrictWithNext:(void (^)(id next))next error:(void (^)(id error))error completed:(void (^)())completed file:(const char * _Nonnull)file line:(int)line {
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:error completed:completed];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[SStrictDisposable alloc] initWithDisposable:[[SSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable] file:file line:line];
}

- (id<SDisposable>)startWithNext:(void (^)(id next))next {
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:nil completed:nil];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[SSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

- (id<SDisposable>)startStrictWithNext:(void (^)(id next))next file:(const char * _Nonnull)file line:(int)line {
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:nil completed:nil];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[SStrictDisposable alloc] initWithDisposable:[[SSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable] file:file line:line];
}

- (id<SDisposable>)startWithNext:(void (^)(id next))next completed:(void (^)())completed {
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:nil completed:completed];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[SSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

- (id<SDisposable>)startStrictWithNext:(void (^)(id next))next completed:(void (^)())completed file:(const char * _Nonnull)file line:(int)line {
    SSubscriber *subscriber = [[SSubscriber alloc] initWithNext:next error:nil completed:completed];
    id<SDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[SStrictDisposable alloc] initWithDisposable:[[SSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable] file:file line:line];
}

@end
