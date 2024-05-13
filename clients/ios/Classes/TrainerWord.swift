//
//  TrainerWord.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-04-03.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

struct TrainerWord: View {
    var word: String
    
    var body: some View {
        HStack {
            Text(word)
                .colored(Color(white: ThemeManager.shared.isSystemDark ? 0.8 : 0.1))
                .padding([.top, .bottom], 1)
            .padding([.leading, .trailing], 1)
            .background(Color(white: ThemeManager.shared.isSystemDark ? 0.35 : 0.95))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }
}

#Preview {
    TrainerWord(word: "Example")
}
