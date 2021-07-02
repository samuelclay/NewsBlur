//
//  ImportExportPreferences.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-01-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// Singleton class to import or export the preferences.
class ImportExportPreferences: NSObject {
    /// Singleton shared instance.
    static let shared = ImportExportPreferences()
    
    /// Private init to prevent others constructing a new instance.
    private override init() {
    }
    
    /// Import the preferences.
    @objc(importFromController:) class func importPreferences(from controller: UIViewController) {
        shared.importPreferences(from: controller)
    }
    
    /// Export the preferences.
    @objc(exportFromController:) class func exportPreferences(from controller: UIViewController) {
        shared.exportPreferences(from: controller)
    }
}

private extension ImportExportPreferences {
    struct Constant {
        static let fileType = "com.newsblur.preferences"
        static let fileName = "NewsBlur Preferences"
        static let fileExtension = "newsblurprefs"
    }
    
    func importPreferences(from controller: UIViewController) {
        
        let picker = UIDocumentPickerViewController(documentTypes: [Constant.fileType], in: .import)
        
        picker.delegate = self
        
        controller.present(picker, animated: true, completion: nil)
    }
    
    func exportPreferences(from controller: UIViewController) {
        let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let prefsURL = temporaryURL.appendingPathComponent(Constant.fileName).appendingPathExtension(Constant.fileExtension)
        let dictionary = UserDefaults.standard.dictionaryRepresentation() as NSDictionary
        
        dictionary.write(to: prefsURL, atomically: true)
        
        let picker: UIDocumentPickerViewController
        
        if #available(iOS 11.0, *) {
            picker = UIDocumentPickerViewController(urls: [prefsURL], in: .exportToService)
        } else {
            picker = UIDocumentPickerViewController(url: prefsURL, in: .exportToService)
        }
        
        controller.present(picker, animated: true, completion: nil)
    }
}

extension ImportExportPreferences: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let dictionary = NSDictionary(contentsOf: url) as? [String : AnyObject] else {
            return
        }
        
        let prefs = UserDefaults.standard
        
        for (key, value) in dictionary {
            prefs.set(value, forKey: key)
        }
        
        NewsBlurAppDelegate.shared()?.reloadFeedsView(true)
    }
}
