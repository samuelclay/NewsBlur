//
//  SwiftUtilities.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-11-04.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation

extension String {
    func deletingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        
        return String(dropFirst(prefix.count))
    }
    
    func deletingSuffix(_ suffix: String) -> String {
        guard hasSuffix(suffix) else {
            return self
        }
        
        return String(dropLast(suffix.count))
    }
}
