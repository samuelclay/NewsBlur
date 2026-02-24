//
//  PreviewViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-08-23.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import UIKit
import QuickLook

class PreviewViewController: QLPreviewController, QLPreviewControllerDelegate, QLPreviewControllerDataSource {
    @objc(saveImage:withFilename:) func save(image: UIImage, with name: String) -> Bool {
        let filename = "\(name).jpg"
        
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(filename)
        
        guard let data = image.jpegData(compressionQuality: 1.0),
              (try? data.write(to: destinationURL)) != nil else {
            return false
        }
        
        self.previewItem.previewItemURL = destinationURL;
        self.previewItem.previewItemTitle = filename;
        
        return true
    }
    
    private var previewItem = PreviewItem()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.dataSource = self;
        
        self.title = previewItem.previewItemTitle;
    }
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return previewItem.previewItemURL == nil ? 0 : 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return previewItem
    }
}

class PreviewItem: NSObject, QLPreviewItem {
    var previewItemURL: URL?
    var previewItemTitle: String?
}
