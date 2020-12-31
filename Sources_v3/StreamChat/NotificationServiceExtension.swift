//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import UserNotifications

open class StreamChatNotificationService<ExtraData: ExtraDataTypes>: UNNotificationServiceExtension {
    open var chatClient: _ChatClient<ExtraData> {
        fatalError("You need to provide a valid ChatClient in your subclass.")
    }
    
    var bestAttemptContent: UNMutableNotificationContent?
    var contentHandler: ((UNNotificationContent) -> Void)?
    
    override public func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard
            let streamPayload = request.content.userInfo["stream"] as? [String: Any],
            let messageId = streamPayload["id"] as? String,
            let cidString = streamPayload["cid"] as? String
        else {
            contentHandler(bestAttemptContent!)
            return
        }

        do {
            let messageController = chatClient.messageController(cid: try! ChannelId(cid: cidString), messageId: messageId)
            messageController.synchronize { _ in
                self.bestAttemptContent!.title = "New message from: \(messageController.message!.author.name!)"
                self.bestAttemptContent!.subtitle = messageController.message!.text
                
                print(messageController.message!.text)
                
                contentHandler(self.bestAttemptContent!)
            }
        }
    }

    override public func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}

import Foundation

struct NotificationPayload: Decodable {
    let id: String
    let cid: String
    let type: String
}
