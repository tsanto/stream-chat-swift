//
//  ChatClient+shared.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 05/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import Foundation
import StreamChat

extension ChatClient {
    static let shared: ChatClient = {
        var config = ChatClientConfig(apiKey: APIKey("8br4watad788"))
        config.baseURL = BaseURL.usEast
        return ChatClient(config: config)
    }()
}
