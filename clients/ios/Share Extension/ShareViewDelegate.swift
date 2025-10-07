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
        if viewController.mode == .add, indexPath.section == 0 {
            viewController.selectedFolderIndexPath = indexPath
            tableView.reloadData()
        }
        
        viewController.updateSaveButtonState()
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        viewController.updateSaveButtonState()
    }
}

extension ShareViewDelegate: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        if viewController.mode == .add {
            return 2
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if viewController.mode == .add, section == 1 {
            return "Add new sub-folder:"
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewController.mode {
        case .save:
            return viewController.tags.count + 1
        case .share:
            return 1
        case .add:
            if section == 0 {
                return viewController.folders.count
            } else {
                return 1
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if viewController.mode == .save {
            if indexPath.item < viewController.tags.count {
                return makeSaveTagCell(for: tableView, indexPath: indexPath)
            } else {
                return makeSaveNewCell(for: tableView, indexPath: indexPath, name: "", placeholder: "new tag")
            }
        } else if viewController.mode == .add {
            if indexPath.section == 0 {
                return makeAddSiteCell(for: tableView, indexPath: indexPath)
            } else {
                return makeSaveNewCell(for: tableView, indexPath: indexPath, name: viewController.newFolder, placeholder: "new tag")
            }
        } else {
            return makeShareCommentCell(for: tableView, indexPath: indexPath)
        }
    }
}

private extension ShareViewDelegate {
    func makeSaveTagCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ShareSaveTagCell.reuseIdentifier, for: indexPath) as? ShareSaveTagCell else {
            preconditionFailure("Expected to dequeue a ShareSaveTagCell")
        }
        
        let tag = viewController.tags[indexPath.item]
        
        cell.tagLabel.text = tag.name
        cell.countLabel.text = "\(tag.count)"
        
        return cell
    }
    
    func makeSaveNewCell(for tableView: UITableView, indexPath: IndexPath, name: String, placeholder: String) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ShareSaveNewCell.reuseIdentifier, for: indexPath) as? ShareSaveNewCell else {
            preconditionFailure("Expected to dequeue a ShareSaveNewCell")
        }
        
        cell.tagField.text = name
        cell.tagField.placeholder = placeholder
        
        return cell
    }
    
    func makeAddSiteCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ShareAddSiteCell.reuseIdentifier, for: indexPath) as? ShareAddSiteCell else {
            preconditionFailure("Expected to dequeue a ShareAddSiteCell")
        }
        
        let components = viewController.folders[indexPath.item].components(separatedBy: " ▸ ")
        
        if components.first == "everything" {
            cell.folderImageView.image = UIImage(named: "all-stories")
            cell.folderLabel.text = "Top Level"
            cell.folderImageLeadingConstraint.constant = 20
        } else {
            cell.folderImageView.image = UIImage(named: "g_icn_folder.png")
            cell.folderLabel.text = components.last ?? "?"
            cell.folderImageLeadingConstraint.constant = 20 + CGFloat(components.count * 35)
        }
        
        cell.accessoryType = indexPath == viewController.selectedFolderIndexPath ? .checkmark : .none
        
        return cell
    }
    
    func makeShareCommentCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
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

extension ShareViewDelegate: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewController.comments = textView.text
    }
}
