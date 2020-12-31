//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import Foundation
import UserNotifications

/// A configuration object used to configure `StreamChatNotificationService` extension.
public struct NotificationExtensionConfig {
    /// The `APIKey` unique for your chat app. This key should be the same one you use for your main app.
    public let apiKey: APIKey
    
    /// The token of the currently logged-in user.
    public let currentUserToken: () -> Token
    
    /// A URL of your app group shared container. In order to make the notification extension work correctly, you need to
    /// use the same local folder for both, your main app and the notification extension.
    public let localStorageFolderURL: URL
    
    public init(
        apiKey: APIKey,
        currentUserToken: @escaping () -> Token,
        localStorageFolderURL: URL
    ) {
        self.apiKey = apiKey
        self.currentUserToken = currentUserToken
        self.localStorageFolderURL = localStorageFolderURL
    }
}

/// A protocol all incoming notifications conform to.
public protocol StreamNotification {}

public typealias MessageNewNotification = _MessageNewNotification<DefaultExtraData>

/// A notification indicating there's a new message in a channel.
public struct _MessageNewNotification<ExtraData: ExtraDataTypes>: StreamNotification {
    /// The channel which contains the new message. `nil` is the extension failed to fetch details about the channel,
    /// most likely due poor network connection.
    public let channel: _ChatChannel<ExtraData>?
    
    /// The new message. `nil` is the extension failed to fetch details about the message, most likely due
    /// poor network connection.
    public let message: _ChatMessage<ExtraData>?
}

public typealias StreamChatNotificationService = _StreamChatNotificationService<DefaultExtraData>

open class _StreamChatNotificationService<ExtraData: ExtraDataTypes>: UNNotificationServiceExtension {
    open var config: NotificationExtensionConfig {
        log.assertationFailure(
            "`NotificationExtensionConfig` is missing. You need to provide `NotificationExtensionConfig` with you custom " +
                "data in your `StreamChatNotificationService` subclass."
        )
        fatalError("Missing `NotificationExtensionConfig` in `StreamChatNotificationService` subclass.")
    }
    
    /// Override this method to provide your customization
    /// - Parameters:
    ///   - notification: <#notification description#>
    ///   - content: <#content description#>
    ///   - contentHandler: <#contentHandler description#>
    /// - Returns: <#description#>
    open func handle(
        notification: StreamNotification,
        content: UNMutableNotificationContent,
        contentHandler: @escaping (UNNotificationContent) -> Void
    ) -> UNNotificationContent? {
        log.assertationFailure(
            "`NotificationExtensionConfig` is missing. You need to provide `NotificationExtensionConfig` with you custom " +
                "data in your `StreamChatNotificationService` subclass."
        )
        fatalError("Missing override")
    }
    
    var bestAttemptContent: UNMutableNotificationContent?
    var contentHandler: ((UNNotificationContent) -> Void)?
    
    lazy var client: _ChatClient<ExtraData> = {
        var clientConfig = ChatClientConfig(apiKey: config.apiKey)
        clientConfig.localStorageFolderURL = config.localStorageFolderURL
        
        let client: _ChatClient<ExtraData> = .init(config: clientConfig, workerBuilders: [], environment: .init())
        
        return client
    }()
    
    override public func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let mutableContent = request.content.mutableCopy() as? UNMutableNotificationContent ?? UNMutableNotificationContent()
        
//        bestAttemptContent = self.handle(notification: <#T##StreamNotification#>, content: mutableContent, contentHandler: contentHandler)
        
//        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
//
//        guard
//            let streamPayload = request.content.userInfo["stream"] as? [String: Any],
//            let messageId = streamPayload["id"] as? String,
//            let cidString = streamPayload["cid"] as? String
//        else {
//            contentHandler(bestAttemptContent!)
//            return
//        }
//
//        do {
//            let messageController = chatClient.messageController(cid: try! ChannelId(cid: cidString), messageId: messageId)
//            messageController.synchronize { _ in
//                self.bestAttemptContent!.title = "New message from: \(messageController.message!.author.name!)"
//                self.bestAttemptContent!.subtitle = messageController.message!.text
//
//                print(messageController.message!.text)
//
//                contentHandler(self.bestAttemptContent!)
//            }
//        }
    }

    override public func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}

struct NotificationPayload: Decodable {
    let id: String
    let cid: String
    let type: String
}
