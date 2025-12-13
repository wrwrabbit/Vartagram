#import "NSBag.h"

@interface NSBag ()
{
    NSInteger _nextKey;
    NSMutableArray *_items;
    NSMutableArray *_itemKeys;
}

@end

@implementation NSBag

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _items = [[NSMutableArray alloc] init];
        _itemKeys = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSInteger)addItem:(id)item
{
    if (item == nil)
        return -1;
    
    NSInteger key = _nextKey;
    [_items addObject:item];
    [_itemKeys addObject:@(key)];
    _nextKey++;
    
    return key;
}

- (void)enumerateItems:(void (^)(id))block
{
    if (block)
    {
        // A workaround to prevent modifications while iterating
        NSMutableArray *itemsCopy = [_items mutableCopy];
        for (id item in itemsCopy)
        {
            block(item);
        }
    }
}

- (void)removeItem:(NSInteger)key
{
    NSUInteger index = 0;
    for (NSNumber *itemKey in _itemKeys)
    {
        if ([itemKey integerValue] == key)
        {
            [_items removeObjectAtIndex:index];
            [_itemKeys removeObjectAtIndex:index];
            break;
        }
        index++;
    }
}

@end
