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
                .colored(Color.themed([0x1A1A1A, 0x3C3226, 0xCCCCCC, 0xCCCCCC]))
                .padding([.top, .bottom], 1)
            .padding([.leading, .trailing], 1)
            .background(Color.themed([0xF2F2F2, 0xEADFD0, 0x595959, 0x595959]))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }
}

#Preview {
    TrainerWord(word: "Example")
}
