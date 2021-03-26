//
//  FeedsViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

///Sidebar listing all of the feeds.
class FeedsViewController: FeedsObjCViewController {
    var loadWorkItem: DispatchWorkItem?
    
    @objc func loadNotificationStory() {
        loadWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else {
                return
            }
            
            self.backgroundLoadNotificationStory()
        }
        
        loadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + (isOffline ? .seconds(1) : .milliseconds(100)), execute: workItem)
    }
}
