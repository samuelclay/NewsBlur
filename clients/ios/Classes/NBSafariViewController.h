//
//  NBSafariViewController.h
//  NewsBlur
//
//  Created by David Sinclair on 2015-10-23.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import <SafariServices/SafariServices.h>

@interface NBSafariViewController : SFSafariViewController

@property (nonatomic, strong, readonly) UIView *edgeView;

@end

