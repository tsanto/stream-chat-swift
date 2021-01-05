//
//  ContentView.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 04/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI
import StreamChat

struct LoginDetails {
    var username: String
    var name: String
}

struct LoginView: View {
    @State var loginDetails: LoginDetails = LoginDetails(username: "luke_skywalker", name: "Luke Skywalker")
    @State var success: Bool = false
    @State var shouldShowErrorAlert: Bool = false
    @State var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                NavigationLink(destination: ContactsListView(), isActive: $success) {
                    EmptyView()
                }
                Form {
                    Section {
                        LoginTextfield(label: "Username", text: $loginDetails.username)
                        LoginTextfield(label: "Name", text: $loginDetails.name)
                        Button("Login", action: logIn)
                    }
                }
            }
            .navigationBarTitle(Text("Authentication"))
            .alert(isPresented: $shouldShowErrorAlert, content: {
                Alert(title: Text("Login Failed!"), message: Text(errorMessage))
            })
        }
    }
    
    func logIn() {
        ChatClient.shared.currentUserController().setUser(
            userId: UserId(loginDetails.username),
            name: loginDetails.name,
            imageURL: URL(string: "https://www.nunovieira.dev/static/media/nv.25e2dde1.jpg"),
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoibHVrZV9za3l3YWxrZXIifQ.kFSLHRB5X62t0Zlc7nwczWUfsQMwfkpylC6jCUZ6Mc0",
            completion: { error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    shouldShowErrorAlert = true
                    return
                }
                success = true
            }
        )
    }
}

struct LoginTextfield: View {
    var label: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text(label).foregroundColor(.gray)
            TextField("", text: $text)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
