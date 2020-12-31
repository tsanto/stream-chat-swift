//
//  NotificationService.swift
//  NotificationServiceExtension
//
//  Created by Vojta on 22/12/2020.
//  Copyright © 2020 Stream.io Inc. All rights reserved.
//

import StreamChat
import UserNotifications

class NotificationService: StreamChatNotificationService {
    
    override var config: NotificationExtensionConfig {
        
        let apiKey = APIKey("unqz94tn8ywf")
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoidm9qdGFzdGF2aWsifQ.Y0kUGo37MYCqB5m5MdW-nMELB_UybFpTOyV1Mt7fnkw"
        let groupContainerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.io.getstream.iOS.Sample.Group")!
        
        return .init(
            apiKey: apiKey,
            currentUserToken: { token },
            localStorageFolderURL: groupContainerURL
        )
    }
    
    override func handle(
        notification: StreamNotification,
        content: UNMutableNotificationContent,
        contentHandler: @escaping (UNNotificationContent) -> Void
    ) -> UNNotificationContent? {
        // An example of notification handling:
        switch notification {
        case let notification as MessageNewNotification:
            // Check if we have more info about the new message
            if let messageText = notification.message?.text, let authorName = notification.message?.author.name {
                content.title = "You have a new message from \(authorName)."
                content.subtitle = messageText
                
            } else {
                // Use fallback
                content.title = "You have a new message."
            }
            
        default:
            // A notification without special handling
            content.title = "Check out what's new."
            break
        }
        
        contentHandler(content)
        
        // In case you need to process the notification asynchronously, return the fallback version of the notification
        // from this function. It will be used in case the system calls `serviceExtensionTimeWillExpire()`. Return `nil`
        // if you don't need to process the notification asynchronously.

//        let bestAttemptContent = content
//        bestAttemptContent.title = "Check out what's new."
//        return bestAttemptContent
        
        return nil
    }
}
