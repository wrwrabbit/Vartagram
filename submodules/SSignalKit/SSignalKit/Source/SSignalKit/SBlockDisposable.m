#import "SBlockDisposable.h"

#import <os/lock.h>
#import <objc/runtime.h>
#import <os/lock.h>

@interface SBlockDisposable () {
    void (^_action)();
    os_unfair_lock _lock;
}

@end

@implementation SBlockDisposable

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
