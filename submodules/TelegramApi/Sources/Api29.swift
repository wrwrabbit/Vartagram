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
    enum BoostersList: TypeConstructorDescription {
        case boostersList(flags: Int32, count: Int32, boosters: [Api.Booster], nextOffset: String?, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .boostersList(let flags, let count, let boosters, let nextOffset, let users):
                    if boxed {
                        buffer.appendInt32(-203604707)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(boosters.count))
                    for item in boosters {
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
                case .boostersList(let flags, let count, let boosters, let nextOffset, let users):
                return ("boostersList", [("flags", flags as Any), ("count", count as Any), ("boosters", boosters as Any), ("nextOffset", nextOffset as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_boostersList(_ reader: BufferReader) -> BoostersList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.Booster]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Booster.self)
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
                return Api.stories.BoostersList.boostersList(flags: _1!, count: _2!, boosters: _3!, nextOffset: _4, users: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum BoostsStatus: TypeConstructorDescription {
        case boostsStatus(flags: Int32, level: Int32, currentLevelBoosts: Int32, boosts: Int32, nextLevelBoosts: Int32?, premiumAudience: Api.StatsPercentValue?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .boostsStatus(let flags, let level, let currentLevelBoosts, let boosts, let nextLevelBoosts, let premiumAudience):
                    if boxed {
                        buffer.appendInt32(1726619631)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(level, buffer: buffer, boxed: false)
                    serializeInt32(currentLevelBoosts, buffer: buffer, boxed: false)
                    serializeInt32(boosts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(nextLevelBoosts!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {premiumAudience!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .boostsStatus(let flags, let level, let currentLevelBoosts, let boosts, let nextLevelBoosts, let premiumAudience):
                return ("boostsStatus", [("flags", flags as Any), ("level", level as Any), ("currentLevelBoosts", currentLevelBoosts as Any), ("boosts", boosts as Any), ("nextLevelBoosts", nextLevelBoosts as Any), ("premiumAudience", premiumAudience as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            var _6: Api.StatsPercentValue?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StatsPercentValue
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.stories.BoostsStatus.boostsStatus(flags: _1!, level: _2!, currentLevelBoosts: _3!, boosts: _4!, nextLevelBoosts: _5, premiumAudience: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stories {
    enum CanApplyBoostResult: TypeConstructorDescription {
        case canApplyBoostOk
        case canApplyBoostReplace(currentBoost: Api.Peer, chats: [Api.Chat])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .canApplyBoostOk:
                    if boxed {
                        buffer.appendInt32(-1021889145)
                    }
                    
                    break
                case .canApplyBoostReplace(let currentBoost, let chats):
                    if boxed {
                        buffer.appendInt32(1898726997)
                    }
                    currentBoost.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .canApplyBoostOk:
                return ("canApplyBoostOk", [])
                case .canApplyBoostReplace(let currentBoost, let chats):
                return ("canApplyBoostReplace", [("currentBoost", currentBoost as Any), ("chats", chats as Any)])
    }
    }
    
        public static func parse_canApplyBoostOk(_ reader: BufferReader) -> CanApplyBoostResult? {
            return Api.stories.CanApplyBoostResult.canApplyBoostOk
        }
        public static func parse_canApplyBoostReplace(_ reader: BufferReader) -> CanApplyBoostResult? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stories.CanApplyBoostResult.canApplyBoostReplace(currentBoost: _1!, chats: _2!)
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
        case storyViewsList(flags: Int32, count: Int32, reactionsCount: Int32, views: [Api.StoryView], users: [Api.User], nextOffset: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyViewsList(let flags, let count, let reactionsCount, let views, let users, let nextOffset):
                    if boxed {
                        buffer.appendInt32(1189722604)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    serializeInt32(reactionsCount, buffer: buffer, boxed: false)
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
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyViewsList(let flags, let count, let reactionsCount, let views, let users, let nextOffset):
                return ("storyViewsList", [("flags", flags as Any), ("count", count as Any), ("reactionsCount", reactionsCount as Any), ("views", views as Any), ("users", users as Any), ("nextOffset", nextOffset as Any)])
    }
    }
    
        public static func parse_storyViewsList(_ reader: BufferReader) -> StoryViewsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.StoryView]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryView.self)
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
                return Api.stories.StoryViewsList.storyViewsList(flags: _1!, count: _2!, reactionsCount: _3!, views: _4!, users: _5!, nextOffset: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.updates {
    enum ChannelDifference: TypeConstructorDescription {
        case channelDifference(flags: Int32, pts: Int32, timeout: Int32?, newMessages: [Api.Message], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User])
        case channelDifferenceEmpty(flags: Int32, pts: Int32, timeout: Int32?)
        case channelDifferenceTooLong(flags: Int32, timeout: Int32?, dialog: Api.Dialog, messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelDifference(let flags, let pts, let timeout, let newMessages, let otherUpdates, let chats, let users):
                    if boxed {
                        buffer.appendInt32(543450958)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newMessages.count))
                    for item in newMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUpdates.count))
                    for item in otherUpdates {
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
                case .channelDifferenceEmpty(let flags, let pts, let timeout):
                    if boxed {
                        buffer.appendInt32(1041346555)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    break
                case .channelDifferenceTooLong(let flags, let timeout, let dialog, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1531132162)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    dialog.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
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
                case .channelDifference(let flags, let pts, let timeout, let newMessages, let otherUpdates, let chats, let users):
                return ("channelDifference", [("flags", flags as Any), ("pts", pts as Any), ("timeout", timeout as Any), ("newMessages", newMessages as Any), ("otherUpdates", otherUpdates as Any), ("chats", chats as Any), ("users", users as Any)])
                case .channelDifferenceEmpty(let flags, let pts, let timeout):
                return ("channelDifferenceEmpty", [("flags", flags as Any), ("pts", pts as Any), ("timeout", timeout as Any)])
                case .channelDifferenceTooLong(let flags, let timeout, let dialog, let messages, let chats, let users):
                return ("channelDifferenceTooLong", [("flags", flags as Any), ("timeout", timeout as Any), ("dialog", dialog as Any), ("messages", messages as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_channelDifference(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Update]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _6: [Api.Chat]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _7: [Api.User]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.updates.ChannelDifference.channelDifference(flags: _1!, pts: _2!, timeout: _3, newMessages: _4!, otherUpdates: _5!, chats: _6!, users: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelDifferenceEmpty(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.updates.ChannelDifference.channelDifferenceEmpty(flags: _1!, pts: _2!, timeout: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_channelDifferenceTooLong(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: Api.Dialog?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Dialog
            }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.ChannelDifference.channelDifferenceTooLong(flags: _1!, timeout: _2, dialog: _3!, messages: _4!, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.updates {
    enum Difference: TypeConstructorDescription {
        case difference(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], state: Api.updates.State)
        case differenceEmpty(date: Int32, seq: Int32)
        case differenceSlice(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], intermediateState: Api.updates.State)
        case differenceTooLong(pts: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .difference(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let state):
                    if boxed {
                        buffer.appendInt32(16030880)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newMessages.count))
                    for item in newMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newEncryptedMessages.count))
                    for item in newEncryptedMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUpdates.count))
                    for item in otherUpdates {
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
                    state.serialize(buffer, true)
                    break
                case .differenceEmpty(let date, let seq):
                    if boxed {
                        buffer.appendInt32(1567990072)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(seq, buffer: buffer, boxed: false)
                    break
                case .differenceSlice(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let intermediateState):
                    if boxed {
                        buffer.appendInt32(-1459938943)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newMessages.count))
                    for item in newMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newEncryptedMessages.count))
                    for item in newEncryptedMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUpdates.count))
                    for item in otherUpdates {
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
                    intermediateState.serialize(buffer, true)
                    break
                case .differenceTooLong(let pts):
                    if boxed {
                        buffer.appendInt32(1258196845)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .difference(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let state):
                return ("difference", [("newMessages", newMessages as Any), ("newEncryptedMessages", newEncryptedMessages as Any), ("otherUpdates", otherUpdates as Any), ("chats", chats as Any), ("users", users as Any), ("state", state as Any)])
                case .differenceEmpty(let date, let seq):
                return ("differenceEmpty", [("date", date as Any), ("seq", seq as Any)])
                case .differenceSlice(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let intermediateState):
                return ("differenceSlice", [("newMessages", newMessages as Any), ("newEncryptedMessages", newEncryptedMessages as Any), ("otherUpdates", otherUpdates as Any), ("chats", chats as Any), ("users", users as Any), ("intermediateState", intermediateState as Any)])
                case .differenceTooLong(let pts):
                return ("differenceTooLong", [("pts", pts as Any)])
    }
    }
    
        public static func parse_difference(_ reader: BufferReader) -> Difference? {
            var _1: [Api.Message]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _2: [Api.EncryptedMessage]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EncryptedMessage.self)
            }
            var _3: [Api.Update]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: Api.updates.State?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.updates.State
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.Difference.difference(newMessages: _1!, newEncryptedMessages: _2!, otherUpdates: _3!, chats: _4!, users: _5!, state: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_differenceEmpty(_ reader: BufferReader) -> Difference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.updates.Difference.differenceEmpty(date: _1!, seq: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_differenceSlice(_ reader: BufferReader) -> Difference? {
            var _1: [Api.Message]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _2: [Api.EncryptedMessage]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EncryptedMessage.self)
            }
            var _3: [Api.Update]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: Api.updates.State?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.updates.State
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.Difference.differenceSlice(newMessages: _1!, newEncryptedMessages: _2!, otherUpdates: _3!, chats: _4!, users: _5!, intermediateState: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_differenceTooLong(_ reader: BufferReader) -> Difference? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.updates.Difference.differenceTooLong(pts: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.updates {
    enum State: TypeConstructorDescription {
        case state(pts: Int32, qts: Int32, date: Int32, seq: Int32, unreadCount: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .state(let pts, let qts, let date, let seq, let unreadCount):
                    if boxed {
                        buffer.appendInt32(-1519637954)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(seq, buffer: buffer, boxed: false)
                    serializeInt32(unreadCount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .state(let pts, let qts, let date, let seq, let unreadCount):
                return ("state", [("pts", pts as Any), ("qts", qts as Any), ("date", date as Any), ("seq", seq as Any), ("unreadCount", unreadCount as Any)])
    }
    }
    
        public static func parse_state(_ reader: BufferReader) -> State? {
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.updates.State.state(pts: _1!, qts: _2!, date: _3!, seq: _4!, unreadCount: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.upload {
    enum CdnFile: TypeConstructorDescription {
        case cdnFile(bytes: Buffer)
        case cdnFileReuploadNeeded(requestToken: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .cdnFile(let bytes):
                    if boxed {
                        buffer.appendInt32(-1449145777)
                    }
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
                case .cdnFileReuploadNeeded(let requestToken):
                    if boxed {
                        buffer.appendInt32(-290921362)
                    }
                    serializeBytes(requestToken, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .cdnFile(let bytes):
                return ("cdnFile", [("bytes", bytes as Any)])
                case .cdnFileReuploadNeeded(let requestToken):
                return ("cdnFileReuploadNeeded", [("requestToken", requestToken as Any)])
    }
    }
    
        public static func parse_cdnFile(_ reader: BufferReader) -> CdnFile? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.upload.CdnFile.cdnFile(bytes: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_cdnFileReuploadNeeded(_ reader: BufferReader) -> CdnFile? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.upload.CdnFile.cdnFileReuploadNeeded(requestToken: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.upload {
    enum File: TypeConstructorDescription {
        case file(type: Api.storage.FileType, mtime: Int32, bytes: Buffer)
        case fileCdnRedirect(dcId: Int32, fileToken: Buffer, encryptionKey: Buffer, encryptionIv: Buffer, fileHashes: [Api.FileHash])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .file(let type, let mtime, let bytes):
                    if boxed {
                        buffer.appendInt32(157948117)
                    }
                    type.serialize(buffer, true)
                    serializeInt32(mtime, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
                case .fileCdnRedirect(let dcId, let fileToken, let encryptionKey, let encryptionIv, let fileHashes):
                    if boxed {
                        buffer.appendInt32(-242427324)
                    }
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeBytes(fileToken, buffer: buffer, boxed: false)
                    serializeBytes(encryptionKey, buffer: buffer, boxed: false)
                    serializeBytes(encryptionIv, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(fileHashes.count))
                    for item in fileHashes {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .file(let type, let mtime, let bytes):
                return ("file", [("type", type as Any), ("mtime", mtime as Any), ("bytes", bytes as Any)])
                case .fileCdnRedirect(let dcId, let fileToken, let encryptionKey, let encryptionIv, let fileHashes):
                return ("fileCdnRedirect", [("dcId", dcId as Any), ("fileToken", fileToken as Any), ("encryptionKey", encryptionKey as Any), ("encryptionIv", encryptionIv as Any), ("fileHashes", fileHashes as Any)])
    }
    }
    
        public static func parse_file(_ reader: BufferReader) -> File? {
            var _1: Api.storage.FileType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.storage.FileType
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.upload.File.file(type: _1!, mtime: _2!, bytes: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_fileCdnRedirect(_ reader: BufferReader) -> File? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: [Api.FileHash]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.upload.File.fileCdnRedirect(dcId: _1!, fileToken: _2!, encryptionKey: _3!, encryptionIv: _4!, fileHashes: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
