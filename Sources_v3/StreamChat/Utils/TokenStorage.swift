//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import Foundation
import KeychainSwift

class KeychainTokenStorage {
    private let keychain: KeychainSwift

    init(accessGroup: String?) {
        keychain = KeychainSwift()
        keychain.accessGroup = accessGroup
    }

    var token: Token? {
        get { keychain.get(.tokenKey) }
        set {
            if let newToken = newValue {
                keychain.set(newToken, forKey: .tokenKey)
            } else if token != nil {
                keychain.delete(.tokenKey)
            }
            checkKeychainForError()
        }
    }

    private func checkKeychainForError() {
        guard keychain.lastResultCode != noErr else { return }

        log.assertationFailure(
            "Error happened when working with keychain. Error code: \(keychain.lastResultCode)"
        )
    }
}

private extension String {
    static let tokenKey = "token"
}
