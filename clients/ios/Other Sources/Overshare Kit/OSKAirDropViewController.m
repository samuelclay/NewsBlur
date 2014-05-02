//
//  OSKAirDropViewController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/21/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKAirDropViewController.h"

#import "OSKShareableContentItem.h"

@interface OSKAirDropViewController ()

@end

@implementation OSKAirDropViewController

@synthesize oskPublishingDelegate = _oskPublishingDelegate;

- (instancetype)initWithAirDropItem:(OSKAirDropContentItem *)item {
    self = [super initWithActivityItems:item.items applicationActivities:nil];
    if (self) {
        [self setExcludedActivityTypes:@[UIActivityTypePostToFacebook,
                                         UIActivityTypePostToTwitter,
                                         UIActivityTypePostToWeibo,
                                         UIActivityTypeMessage,
                                         UIActivityTypeMail,
                                         UIActivityTypePrint,
                                         UIActivityTypeCopyToPasteboard,
                                         UIActivityTypeAssignToContact,
                                         UIActivityTypeSaveToCameraRoll,
                                         UIActivityTypeAddToReadingList,
                                         UIActivityTypePostToFlickr,
                                         UIActivityTypePostToVimeo,
                                         UIActivityTypePostToTencentWeibo]];
    }
    return self;
}

- (void)preparePublishingViewForActivity:(OSKActivity *)activity delegate:(id<OSKPublishingViewControllerDelegate>)oskPublishingDelegate {
    [self setOskPublishingDelegate:oskPublishingDelegate];
    __weak OSKAirDropViewController *weakSelf = self;
    UIActivityViewControllerCompletionHandler handler = ^(NSString *activityType, BOOL completed){
        // AirDrop always finishes as if it was cancelled, so just dismiss the sheet.
        [weakSelf.oskPublishingDelegate publishingViewController:self didTapPublishActivity:activity];
    };
    [self setCompletionHandler:handler];
}

@end
