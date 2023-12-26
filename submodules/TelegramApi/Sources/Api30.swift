public extension Api.phone {
    enum GroupParticipants: TypeConstructorDescription {
        case groupParticipants(count: Int32, participants: [Api.GroupCallParticipant], nextOffset: String, chats: [Api.Chat], users: [Api.User], version: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupParticipants(let count, let participants, let nextOffset, let chats, let users, let version):
                    if boxed {
                        buffer.appendInt32(-193506890)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
                        item.serialize(buffer, true)
                    }
                    serializeString(nextOffset, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupParticipants(let count, let participants, let nextOffset, let chats, let users, let version):
                return ("groupParticipants", [("count", count as Any), ("participants", participants as Any), ("nextOffset", nextOffset as Any), ("chats", chats as Any), ("users", users as Any), ("version", version as Any)])
    }
    }
    
        public static func parse_groupParticipants(_ reader: BufferReader) -> GroupParticipants? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.GroupCallParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipant.self)
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.phone.GroupParticipants.groupParticipants(count: _1!, participants: _2!, nextOffset: _3!, chats: _4!, users: _5!, version: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum JoinAsPeers: TypeConstructorDescription {
        case joinAsPeers(peers: [Api.Peer], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .joinAsPeers(let peers, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1343921601)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .joinAsPeers(let peers, let chats, let users):
                return ("joinAsPeers", [("peers", peers as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_joinAsPeers(_ reader: BufferReader) -> JoinAsPeers? {
            var _1: [Api.Peer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.phone.JoinAsPeers.joinAsPeers(peers: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum PhoneCall: TypeConstructorDescription {
        case phoneCall(phoneCall: Api.PhoneCall, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneCall(let phoneCall, let users):
                    if boxed {
                        buffer.appendInt32(-326966976)
                    }
                    phoneCall.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .phoneCall(let phoneCall, let users):
                return ("phoneCall", [("phoneCall", phoneCall as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_phoneCall(_ reader: BufferReader) -> PhoneCall? {
            var _1: Api.PhoneCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PhoneCall
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.phone.PhoneCall.phoneCall(phoneCall: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.photos {
    enum Photo: TypeConstructorDescription {
        case photo(photo: Api.Photo, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photo(let photo, let users):
                    if boxed {
                        buffer.appendInt32(539045032)
                    }
                    photo.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .photo(let photo, let users):
                return ("photo", [("photo", photo as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_photo(_ reader: BufferReader) -> Photo? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.photos.Photo.photo(photo: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.photos {
    enum Photos: TypeConstructorDescription {
        case photos(photos: [Api.Photo], users: [Api.User])
        case photosSlice(count: Int32, photos: [Api.Photo], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photos(let photos, let users):
                    if boxed {
                        buffer.appendInt32(-1916114267)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(photos.count))
                    for item in photos {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .photosSlice(let count, let photos, let users):
                    if boxed {
                        buffer.appendInt32(352657236)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(photos.count))
                    for item in photos {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .photos(let photos, let users):
                return ("photos", [("photos", photos as Any), ("users", users as Any)])
                case .photosSlice(let count, let photos, let users):
                return ("photosSlice", [("count", count as Any), ("photos", photos as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_photos(_ reader: BufferReader) -> Photos? {
            var _1: [Api.Photo]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.photos.Photos.photos(photos: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_photosSlice(_ reader: BufferReader) -> Photos? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Photo]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.photos.Photos.photosSlice(count: _1!, photos: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.premium {
    enum BoostsList: TypeConstructorDescription {
        case boostsList(flags: Int32, count: Int32, boosts: [Api.Boost], nextOffset: String?, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .boostsList(let flags, let count, let boosts, let nextOffset, let users):
                    if boxed {
                        buffer.appendInt32(-2030542532)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(boosts.count))
                    for item in boosts {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .boostsList(let flags, let count, let boosts, let nextOffset, let users):
                return ("boostsList", [("flags", flags as Any), ("count", count as Any), ("boosts", boosts as Any), ("nextOffset", nextOffset as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_boostsList(_ reader: BufferReader) -> BoostsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.Boost]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Boost.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.premium.BoostsList.boostsList(flags: _1!, count: _2!, boosts: _3!, nextOffset: _4, users: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.premium {
    enum BoostsStatus: TypeConstructorDescription {
        case boostsStatus(flags: Int32, level: Int32, currentLevelBoosts: Int32, boosts: Int32, giftBoosts: Int32?, nextLevelBoosts: Int32?, premiumAudience: Api.StatsPercentValue?, boostUrl: String, prepaidGiveaways: [Api.PrepaidGiveaway]?, myBoostSlots: [Int32]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .boostsStatus(let flags, let level, let currentLevelBoosts, let boosts, let giftBoosts, let nextLevelBoosts, let premiumAudience, let boostUrl, let prepaidGiveaways, let myBoostSlots):
                    if boxed {
                        buffer.appendInt32(1230586490)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(level, buffer: buffer, boxed: false)
                    serializeInt32(currentLevelBoosts, buffer: buffer, boxed: false)
                    serializeInt32(boosts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(giftBoosts!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(nextLevelBoosts!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {premiumAudience!.serialize(buffer, true)}
                    serializeString(boostUrl, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prepaidGiveaways!.count))
                    for item in prepaidGiveaways! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(myBoostSlots!.count))
                    for item in myBoostSlots! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .boostsStatus(let flags, let level, let currentLevelBoosts, let boosts, let giftBoosts, let nextLevelBoosts, let premiumAudience, let boostUrl, let prepaidGiveaways, let myBoostSlots):
                return ("boostsStatus", [("flags", flags as Any), ("level", level as Any), ("currentLevelBoosts", currentLevelBoosts as Any), ("boosts", boosts as Any), ("giftBoosts", giftBoosts as Any), ("nextLevelBoosts", nextLevelBoosts as Any), ("premiumAudience", premiumAudience as Any), ("boostUrl", boostUrl as Any), ("prepaidGiveaways", prepaidGiveaways as Any), ("myBoostSlots", myBoostSlots as Any)])
    }
    }
    
        public static func parse_boostsStatus(_ reader: BufferReader) -> BoostsStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt32() }
            var _7: Api.StatsPercentValue?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StatsPercentValue
            } }
            var _8: String?
            _8 = parseString(reader)
            var _9: [Api.PrepaidGiveaway]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrepaidGiveaway.self)
            } }
            var _10: [Int32]?
            if Int(_1!) & Int(1 << 2) != 0 {if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 3) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 2) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.premium.BoostsStatus.boostsStatus(flags: _1!, level: _2!, currentLevelBoosts: _3!, boosts: _4!, giftBoosts: _5, nextLevelBoosts: _6, premiumAudience: _7, boostUrl: _8!, prepaidGiveaways: _9, myBoostSlots: _10)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.premium {
    enum MyBoosts: TypeConstructorDescription {
        case myBoosts(myBoosts: [Api.MyBoost], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .myBoosts(let myBoosts, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1696454430)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(myBoosts.count))
                    for item in myBoosts {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .myBoosts(let myBoosts, let chats, let users):
                return ("myBoosts", [("myBoosts", myBoosts as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_myBoosts(_ reader: BufferReader) -> MyBoosts? {
            var _1: [Api.MyBoost]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MyBoost.self)
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.premium.MyBoosts.myBoosts(myBoosts: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum BroadcastStats: TypeConstructorDescription {
        case broadcastStats(period: Api.StatsDateRangeDays, followers: Api.StatsAbsValueAndPrev, viewsPerPost: Api.StatsAbsValueAndPrev, sharesPerPost: Api.StatsAbsValueAndPrev, reactionsPerPost: Api.StatsAbsValueAndPrev, viewsPerStory: Api.StatsAbsValueAndPrev, sharesPerStory: Api.StatsAbsValueAndPrev, reactionsPerStory: Api.StatsAbsValueAndPrev, enabledNotifications: Api.StatsPercentValue, growthGraph: Api.StatsGraph, followersGraph: Api.StatsGraph, muteGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, interactionsGraph: Api.StatsGraph, ivInteractionsGraph: Api.StatsGraph, viewsBySourceGraph: Api.StatsGraph, newFollowersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph, storyInteractionsGraph: Api.StatsGraph, storyReactionsByEmotionGraph: Api.StatsGraph, recentPostsInteractions: [Api.PostInteractionCounters])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .broadcastStats(let period, let followers, let viewsPerPost, let sharesPerPost, let reactionsPerPost, let viewsPerStory, let sharesPerStory, let reactionsPerStory, let enabledNotifications, let growthGraph, let followersGraph, let muteGraph, let topHoursGraph, let interactionsGraph, let ivInteractionsGraph, let viewsBySourceGraph, let newFollowersBySourceGraph, let languagesGraph, let reactionsByEmotionGraph, let storyInteractionsGraph, let storyReactionsByEmotionGraph, let recentPostsInteractions):
                    if boxed {
                        buffer.appendInt32(963421692)
                    }
                    period.serialize(buffer, true)
                    followers.serialize(buffer, true)
                    viewsPerPost.serialize(buffer, true)
                    sharesPerPost.serialize(buffer, true)
                    reactionsPerPost.serialize(buffer, true)
                    viewsPerStory.serialize(buffer, true)
                    sharesPerStory.serialize(buffer, true)
                    reactionsPerStory.serialize(buffer, true)
                    enabledNotifications.serialize(buffer, true)
                    growthGraph.serialize(buffer, true)
                    followersGraph.serialize(buffer, true)
                    muteGraph.serialize(buffer, true)
                    topHoursGraph.serialize(buffer, true)
                    interactionsGraph.serialize(buffer, true)
                    ivInteractionsGraph.serialize(buffer, true)
                    viewsBySourceGraph.serialize(buffer, true)
                    newFollowersBySourceGraph.serialize(buffer, true)
                    languagesGraph.serialize(buffer, true)
                    reactionsByEmotionGraph.serialize(buffer, true)
                    storyInteractionsGraph.serialize(buffer, true)
                    storyReactionsByEmotionGraph.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentPostsInteractions.count))
                    for item in recentPostsInteractions {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .broadcastStats(let period, let followers, let viewsPerPost, let sharesPerPost, let reactionsPerPost, let viewsPerStory, let sharesPerStory, let reactionsPerStory, let enabledNotifications, let growthGraph, let followersGraph, let muteGraph, let topHoursGraph, let interactionsGraph, let ivInteractionsGraph, let viewsBySourceGraph, let newFollowersBySourceGraph, let languagesGraph, let reactionsByEmotionGraph, let storyInteractionsGraph, let storyReactionsByEmotionGraph, let recentPostsInteractions):
                return ("broadcastStats", [("period", period as Any), ("followers", followers as Any), ("viewsPerPost", viewsPerPost as Any), ("sharesPerPost", sharesPerPost as Any), ("reactionsPerPost", reactionsPerPost as Any), ("viewsPerStory", viewsPerStory as Any), ("sharesPerStory", sharesPerStory as Any), ("reactionsPerStory", reactionsPerStory as Any), ("enabledNotifications", enabledNotifications as Any), ("growthGraph", growthGraph as Any), ("followersGraph", followersGraph as Any), ("muteGraph", muteGraph as Any), ("topHoursGraph", topHoursGraph as Any), ("interactionsGraph", interactionsGraph as Any), ("ivInteractionsGraph", ivInteractionsGraph as Any), ("viewsBySourceGraph", viewsBySourceGraph as Any), ("newFollowersBySourceGraph", newFollowersBySourceGraph as Any), ("languagesGraph", languagesGraph as Any), ("reactionsByEmotionGraph", reactionsByEmotionGraph as Any), ("storyInteractionsGraph", storyInteractionsGraph as Any), ("storyReactionsByEmotionGraph", storyReactionsByEmotionGraph as Any), ("recentPostsInteractions", recentPostsInteractions as Any)])
    }
    }
    
        public static func parse_broadcastStats(_ reader: BufferReader) -> BroadcastStats? {
            var _1: Api.StatsDateRangeDays?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsDateRangeDays
            }
            var _2: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _3: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _4: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _5: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _6: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _7: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _8: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _9: Api.StatsPercentValue?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.StatsPercentValue
            }
            var _10: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _11: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _12: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _13: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _14: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _15: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _16: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _16 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _17: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _17 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _18: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _18 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _19: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _19 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _20: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _20 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _21: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _21 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _22: [Api.PostInteractionCounters]?
            if let _ = reader.readInt32() {
                _22 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PostInteractionCounters.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = _16 != nil
            let _c17 = _17 != nil
            let _c18 = _18 != nil
            let _c19 = _19 != nil
            let _c20 = _20 != nil
            let _c21 = _21 != nil
            let _c22 = _22 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 {
                return Api.stats.BroadcastStats.broadcastStats(period: _1!, followers: _2!, viewsPerPost: _3!, sharesPerPost: _4!, reactionsPerPost: _5!, viewsPerStory: _6!, sharesPerStory: _7!, reactionsPerStory: _8!, enabledNotifications: _9!, growthGraph: _10!, followersGraph: _11!, muteGraph: _12!, topHoursGraph: _13!, interactionsGraph: _14!, ivInteractionsGraph: _15!, viewsBySourceGraph: _16!, newFollowersBySourceGraph: _17!, languagesGraph: _18!, reactionsByEmotionGraph: _19!, storyInteractionsGraph: _20!, storyReactionsByEmotionGraph: _21!, recentPostsInteractions: _22!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum MegagroupStats: TypeConstructorDescription {
        case megagroupStats(period: Api.StatsDateRangeDays, members: Api.StatsAbsValueAndPrev, messages: Api.StatsAbsValueAndPrev, viewers: Api.StatsAbsValueAndPrev, posters: Api.StatsAbsValueAndPrev, growthGraph: Api.StatsGraph, membersGraph: Api.StatsGraph, newMembersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, messagesGraph: Api.StatsGraph, actionsGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, weekdaysGraph: Api.StatsGraph, topPosters: [Api.StatsGroupTopPoster], topAdmins: [Api.StatsGroupTopAdmin], topInviters: [Api.StatsGroupTopInviter], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .megagroupStats(let period, let members, let messages, let viewers, let posters, let growthGraph, let membersGraph, let newMembersBySourceGraph, let languagesGraph, let messagesGraph, let actionsGraph, let topHoursGraph, let weekdaysGraph, let topPosters, let topAdmins, let topInviters, let users):
                    if boxed {
                        buffer.appendInt32(-276825834)
                    }
                    period.serialize(buffer, true)
                    members.serialize(buffer, true)
                    messages.serialize(buffer, true)
                    viewers.serialize(buffer, true)
                    posters.serialize(buffer, true)
                    growthGraph.serialize(buffer, true)
                    membersGraph.serialize(buffer, true)
                    newMembersBySourceGraph.serialize(buffer, true)
                    languagesGraph.serialize(buffer, true)
                    messagesGraph.serialize(buffer, true)
                    actionsGraph.serialize(buffer, true)
                    topHoursGraph.serialize(buffer, true)
                    weekdaysGraph.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topPosters.count))
                    for item in topPosters {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topAdmins.count))
                    for item in topAdmins {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topInviters.count))
                    for item in topInviters {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .megagroupStats(let period, let members, let messages, let viewers, let posters, let growthGraph, let membersGraph, let newMembersBySourceGraph, let languagesGraph, let messagesGraph, let actionsGraph, let topHoursGraph, let weekdaysGraph, let topPosters, let topAdmins, let topInviters, let users):
                return ("megagroupStats", [("period", period as Any), ("members", members as Any), ("messages", messages as Any), ("viewers", viewers as Any), ("posters", posters as Any), ("growthGraph", growthGraph as Any), ("membersGraph", membersGraph as Any), ("newMembersBySourceGraph", newMembersBySourceGraph as Any), ("languagesGraph", languagesGraph as Any), ("messagesGraph", messagesGraph as Any), ("actionsGraph", actionsGraph as Any), ("topHoursGraph", topHoursGraph as Any), ("weekdaysGraph", weekdaysGraph as Any), ("topPosters", topPosters as Any), ("topAdmins", topAdmins as Any), ("topInviters", topInviters as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_megagroupStats(_ reader: BufferReader) -> MegagroupStats? {
            var _1: Api.StatsDateRangeDays?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsDateRangeDays
            }
            var _2: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _3: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _4: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _5: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _6: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _7: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _8: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _9: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _10: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _11: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _12: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _13: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _14: [Api.StatsGroupTopPoster]?
            if let _ = reader.readInt32() {
                _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopPoster.self)
            }
            var _15: [Api.StatsGroupTopAdmin]?
            if let _ = reader.readInt32() {
                _15 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopAdmin.self)
            }
            var _16: [Api.StatsGroupTopInviter]?
            if let _ = reader.readInt32() {
                _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopInviter.self)
            }
            var _17: [Api.User]?
            if let _ = reader.readInt32() {
                _17 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = _16 != nil
            let _c17 = _17 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 {
                return Api.stats.MegagroupStats.megagroupStats(period: _1!, members: _2!, messages: _3!, viewers: _4!, posters: _5!, growthGraph: _6!, membersGraph: _7!, newMembersBySourceGraph: _8!, languagesGraph: _9!, messagesGraph: _10!, actionsGraph: _11!, topHoursGraph: _12!, weekdaysGraph: _13!, topPosters: _14!, topAdmins: _15!, topInviters: _16!, users: _17!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum MessageStats: TypeConstructorDescription {
        case messageStats(viewsGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageStats(let viewsGraph, let reactionsByEmotionGraph):
                    if boxed {
                        buffer.appendInt32(2145983508)
                    }
                    viewsGraph.serialize(buffer, true)
                    reactionsByEmotionGraph.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageStats(let viewsGraph, let reactionsByEmotionGraph):
                return ("messageStats", [("viewsGraph", viewsGraph as Any), ("reactionsByEmotionGraph", reactionsByEmotionGraph as Any)])
    }
    }
    
        public static func parse_messageStats(_ reader: BufferReader) -> MessageStats? {
            var _1: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _2: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stats.MessageStats.messageStats(viewsGraph: _1!, reactionsByEmotionGraph: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum PublicForwards: TypeConstructorDescription {
        case publicForwards(flags: Int32, count: Int32, forwards: [Api.PublicForward], nextOffset: String?, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .publicForwards(let flags, let count, let forwards, let nextOffset, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1828487648)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(forwards.count))
                    for item in forwards {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .publicForwards(let flags, let count, let forwards, let nextOffset, let chats, let users):
                return ("publicForwards", [("flags", flags as Any), ("count", count as Any), ("forwards", forwards as Any), ("nextOffset", nextOffset as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_publicForwards(_ reader: BufferReader) -> PublicForwards? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.PublicForward]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PublicForward.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.stats.PublicForwards.publicForwards(flags: _1!, count: _2!, forwards: _3!, nextOffset: _4, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum StoryStats: TypeConstructorDescription {
        case storyStats(viewsGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyStats(let viewsGraph, let reactionsByEmotionGraph):
                    if boxed {
                        buffer.appendInt32(1355613820)
                    }
                    viewsGraph.serialize(buffer, true)
                    reactionsByEmotionGraph.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyStats(let viewsGraph, let reactionsByEmotionGraph):
                return ("storyStats", [("viewsGraph", viewsGraph as Any), ("reactionsByEmotionGraph", reactionsByEmotionGraph as Any)])
    }
    }
    
        public static func parse_storyStats(_ reader: BufferReader) -> StoryStats? {
            var _1: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _2: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stats.StoryStats.storyStats(viewsGraph: _1!, reactionsByEmotionGraph: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stickers {
    enum SuggestedShortName: TypeConstructorDescription {
        case suggestedShortName(shortName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .suggestedShortName(let shortName):
                    if boxed {
                        buffer.appendInt32(-2046910401)
                    }
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .suggestedShortName(let shortName):
                return ("suggestedShortName", [("shortName", shortName as Any)])
    }
    }
    
        public static func parse_suggestedShortName(_ reader: BufferReader) -> SuggestedShortName? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.stickers.SuggestedShortName.suggestedShortName(shortName: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.storage {
    enum FileType: TypeConstructorDescription {
        case fileGif
        case fileJpeg
        case fileMov
        case fileMp3
        case fileMp4
        case filePartial
        case filePdf
        case filePng
        case fileUnknown
        case fileWebp
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .fileGif:
                    if boxed {
                        buffer.appendInt32(-891180321)
                    }
                    
                    break
                case .fileJpeg:
                    if boxed {
                        buffer.appendInt32(8322574)
                    }
                    
                    break
                case .fileMov:
                    if boxed {
                        buffer.appendInt32(1258941372)
                    }
                    
                    break
                case .fileMp3:
                    if boxed {
                        buffer.appendInt32(1384777335)
                    }
                    
                    break
                case .fileMp4:
                    if boxed {
                        buffer.appendInt32(-1278304028)
                    }
                    
                    break
                case .filePartial:
                    if boxed {
                        buffer.appendInt32(1086091090)
                    }
                    
                    break
                case .filePdf:
                    if boxed {
                        buffer.appendInt32(-1373745011)
                    }
                    
                    break
                case .filePng:
                    if boxed {
                        buffer.appendInt32(172975040)
                    }
                    
                    break
                case .fileUnknown:
                    if boxed {
                        buffer.appendInt32(-1432995067)
                    }
                    
                    break
                case .fileWebp:
                    if boxed {
                        buffer.appendInt32(276907596)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .fileGif:
                return ("fileGif", [])
                case .fileJpeg:
                return ("fileJpeg", [])
                case .fileMov:
                return ("fileMov", [])
                case .fileMp3:
                return ("fileMp3", [])
                case .fileMp4:
                return ("fileMp4", [])
                case .filePartial:
                return ("filePartial", [])
                case .filePdf:
                return ("filePdf", [])
                case .filePng:
                return ("filePng", [])
                case .fileUnknown:
                return ("fileUnknown", [])
                case .fileWebp:
                return ("fileWebp", [])
    }
    }
    
        public static func parse_fileGif(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileGif
        }
        public static func parse_fileJpeg(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileJpeg
        }
        public static func parse_fileMov(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMov
        }
        public static func parse_fileMp3(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMp3
        }
        public static func parse_fileMp4(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMp4
        }
        public static func parse_filePartial(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePartial
        }
        public static func parse_filePdf(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePdf
        }
        public static func parse_filePng(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePng
        }
        public static func parse_fileUnknown(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileUnknown
        }
        public static func parse_fileWebp(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileWebp
        }
    
    }
}
public extension Api.stories {
    enum AllStories: TypeConstructorDescription {
        case allStories(flags: Int32, count: Int32, state: String, peerStories: [Api.PeerStories], chats: [Api.Chat], users: [Api.User], stealthMode: Api.StoriesStealthMode)
        case allStoriesNotModified(flags: Int32, state: String, stealthMode: Api.StoriesStealthMode)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .allStories(let flags, let count, let state, let peerStories, let chats, let users, let stealthMode):
                    if boxed {
                        buffer.appendInt32(1862033025)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    serializeString(state, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peerStories.count))
                    for item in peerStories {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    stealthMode.serialize(buffer, true)
                    break
                case .allStoriesNotModified(let flags, let state, let stealthMode):
                    if boxed {
                        buffer.appendInt32(291044926)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(state, buffer: buffer, boxed: false)
                    stealthMode.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .allStories(let flags, let count, let state, let peerStories, let chats, let users, let stealthMode):
                return ("allStories", [("flags", flags as Any), ("count", count as Any), ("state", state as Any), ("peerStories", peerStories as Any), ("chats", chats as Any), ("users", users as Any), ("stealthMode", stealthMode as Any)])
                case .allStoriesNotModified(let flags, let state, let stealthMode):
                return ("allStoriesNotModified", [("flags", flags as Any), ("state", state as Any), ("stealthMode", stealthMode as Any)])
    }
    }
    
        public static func parse_allStories(_ reader: BufferReader) -> AllStories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.PeerStories]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PeerStories.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _7: Api.StoriesStealthMode?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StoriesStealthMode
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.stories.AllStories.allStories(flags: _1!, count: _2!, state: _3!, peerStories: _4!, chats: _5!, users: _6!, stealthMode: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_allStoriesNotModified(_ reader: BufferReader) -> AllStories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.StoriesStealthMode?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StoriesStealthMode
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.stories.AllStories.allStoriesNotModified(flags: _1!, state: _2!, stealthMode: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum PeerStories: TypeConstructorDescription {
        case peerStories(stories: Api.PeerStories, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerStories(let stories, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-890861720)
                    }
                    stories.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerStories(let stories, let chats, let users):
                return ("peerStories", [("stories", stories as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_peerStories(_ reader: BufferReader) -> PeerStories? {
            var _1: Api.PeerStories?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PeerStories
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.stories.PeerStories.peerStories(stories: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum Stories: TypeConstructorDescription {
        case stories(count: Int32, stories: [Api.StoryItem], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stories(let count, let stories, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1574486984)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stories.count))
                    for item in stories {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stories(let count, let stories, let chats, let users):
                return ("stories", [("count", count as Any), ("stories", stories as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_stories(_ reader: BufferReader) -> Stories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StoryItem]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryItem.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.stories.Stories.stories(count: _1!, stories: _2!, chats: _3!, users: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum StoryReactionsList: TypeConstructorDescription {
        case storyReactionsList(flags: Int32, count: Int32, reactions: [Api.StoryReaction], chats: [Api.Chat], users: [Api.User], nextOffset: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyReactionsList(let flags, let count, let reactions, let chats, let users, let nextOffset):
                    if boxed {
                        buffer.appendInt32(-1436583780)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(reactions.count))
                    for item in reactions {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyReactionsList(let flags, let count, let reactions, let chats, let users, let nextOffset):
                return ("storyReactionsList", [("flags", flags as Any), ("count", count as Any), ("reactions", reactions as Any), ("chats", chats as Any), ("users", users as Any), ("nextOffset", nextOffset as Any)])
    }
    }
    
        public static func parse_storyReactionsList(_ reader: BufferReader) -> StoryReactionsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.StoryReaction]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryReaction.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.stories.StoryReactionsList.storyReactionsList(flags: _1!, count: _2!, reactions: _3!, chats: _4!, users: _5!, nextOffset: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum StoryViews: TypeConstructorDescription {
        case storyViews(views: [Api.StoryViews], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyViews(let views, let users):
                    if boxed {
                        buffer.appendInt32(-560009955)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(views.count))
                    for item in views {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyViews(let views, let users):
                return ("storyViews", [("views", views as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_storyViews(_ reader: BufferReader) -> StoryViews? {
            var _1: [Api.StoryViews]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryViews.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stories.StoryViews.storyViews(views: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum StoryViewsList: TypeConstructorDescription {
        case storyViewsList(flags: Int32, count: Int32, viewsCount: Int32, forwardsCount: Int32, reactionsCount: Int32, views: [Api.StoryView], chats: [Api.Chat], users: [Api.User], nextOffset: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyViewsList(let flags, let count, let viewsCount, let forwardsCount, let reactionsCount, let views, let chats, let users, let nextOffset):
                    if boxed {
                        buffer.appendInt32(1507299269)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    serializeInt32(viewsCount, buffer: buffer, boxed: false)
                    serializeInt32(forwardsCount, buffer: buffer, boxed: false)
                    serializeInt32(reactionsCount, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(views.count))
                    for item in views {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyViewsList(let flags, let count, let viewsCount, let forwardsCount, let reactionsCount, let views, let chats, let users, let nextOffset):
                return ("storyViewsList", [("flags", flags as Any), ("count", count as Any), ("viewsCount", viewsCount as Any), ("forwardsCount", forwardsCount as Any), ("reactionsCount", reactionsCount as Any), ("views", views as Any), ("chats", chats as Any), ("users", users as Any), ("nextOffset", nextOffset as Any)])
    }
    }
    
        public static func parse_storyViewsList(_ reader: BufferReader) -> StoryViewsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: [Api.StoryView]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryView.self)
            }
            var _7: [Api.Chat]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _8: [Api.User]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _9: String?
            if Int(_1!) & Int(1 << 0) != 0 {_9 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 0) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.stories.StoryViewsList.storyViewsList(flags: _1!, count: _2!, viewsCount: _3!, forwardsCount: _4!, reactionsCount: _5!, views: _6!, chats: _7!, users: _8!, nextOffset: _9)
            }
            else {
                return nil
            }
        }
    
    }
}
