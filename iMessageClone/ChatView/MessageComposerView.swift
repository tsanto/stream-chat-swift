//
//  MessageComposerView.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 06/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI

struct MessageComposerView: View {
    @Binding var typingMessage: String
    var action: () -> Void
    
    var body: some View {
        HStack {
            TextField("Message...", text: $typingMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minHeight: CGFloat(30))
            Button(action: action) {
                Text("Send")
            }.disabled(typingMessage.isEmpty)
        }.frame(minHeight: CGFloat(50)).padding()
    }
}

struct MessageComposerView_Previews: PreviewProvider {
    
    @State private static var message: String = "Hello!"
    @State private static var emptyMessage: String = ""
    
    static var previews: some View {
        Group {
            MessageComposerView(typingMessage: $message, action: {})
                .previewLayout(.sizeThatFits)
            MessageComposerView(typingMessage: $emptyMessage, action: {})
                .previewLayout(.sizeThatFits)
        }
    }
}
