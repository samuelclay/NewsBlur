//
//  ShareViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/21/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface ShareViewController : UIViewController {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;

- (IBAction)doCancelButton:(id)sender;

@end
