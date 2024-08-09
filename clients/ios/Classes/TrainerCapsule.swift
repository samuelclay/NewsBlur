//
//  TrainerCapsule.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-04-02.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

struct TrainerCapsule: View {
    var score: Feed.Score
    
    var header: String
    
    var image: UIImage?
    
    var value: String
    
    var count: Int = 0
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: score.imageName)
                    .foregroundColor(.white)
                
                content
            }
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 10)
            .background(score == .like ? Color(red: 0, green: 0.5, blue: 0.0) : score == .dislike ? Color.red : Color(white: ThemeManager.shared.isSystemDark ? 0.35 : 0.6))
            .clipShape(Capsule())
            
            if count > 0 {
                Text("x \(count)")
                    .colored(.gray)
                    .padding([.trailing], 10)
            }
        }
    }
    
    var content: Text {
        Text("\(Text("\(header):").colored(.init(white: 0.85))) \(imageText)\(value)")
                .colored(.white)
    }
    
    var imageText: Text {
        if let image {
            Text(Image(uiImage: image)).baselineOffset(-3) + Text(" ")
        } else {
            Text("")
        }
    }
}

#Preview {
    TrainerCapsule(score: .none, header: "Tag", value: "None Example")
}

#Preview {
    TrainerCapsule(score: .like, header: "Tag", value: "Liked Example")
}

#Preview {
    TrainerCapsule(score: .dislike, header: "Tag", value: "Disliked Example")
}
