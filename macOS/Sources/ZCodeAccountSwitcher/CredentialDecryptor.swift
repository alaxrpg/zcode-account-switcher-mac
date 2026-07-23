import Foundation
import CryptoKit

struct CredentialDecryptor {
    static let prefix = "enc:v1:"
    
    static func getCredentialSecret() -> String {
        if let envSecret = ProcessInfo.processInfo.environment["ZCODE_CREDENTIAL_SECRET"], !envSecret.isEmpty {
            return envSecret
        }
        let username = NSUserName()
        let homeDir = NSHomeDirectory()
        return "zcode-credential-fallback:darwin:\(homeDir):\(username)"
    }
    
    static func decodeBase64URL(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
    
    static func decrypt(_ value: String) -> String? {
        guard value.hasPrefix(prefix) else {
            return value
        }
        
        let secretString = getCredentialSecret()
        let secretData = Data(secretString.utf8)
        let hashedKey = SHA256.hash(data: secretData)
        let key = SymmetricKey(data: hashedKey)
        
        let token = String(value.dropFirst(prefix.count))
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3,
              let ivData = decodeBase64URL(parts[0]),
              let tagData = decodeBase64URL(parts[1]),
              let ciphertextData = decodeBase64URL(parts[2]) else {
            return nil
        }
        
        do {
            let nonce = try AES.GCM.Nonce(data: ivData)
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertextData, tag: tagData)
            let decryptedData = try AES.GCM.open(box, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    static func readPlainCredentials() -> [String: String]? {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".zcode/v2/credentials.json")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        
        var result: [String: String] = [:]
        for (key, val) in json {
            if let dec = decrypt(val) {
                result[key] = dec
            }
        }
        return result
    }
}
