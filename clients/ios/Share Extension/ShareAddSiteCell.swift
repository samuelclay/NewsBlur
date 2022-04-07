//
//  ShareAddSiteCell.swift
//  Share Extension
//
//  Created by David Sinclair on 2022-03-10.
//  Copyright © 2022 NewsBlur. All rights reserved.
//

import UIKit

class ShareAddSiteCell: UITableViewCell {
    @IBOutlet weak var folderImageView: UIImageView!
    
    @IBOutlet weak var folderLabel: UILabel!
    
    @IBOutlet weak var folderImageLeadingConstraint: NSLayoutConstraint!
    
    /// The reuse identifier for this table view cell.
    static let reuseIdentifier = "ShareAddSiteCell"
}
