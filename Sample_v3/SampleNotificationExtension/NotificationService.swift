//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UserNotifications

class NotificationService: StreamChatNotificationService<DefaultExtraData> {
    override var chatClient: _ChatClient<DefaultExtraData> {
        var config = ChatClientConfig(apiKeyString: "unqz94tn8ywf")
        config.localStorageFolderURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.io.getstream.iOS.Sample.Group")!

        let client = _ChatClient<DefaultExtraData>(config: config, tokenProvider: .closure { client, completion in
            guard let loggedInUserId = client.currentUserId else {
                // No currently logged in user, use anonymous user instead.
                // This might be a bug! Make sure to remove user device tokens when logging our the user.
                completion(.success(.anonymous))
                return
            }

            // Find the matching token for the logged in user
            if let token = Configuration.TestUser.defaults.first(where: { $0.id == loggedInUserId })?.token {
                completion(.success(token))
            } else {
                // No token for the currently logged in user
                completion(.failure(ClientError.MissingToken()))
            }
        })

        return client
    }
}
