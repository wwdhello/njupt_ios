import Foundation
import CryptoKit

/// Token 解密与解析 —— 完全对齐 Android 版 AES-GCM 逻辑
enum TokenProcessor {

    // MARK: - 混淆密钥（与 Android 版一致，切勿修改）

    private static let obfuscatedKey: [UInt8] = [
        0xc4, 0xe0, 0xff, 0xfa, 0xfe, 0xcb, 0xff, 0xfe,
        0xe2, 0xd9, 0xef, 0xe9, 0xf8, 0xef, 0xfe, 0xc1,
        0xef, 0xf3, 0xb8, 0xba, 0xb8, 0xbc, 0xab, 0xca,
        0xa9, 0xbb, 0xb8, 0xb9, 0xbe, 0xbf, 0xbc, 0xbd
    ]

    /// 还原真实 AES 密钥（XOR 0x8A）
    private static var keyBytes: [UInt8] {
        obfuscatedKey.map { $0 ^ 0x8A }
    }

    // MARK: - 解析结果

    struct AuthInfo {
        let username: String       // 带运营商后缀的完整用户名
        let password: String
        let rawUsername: String
        let networkType: String
        let expiryTimestamp: Int64
    }

    // MARK: - 主解密入口

    /// 解密并解析 Token，失败返回 nil
    static func process(token: String) -> AuthInfo? {
        do {
            // 1. URL Safe Base64 解码
            guard let cipherBytes = base64URLDecode(token) else {
                throw TokenError.base64DecodeFailed
            }

            // 2. 提取 Nonce（前 12 字节）和密文+Tag（剩余部分）
            guard cipherBytes.count > 28 else {
                throw TokenError.invalidLength
            }
            let nonceData = Data(cipherBytes.prefix(12))
            let combined = Data(cipherBytes.suffix(from: 12))

            // 3. AES-GCM 解密
            //    Android 的 Cipher.doFinal() 返回 ciphertext + 16-byte tag 拼接
            //    CryptoKit 需要分开传入
            let tagLength = 16
            guard combined.count > tagLength else {
                throw TokenError.invalidLength
            }
            let ciphertext = Data(combined.prefix(combined.count - tagLength))
            let tag = Data(combined.suffix(tagLength))

            // CryptoKit: init(data:) 是 throwing，不是 optional
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let key = SymmetricKey(data: Data(keyBytes))
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: ciphertext,
                tag: tag
            )
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            guard let decrypted = String(data: decryptedData, encoding: .utf8) else {
                throw TokenError.utf8DecodeFailed
            }

            // 4. 解析 | 分隔的内容
            let parts = decrypted.components(separatedBy: "|")
            guard parts.count >= 4 else {
                throw TokenError.invalidFormat
            }

            let rawUsername = parts[0]
            let password = parts[1]
            let networkType = parts[2]
            guard let exp = Int64(parts[3]) else {
                throw TokenError.invalidExpiry
            }

            // 5. 检查过期
            let now = Int64(Date().timeIntervalSince1970)
            guard now <= exp else {
                throw TokenError.expired
            }

            // 6. 拼接运营商后缀
            let suffix: String
            switch networkType {
            case "中国电信": suffix = "@telecom"
            case "中国移动": suffix = "@cmcc"
            case "中国联通": suffix = "@unicom"
            default:         suffix = ""
            }
            let fullUsername = rawUsername + suffix

            return AuthInfo(
                username: fullUsername,
                password: password,
                rawUsername: rawUsername,
                networkType: networkType,
                expiryTimestamp: exp
            )

        } catch let error as TokenError {
            print("[TokenProcessor] \(error.localizedDescription)")
            return nil
        } catch {
            print("[TokenProcessor] 未知错误: \(error)")
            return nil
        }
    }

    // MARK: - Base64 URL Safe 解码

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // 补齐等号
        while base64.count % 4 != 0 {
            base64 += "="
        }
        return Data(base64Encoded: base64)
    }

    // MARK: - 错误类型

    enum TokenError: LocalizedError {
        case base64DecodeFailed
        case invalidLength
        case invalidNonce
        case utf8DecodeFailed
        case invalidFormat
        case invalidExpiry
        case expired

        var errorDescription: String? {
            switch self {
            case .base64DecodeFailed: return "Base64 解码失败"
            case .invalidLength:      return "Token 长度无效"
            case .invalidNonce:       return "Nonce 无效"
            case .utf8DecodeFailed:   return "UTF-8 解码失败"
            case .invalidFormat:      return "Token 格式不兼容，请确认是否为最新版"
            case .invalidExpiry:      return "过期时间解析失败"
            case .expired:            return "抱歉：您的授权 Token 已过期，请获取新 Token！"
            }
        }
    }
}
