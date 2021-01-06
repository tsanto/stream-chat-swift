//
//  ChannelListCell.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 06/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI

struct ChannelListCell: View {
    var item: ChannelListItem
    
    var body: some View {
        HStack(spacing: 12){
            RemoteImage(withURL: item.imageUrl)
                .frame(width: 55, height: 55)
                .cornerRadius(50)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.name).bold()
                    Spacer()
                    Text(item.date)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding()
                }.frame(height: 30)
                
                Text(item.msg)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer(minLength: 0)
        }.padding(.vertical)
    }
}

struct ChannelListCell_Previews: PreviewProvider {
    static var previews: some View {
        ChannelListCell(
            item: ChannelListItem(
                name: "Nuno Vieira",
                msg: "Hello world!",
                date: "23 days ago",
                imageUrl: nil
            )
        ).previewLayout(.sizeThatFits)
    }
}
