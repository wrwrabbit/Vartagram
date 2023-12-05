import Foundation

final class Cache<Key: Hashable, Value> {
    final class WrappedKey: NSObject {
        let key: Key
        
        init(_ key: Key) {
            self.key = key
        }
        
        override var hash: Int {
            return self.key.hashValue
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? WrappedKey else {
                return false
            }
            return self.key == other.key
        }
    }
    
    final class WrappedValue {
        let value: Value
        
        init(_ value: Value) {
            self.value = value
        }
    }
    
    private let wrapped = NSCache<WrappedKey, WrappedValue>()
    
    var countLimit: Int {
        get {
            return self.wrapped.countLimit
        }
        set {
            self.wrapped.countLimit = newValue
        }
    }
    
    func set(_ value: Value, forKey key: Key) {
        self.wrapped.setObject(WrappedValue(value), forKey: WrappedKey(key))
    }
    
    func value(forKey key: Key) -> Value? {
        return self.wrapped.object(forKey: WrappedKey(key))?.value
    }
}
