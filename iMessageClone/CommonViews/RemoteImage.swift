//
//  RemoteImage.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 05/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import Combine
import SwiftUI

struct RemoteImage: View {
    @ObservedObject var imageLoader: ImageLoader
    @State private var image: UIImage = UIImage()
    
    init(withURL url: URL?) {
        imageLoader = ImageLoader(url: url)
    }
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .background(Color(.lightGray).opacity(0.2))
            .onReceive(imageLoader.dataPublisher) { data in
                self.image = UIImage(data: data) ?? UIImage()
            }
    }
}

class ImageLoader: ObservableObject {
    var dataPublisher = PassthroughSubject<Data, Never>()
    var data = Data() {
        didSet {
            dataPublisher.send(data)
        }
    }
    
    init(url: URL?) {
        guard let url = url else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { return }
            DispatchQueue.main.async {
                self.data = data
            }
        }
        task.resume()
    }
}

struct RemoteImage_Previews: PreviewProvider {
    static var previews: some View {
        RemoteImage(
            withURL: URL(string: "https://www.nunovieira.dev/static/media/nv.25e2dde1.jpg")
        )
        .frame(width:100, height:100)
        .cornerRadius(50)
    }
}
