//
//  OSKFacebookAudienceChooserViewController.h
//  Overshare
//
//  Created by Jared Sinclair on 10/30/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKFacebookAudienceChooserViewController;

@protocol OSKFacebookAudienceChooserDelegate <NSObject>

- (void)audienceChooser:(OSKFacebookAudienceChooserViewController *)chooser didChooseNewAudience:(NSString *)audience;

@end

@interface OSKFacebookAudienceChooserViewController : UITableViewController

- (id)initWithSelectedAudience:(NSString *)selectedAudience delegate:(id <OSKFacebookAudienceChooserDelegate>)delegate;

@end
