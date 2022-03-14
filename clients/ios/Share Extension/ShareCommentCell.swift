//
//  ShareCommentCell.swift
//  Share Extension
//
//  Created by David Sinclair on 2021-07-18.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import UIKit

class ShareCommentCell: UITableViewCell {
    @IBOutlet weak var commentTextView: UITextView!
    
    /// The reuse identifier for this table view cell.
    static let reuseIdentifier = "ShareCommentCell"
}
