//
//  ShareViewDelegate.swift
//  Share Extension
//
//  Created by David Sinclair on 2021-07-18.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import UIKit

class ShareViewDelegate: NSObject {
    @IBOutlet weak var viewController: ShareViewController!
}

extension ShareViewDelegate: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewController.updateSaveButtonState()
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        viewController.updateSaveButtonState()
    }
}

extension ShareViewDelegate: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if viewController.mode == .save {
            return viewController.tags.count + 1
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if viewController.mode == .save {
            if indexPath.item < viewController.tags.count {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: ShareSaveTagCell.reuseIdentifier, for: indexPath) as? ShareSaveTagCell else {
                    preconditionFailure("Expected to dequeue a ShareSaveTagCell")
                }
                
                cell.tagLabel.text = viewController.tags[indexPath.item].name
                
                return cell
            } else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: ShareSaveNewCell.reuseIdentifier, for: indexPath) as? ShareSaveNewCell else {
                    preconditionFailure("Expected to dequeue a ShareSaveNewCell")
                }
                
                cell.tagField.text = ""
                
                return cell
            }
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ShareCommentCell.reuseIdentifier, for: indexPath) as? ShareCommentCell else {
                preconditionFailure("Expected to dequeue a ShareCommentCell")
            }
            
            cell.commentTextView.text = ""
            cell.commentTextView.delegate = self
            
            DispatchQueue.main.async {
                cell.commentTextView.becomeFirstResponder()
            }
            
            return cell
        }
    }
}

extension ShareViewDelegate: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewController.comments = textView.text
    }
}
