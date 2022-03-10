//
//  ShareSaveTagCell.swift
//  Share Extension
//
//  Created by David Sinclair on 2021-07-18.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import UIKit

class ShareSaveTagCell: UITableViewCell {
    @IBOutlet weak var tagLabel: UILabel!
    
    @IBOutlet weak var countLabel: UILabel!
    
    /// The reuse identifier for this table view cell.
    static let reuseIdentifier = "ShareSaveTagCell"
}
