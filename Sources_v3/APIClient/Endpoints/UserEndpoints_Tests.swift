//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

@testable import StreamChatClient
import XCTest

final class UserEndpoints_Tests: XCTestCase {
    func test_users_buildsCorrectly() {
        let query: UserListQuery = .init(
            filter: .contains("name", "a"),
            sort: [.init(key: .lastActiveAt)],
            pagination: [.offset(3)]
        )
        
        let expectedEndpoint = Endpoint<UserListPayload<DefaultExtraData.User>>(
            path: "users",
            method: .get,
            queryItems: nil,
            requiresConnectionId: true,
            body: ["payload": query]
        )
        
        // Build endpoint
        let endpoint: Endpoint<UserListPayload<DefaultExtraData.User>> = .users(query: query)
        
        // Assert endpoint is built correctly
        XCTAssertEqual(AnyEndpoint(expectedEndpoint), AnyEndpoint(endpoint))
    }
}