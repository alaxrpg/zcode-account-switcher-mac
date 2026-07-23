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

    // MARK: - Encryption (mirror of decrypt, same key derivation)

    static func encodeBase64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Encrypt arbitrary plaintext using the SAME key derivation as ZCode's
    /// credential store (secret = env or darwin fallback → SHA256 → AES-256-GCM).
    /// Output format mirrors `enc:v1:` so it can only be decrypted back on this
    /// machine by the same secret.
    static func encrypt(_ plaintext: String) -> String? {
        let secretString = getCredentialSecret()
        let secretData = Data(secretString.utf8)
        let hashedKey = SHA256.hash(data: secretData)
        let key = SymmetricKey(data: hashedKey)

        do {
            let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: key)
            // AES.GCM.SealedBox lays out combined = nonce(12) || ciphertext || tag(16),
            // but sealed.combined already concatenates nonce+ct+tag. We want iv.tag.ct
            // to mirror the decrypt() side, so build it explicitly.
            guard let combined = sealed.combined else { return nil }
            // combined = nonce(12) || ciphertext || tag(16)
            let iv = combined.prefix(12)
            let tag = combined.suffix(16)
            let ciphertext = combined.dropFirst(12).dropLast(16)
            return prefix + encodeBase64URL(iv) + "." + encodeBase64URL(Data(tag)) + "." + encodeBase64URL(Data(ciphertext))
        } catch {
            return nil
        }
    }

    /// Decrypt a string produced by encrypt() (or ZCode's own enc:v1: format).
    /// Convenience wrapper returning Data for file payloads.
    static func decryptToData(_ value: String) -> Data? {
        guard let plain = decrypt(value) else { return nil }
        return Data(plain.utf8)
    }
}
