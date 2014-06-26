//
//  OSKAirDropViewController.h
//  Overshare
//
//  Created by Jared Sinclair on 10/21/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;
#import "OSKPublishingViewController.h"

@class OSKAirDropContentItem;

@interface OSKAirDropViewController : UIActivityViewController <OSKPublishingViewController>

- (instancetype)initWithAirDropItem:(OSKAirDropContentItem *)item;

@end
