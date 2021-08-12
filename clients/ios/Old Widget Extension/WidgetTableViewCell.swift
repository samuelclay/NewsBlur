//
//  WidgetTableViewCell.swift
//  Widget Extension
//
//  Created by David Sinclair on 2019-11-26.
//  Copyright © 2019 NewsBlur. All rights reserved.
//

import UIKit

class WidgetTableViewCell: UITableViewCell {
    /// The reuse identifier for this table view cell.
    static let reuseIdentifier = "WidgetTableViewCell"
    
    @IBOutlet var barView: BarView!
    @IBOutlet var feedImageView: UIImageView!
    @IBOutlet var feedLabel: UILabel!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var contentLabel: UILabel!
    @IBOutlet var authorLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var thumbnailImageView: UIImageView!
    @IBOutlet var thumbnailTrailingConstraint: NSLayoutConstraint!
}
