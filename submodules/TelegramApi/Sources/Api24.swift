public extension Api.auth {
    enum Authorization: TypeConstructorDescription {
        case authorization(flags: Int32, otherwiseReloginDays: Int32?, tmpSessions: Int32?, futureAuthToken: Buffer?, user: Api.User)
        case authorizationSignUpRequired(flags: Int32, termsOfService: Api.help.TermsOfService?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .authorization(let flags, let otherwiseReloginDays, let tmpSessions, let futureAuthToken, let user):
                    if boxed {
                        buffer.appendInt32(782418132)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(otherwiseReloginDays!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(tmpSessions!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeBytes(futureAuthToken!, buffer: buffer, boxed: false)}
                    user.serialize(buffer, true)
                    break
                case .authorizationSignUpRequired(let flags, let termsOfService):
                    if boxed {
                        buffer.appendInt32(1148485274)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {termsOfService!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .authorization(let flags, let otherwiseReloginDays, let tmpSessions, let futureAuthToken, let user):
                return ("authorization", [("flags", flags as Any), ("otherwiseReloginDays", otherwiseReloginDays as Any), ("tmpSessions", tmpSessions as Any), ("futureAuthToken", futureAuthToken as Any), ("user", user as Any)])
                case .authorizationSignUpRequired(let flags, let termsOfService):
                return ("authorizationSignUpRequired", [("flags", flags as Any), ("termsOfService", termsOfService as Any)])
    }
    }
    
        public static func parse_authorization(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = parseBytes(reader) }
            var _5: Api.User?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.User
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.auth.Authorization.authorization(flags: _1!, otherwiseReloginDays: _2, tmpSessions: _3, futureAuthToken: _4, user: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_authorizationSignUpRequired(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.help.TermsOfService?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.help.TermsOfService
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.Authorization.authorizationSignUpRequired(flags: _1!, termsOfService: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.auth {
    enum CodeType: TypeConstructorDescription {
        case codeTypeCall
        case codeTypeFlashCall
        case codeTypeFragmentSms
        case codeTypeMissedCall
        case codeTypeSms
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .codeTypeCall:
                    if boxed {
                        buffer.appendInt32(1948046307)
                    }
                    
                    break
                case .codeTypeFlashCall:
                    if boxed {
                        buffer.appendInt32(577556219)
                    }
                    
                    break
                case .codeTypeFragmentSms:
                    if boxed {
                        buffer.appendInt32(116234636)
                    }
                    
                    break
                case .codeTypeMissedCall:
                    if boxed {
                        buffer.appendInt32(-702884114)
                    }
                    
                    break
                case .codeTypeSms:
                    if boxed {
                        buffer.appendInt32(1923290508)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .codeTypeCall:
                return ("codeTypeCall", [])
                case .codeTypeFlashCall:
                return ("codeTypeFlashCall", [])
                case .codeTypeFragmentSms:
                return ("codeTypeFragmentSms", [])
                case .codeTypeMissedCall:
                return ("codeTypeMissedCall", [])
                case .codeTypeSms:
                return ("codeTypeSms", [])
    }
    }
    
        public static func parse_codeTypeCall(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeCall
        }
        public static func parse_codeTypeFlashCall(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeFlashCall
        }
        public static func parse_codeTypeFragmentSms(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeFragmentSms
        }
        public static func parse_codeTypeMissedCall(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeMissedCall
        }
        public static func parse_codeTypeSms(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeSms
        }
    
    }
}
public extension Api.auth {
    enum ExportedAuthorization: TypeConstructorDescription {
        case exportedAuthorization(id: Int64, bytes: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedAuthorization(let id, let bytes):
                    if boxed {
                        buffer.appendInt32(-1271602504)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .exportedAuthorization(let id, let bytes):
                return ("exportedAuthorization", [("id", id as Any), ("bytes", bytes as Any)])
    }
    }
    
        public static func parse_exportedAuthorization(_ reader: BufferReader) -> ExportedAuthorization? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.ExportedAuthorization.exportedAuthorization(id: _1!, bytes: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.auth {
    enum LoggedOut: TypeConstructorDescription {
        case loggedOut(flags: Int32, futureAuthToken: Buffer?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .loggedOut(let flags, let futureAuthToken):
                    if boxed {
                        buffer.appendInt32(-1012759713)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(futureAuthToken!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .loggedOut(let flags, let futureAuthToken):
                return ("loggedOut", [("flags", flags as Any), ("futureAuthToken", futureAuthToken as Any)])
    }
    }
    
        public static func parse_loggedOut(_ reader: BufferReader) -> LoggedOut? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseBytes(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.LoggedOut.loggedOut(flags: _1!, futureAuthToken: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.auth {
    enum LoginToken: TypeConstructorDescription {
        case loginToken(expires: Int32, token: Buffer)
        case loginTokenMigrateTo(dcId: Int32, token: Buffer)
        case loginTokenSuccess(authorization: Api.auth.Authorization)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .loginToken(let expires, let token):
                    if boxed {
                        buffer.appendInt32(1654593920)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    serializeBytes(token, buffer: buffer, boxed: false)
                    break
                case .loginTokenMigrateTo(let dcId, let token):
                    if boxed {
                        buffer.appendInt32(110008598)
                    }
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeBytes(token, buffer: buffer, boxed: false)
                    break
                case .loginTokenSuccess(let authorization):
                    if boxed {
                        buffer.appendInt32(957176926)
                    }
                    authorization.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .loginToken(let expires, let token):
                return ("loginToken", [("expires", expires as Any), ("token", token as Any)])
                case .loginTokenMigrateTo(let dcId, let token):
                return ("loginTokenMigrateTo", [("dcId", dcId as Any), ("token", token as Any)])
                case .loginTokenSuccess(let authorization):
                return ("loginTokenSuccess", [("authorization", authorization as Any)])
    }
    }
    
        public static func parse_loginToken(_ reader: BufferReader) -> LoginToken? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.LoginToken.loginToken(expires: _1!, token: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_loginTokenMigrateTo(_ reader: BufferReader) -> LoginToken? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.LoginToken.loginTokenMigrateTo(dcId: _1!, token: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_loginTokenSuccess(_ reader: BufferReader) -> LoginToken? {
            var _1: Api.auth.Authorization?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.auth.Authorization
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.LoginToken.loginTokenSuccess(authorization: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.auth {
    enum PasswordRecovery: TypeConstructorDescription {
        case passwordRecovery(emailPattern: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passwordRecovery(let emailPattern):
                    if boxed {
                        buffer.appendInt32(326715557)
                    }
                    serializeString(emailPattern, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passwordRecovery(let emailPattern):
                return ("passwordRecovery", [("emailPattern", emailPattern as Any)])
    }
    }
    
        public static func parse_passwordRecovery(_ reader: BufferReader) -> PasswordRecovery? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.PasswordRecovery.passwordRecovery(emailPattern: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.auth {
    enum SentCode: TypeConstructorDescription {
        case sentCode(flags: Int32, type: Api.auth.SentCodeType, phoneCodeHash: String, nextType: Api.auth.CodeType?, timeout: Int32?)
        case sentCodeSuccess(authorization: Api.auth.Authorization)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sentCode(let flags, let type, let phoneCodeHash, let nextType, let timeout):
                    if boxed {
                        buffer.appendInt32(1577067778)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    type.serialize(buffer, true)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {nextType!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    break
                case .sentCodeSuccess(let authorization):
                    if boxed {
                        buffer.appendInt32(596704836)
                    }
                    authorization.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sentCode(let flags, let type, let phoneCodeHash, let nextType, let timeout):
                return ("sentCode", [("flags", flags as Any), ("type", type as Any), ("phoneCodeHash", phoneCodeHash as Any), ("nextType", nextType as Any), ("timeout", timeout as Any)])
                case .sentCodeSuccess(let authorization):
                return ("sentCodeSuccess", [("authorization", authorization as Any)])
    }
    }
    
        public static func parse_sentCode(_ reader: BufferReader) -> SentCode? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.auth.SentCodeType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.auth.SentCodeType
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.auth.CodeType?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.auth.CodeType
            } }
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.auth.SentCode.sentCode(flags: _1!, type: _2!, phoneCodeHash: _3!, nextType: _4, timeout: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeSuccess(_ reader: BufferReader) -> SentCode? {
            var _1: Api.auth.Authorization?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.auth.Authorization
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCode.sentCodeSuccess(authorization: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.auth {
    enum SentCodeType: TypeConstructorDescription {
        case sentCodeTypeApp(length: Int32)
        case sentCodeTypeCall(length: Int32)
        case sentCodeTypeEmailCode(flags: Int32, emailPattern: String, length: Int32, resetAvailablePeriod: Int32?, resetPendingDate: Int32?)
        case sentCodeTypeFirebaseSms(flags: Int32, nonce: Buffer?, receipt: String?, pushTimeout: Int32?, length: Int32)
        case sentCodeTypeFlashCall(pattern: String)
        case sentCodeTypeFragmentSms(url: String, length: Int32)
        case sentCodeTypeMissedCall(prefix: String, length: Int32)
        case sentCodeTypeSetUpEmailRequired(flags: Int32)
        case sentCodeTypeSms(length: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sentCodeTypeApp(let length):
                    if boxed {
                        buffer.appendInt32(1035688326)
                    }
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeCall(let length):
                    if boxed {
                        buffer.appendInt32(1398007207)
                    }
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeEmailCode(let flags, let emailPattern, let length, let resetAvailablePeriod, let resetPendingDate):
                    if boxed {
                        buffer.appendInt32(-196020837)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(emailPattern, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(resetAvailablePeriod!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(resetPendingDate!, buffer: buffer, boxed: false)}
                    break
                case .sentCodeTypeFirebaseSms(let flags, let nonce, let receipt, let pushTimeout, let length):
                    if boxed {
                        buffer.appendInt32(-444918734)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(nonce!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(receipt!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(pushTimeout!, buffer: buffer, boxed: false)}
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeFlashCall(let pattern):
                    if boxed {
                        buffer.appendInt32(-1425815847)
                    }
                    serializeString(pattern, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeFragmentSms(let url, let length):
                    if boxed {
                        buffer.appendInt32(-648651719)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeMissedCall(let prefix, let length):
                    if boxed {
                        buffer.appendInt32(-2113903484)
                    }
                    serializeString(prefix, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeSetUpEmailRequired(let flags):
                    if boxed {
                        buffer.appendInt32(-1521934870)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeSms(let length):
                    if boxed {
                        buffer.appendInt32(-1073693790)
                    }
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sentCodeTypeApp(let length):
                return ("sentCodeTypeApp", [("length", length as Any)])
                case .sentCodeTypeCall(let length):
                return ("sentCodeTypeCall", [("length", length as Any)])
                case .sentCodeTypeEmailCode(let flags, let emailPattern, let length, let resetAvailablePeriod, let resetPendingDate):
                return ("sentCodeTypeEmailCode", [("flags", flags as Any), ("emailPattern", emailPattern as Any), ("length", length as Any), ("resetAvailablePeriod", resetAvailablePeriod as Any), ("resetPendingDate", resetPendingDate as Any)])
                case .sentCodeTypeFirebaseSms(let flags, let nonce, let receipt, let pushTimeout, let length):
                return ("sentCodeTypeFirebaseSms", [("flags", flags as Any), ("nonce", nonce as Any), ("receipt", receipt as Any), ("pushTimeout", pushTimeout as Any), ("length", length as Any)])
                case .sentCodeTypeFlashCall(let pattern):
                return ("sentCodeTypeFlashCall", [("pattern", pattern as Any)])
                case .sentCodeTypeFragmentSms(let url, let length):
                return ("sentCodeTypeFragmentSms", [("url", url as Any), ("length", length as Any)])
                case .sentCodeTypeMissedCall(let prefix, let length):
                return ("sentCodeTypeMissedCall", [("prefix", prefix as Any), ("length", length as Any)])
                case .sentCodeTypeSetUpEmailRequired(let flags):
                return ("sentCodeTypeSetUpEmailRequired", [("flags", flags as Any)])
                case .sentCodeTypeSms(let length):
                return ("sentCodeTypeSms", [("length", length as Any)])
    }
    }
    
        public static func parse_sentCodeTypeApp(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCodeType.sentCodeTypeApp(length: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeCall(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCodeType.sentCodeTypeCall(length: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeEmailCode(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.auth.SentCodeType.sentCodeTypeEmailCode(flags: _1!, emailPattern: _2!, length: _3!, resetAvailablePeriod: _4, resetPendingDate: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeFirebaseSms(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseBytes(reader) }
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseString(reader) }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.auth.SentCodeType.sentCodeTypeFirebaseSms(flags: _1!, nonce: _2, receipt: _3, pushTimeout: _4, length: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeFlashCall(_ reader: BufferReader) -> SentCodeType? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCodeType.sentCodeTypeFlashCall(pattern: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeFragmentSms(_ reader: BufferReader) -> SentCodeType? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.SentCodeType.sentCodeTypeFragmentSms(url: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeMissedCall(_ reader: BufferReader) -> SentCodeType? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.SentCodeType.sentCodeTypeMissedCall(prefix: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeSetUpEmailRequired(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCodeType.sentCodeTypeSetUpEmailRequired(flags: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeSms(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCodeType.sentCodeTypeSms(length: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.bots {
    enum BotInfo: TypeConstructorDescription {
        case botInfo(name: String, about: String, description: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botInfo(let name, let about, let description):
                    if boxed {
                        buffer.appendInt32(-391678544)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    serializeString(about, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botInfo(let name, let about, let description):
                return ("botInfo", [("name", name as Any), ("about", about as Any), ("description", description as Any)])
    }
    }
    
        public static func parse_botInfo(_ reader: BufferReader) -> BotInfo? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.bots.BotInfo.botInfo(name: _1!, about: _2!, description: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.channels {
    enum AdminLogResults: TypeConstructorDescription {
        case adminLogResults(events: [Api.ChannelAdminLogEvent], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .adminLogResults(let events, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-309659827)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(events.count))
                    for item in events {
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
                case .adminLogResults(let events, let chats, let users):
                return ("adminLogResults", [("events", events as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_adminLogResults(_ reader: BufferReader) -> AdminLogResults? {
            var _1: [Api.ChannelAdminLogEvent]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChannelAdminLogEvent.self)
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
                return Api.channels.AdminLogResults.adminLogResults(events: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.channels {
    enum ChannelParticipant: TypeConstructorDescription {
        case channelParticipant(participant: Api.ChannelParticipant, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelParticipant(let participant, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-541588713)
                    }
                    participant.serialize(buffer, true)
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
                case .channelParticipant(let participant, let chats, let users):
                return ("channelParticipant", [("participant", participant as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_channelParticipant(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
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
                return Api.channels.ChannelParticipant.channelParticipant(participant: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.channels {
    enum ChannelParticipants: TypeConstructorDescription {
        case channelParticipants(count: Int32, participants: [Api.ChannelParticipant], chats: [Api.Chat], users: [Api.User])
        case channelParticipantsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelParticipants(let count, let participants, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1699676497)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
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
                case .channelParticipantsNotModified:
                    if boxed {
                        buffer.appendInt32(-266911767)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelParticipants(let count, let participants, let chats, let users):
                return ("channelParticipants", [("count", count as Any), ("participants", participants as Any), ("chats", chats as Any), ("users", users as Any)])
                case .channelParticipantsNotModified:
                return ("channelParticipantsNotModified", [])
    }
    }
    
        public static func parse_channelParticipants(_ reader: BufferReader) -> ChannelParticipants? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.ChannelParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChannelParticipant.self)
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
                return Api.channels.ChannelParticipants.channelParticipants(count: _1!, participants: _2!, chats: _3!, users: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantsNotModified(_ reader: BufferReader) -> ChannelParticipants? {
            return Api.channels.ChannelParticipants.channelParticipantsNotModified
        }
    
    }
}
public extension Api.channels {
    enum SendAsPeers: TypeConstructorDescription {
        case sendAsPeers(peers: [Api.SendAsPeer], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sendAsPeers(let peers, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-191450938)
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
                case .sendAsPeers(let peers, let chats, let users):
                return ("sendAsPeers", [("peers", peers as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_sendAsPeers(_ reader: BufferReader) -> SendAsPeers? {
            var _1: [Api.SendAsPeer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SendAsPeer.self)
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
                return Api.channels.SendAsPeers.sendAsPeers(peers: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.chatlists {
    enum ChatlistInvite: TypeConstructorDescription {
        case chatlistInvite(flags: Int32, title: String, emoticon: String?, peers: [Api.Peer], chats: [Api.Chat], users: [Api.User])
        case chatlistInviteAlready(filterId: Int32, missingPeers: [Api.Peer], alreadyPeers: [Api.Peer], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatlistInvite(let flags, let title, let emoticon, let peers, let chats, let users):
                    if boxed {
                        buffer.appendInt32(500007837)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(emoticon!, buffer: buffer, boxed: false)}
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
                case .chatlistInviteAlready(let filterId, let missingPeers, let alreadyPeers, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-91752871)
                    }
                    serializeInt32(filterId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(missingPeers.count))
                    for item in missingPeers {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(alreadyPeers.count))
                    for item in alreadyPeers {
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
                case .chatlistInvite(let flags, let title, let emoticon, let peers, let chats, let users):
                return ("chatlistInvite", [("flags", flags as Any), ("title", title as Any), ("emoticon", emoticon as Any), ("peers", peers as Any), ("chats", chats as Any), ("users", users as Any)])
                case .chatlistInviteAlready(let filterId, let missingPeers, let alreadyPeers, let chats, let users):
                return ("chatlistInviteAlready", [("filterId", filterId as Any), ("missingPeers", missingPeers as Any), ("alreadyPeers", alreadyPeers as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_chatlistInvite(_ reader: BufferReader) -> ChatlistInvite? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: [Api.Peer]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
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
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.chatlists.ChatlistInvite.chatlistInvite(flags: _1!, title: _2!, emoticon: _3, peers: _4!, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_chatlistInviteAlready(_ reader: BufferReader) -> ChatlistInvite? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Peer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            }
            var _3: [Api.Peer]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.chatlists.ChatlistInvite.chatlistInviteAlready(filterId: _1!, missingPeers: _2!, alreadyPeers: _3!, chats: _4!, users: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
