//
//  ShareViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 6/21/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@interface ShareViewController : UIViewController <ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;

}

@property (retain, nonatomic) IBOutlet UIImageView *siteFavicon;
@property (retain, nonatomic) IBOutlet UILabel *siteInformation;
@property (retain, nonatomic) IBOutlet UITextView *commentField;
@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;

- (void)setSiteInfo;
- (IBAction)doCancelButton:(id)sender;
- (IBAction)doToggleButton:(id)sender;
- (IBAction)doShareThisStory:(id)sender;



@end
