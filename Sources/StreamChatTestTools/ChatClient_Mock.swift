//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import Foundation
@testable import StreamChat

public extension _ChatClient {
    /// Create a new instance of mock `_ChatClient`
    static func mock() -> _ChatClient {
        var config = ChatClientConfig(apiKey: .init("--== Mock ChatClient ==--"))
        config.isLocalStorageEnabled = false
        
        return .init(config: config, tokenProvider: .development(userId: .anonymous))
    }
}

// ===== TEMP =====

class APIClient_Mock: APIClient {
    override func request<Response>(
        endpoint: Endpoint<Response>,
        completion: @escaping (Result<Response, Error>) -> Void
    ) where Response: Decodable {
        // Do nothing for now
    }
}

class WebSocketClient_Mock: WebSocketClient {
    override func connect() {
        // Do nothing for now
    }
}
