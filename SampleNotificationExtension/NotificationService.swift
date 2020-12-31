//
//  NotificationService.swift
//  NotificationServiceExtension
//
//  Created by Vojta on 22/12/2020.
//  Copyright © 2020 Stream.io Inc. All rights reserved.
//

import StreamChat
import UserNotifications

class NotificationService: StreamChatNotificationService<DefaultExtraData> {
    
    override var chatClient: _ChatClient<DefaultExtraData> {
        var config = ChatClientConfig(apiKeyString: "unqz94tn8ywf")
        config.localStorageFolderURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.io.getstream.iOS.Sample.Group")!
                
        let client = _ChatClient<DefaultExtraData>(config: config)
        
        client.currentUserController()
            .setUser(
                userId: "vojtastavik",
                name: nil,
                imageURL: nil,
                token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoidm9qdGFzdGF2aWsifQ.Y0kUGo37MYCqB5m5MdW-nMELB_UybFpTOyV1Mt7fnkw"
            )
        
        return client
    }
}
