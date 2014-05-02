//
//  OSKActivitySheetViewController.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKSession;
@protocol OSKActivitySheetDelegate;

@interface OSKActivitySheetViewController : UIViewController

@property (strong, nonatomic, readonly) OSKSession *session;

- (instancetype)initWithSession:(OSKSession *)session
                     activities:(NSArray *)activities
                       delegate:(id <OSKActivitySheetDelegate>)delegate
               usePopoverLayout:(BOOL)usePopoverLayout;

- (CGFloat)visibleSheetHeightForCurrentLayout;

@end

