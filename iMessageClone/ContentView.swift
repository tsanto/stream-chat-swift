//
//  ContentView.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 04/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI
import StreamChat

struct ContentView: View {
    @State
    private var username: String = "luke_skywalker"
    @State
    private var shouldShowSuccessAlert: Bool = false
    @State
    private var shouldShowErrorAlert: Bool = false
    @State
    private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Username", text: $username)
                    Button("Login", action: logIn)
                }
            }
            .navigationBarTitle(Text("Authentication"))
            .alert(isPresented: $shouldShowSuccessAlert, content: {
                Alert(title: Text("Logged In!"))
            })
            .alert(isPresented: $shouldShowErrorAlert, content: {
                Alert(title: Text("Login Failed!"), message: Text(errorMessage))
            })
        }
    }
    
    func logIn() {
        LogConfig.formatters = [
            PrefixLogFormatter(prefixes: [.info: "ℹ️", .debug: "🛠", .warning: "⚠️", .error: "🚨"]),
        ]
        LogConfig.level = .warning
        
        var config = ChatClientConfig(apiKey: APIKey("8br4watad788"))
        config.baseURL = BaseURL.usEast
        let chatClient = ChatClient(config: config)
        let currentUserController = chatClient.currentUserController()
        
        currentUserController.setUser(
            userId: UserId(username),
            name: "Luke Skywalker",
            imageURL: nil,
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibHVrZV9za3l3YWxrZXIifQ.kFSLHRB5X62t0Zlc7nwczWUfsQMwfkpylC6jCUZ6Mc0",
            completion: { error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    shouldShowErrorAlert = true
                    return
                }
                shouldShowSuccessAlert = true
            }
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
