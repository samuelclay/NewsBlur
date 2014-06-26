//
//  OSKInMemoryImageCache.h
//  Overshare
//
//  Created by Jared Sinclair on 10/22/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;
@import UIKit;

@interface OSKInMemoryImageCache : NSCache

+ (id)sharedInstance;
- (UIImage *)settingsIconMaskImage;

@end
