//
//  OSKMessageComposeViewController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/20/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import AssetsLibrary;

#import "OSKMessageComposeViewController.h"
#import "OSKSMSActivity.h"
#import "OSKShareableContentItem.h"

@interface OSKMessageComposeViewController () <MFMessageComposeViewControllerDelegate, UINavigationControllerDelegate>

@property (strong, nonatomic) OSKSMSActivity *activity;

@end

@implementation OSKMessageComposeViewController

@synthesize oskPublishingDelegate = _oskPublishingDelegate;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self setMessageComposeDelegate:self];
    }
    return self;
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result {
    if (result == MessageComposeResultCancelled || result == MessageComposeResultFailed) {
        [self.oskPublishingDelegate publishingViewControllerDidCancel:self withActivity:self.activity];
    } else {
        [self.oskPublishingDelegate publishingViewController:self didTapPublishActivity:self.activity];
    }
}

- (void)preparePublishingViewForActivity:(OSKActivity *)activity delegate:(id <OSKPublishingViewControllerDelegate>)oskPublishingDelegate {
    [self setActivity:(OSKSMSActivity *)activity];
    [self setOskPublishingDelegate:oskPublishingDelegate];
    
    OSKSMSContentItem *smsItem = (OSKSMSContentItem *)activity.contentItem;
    
    [self setBody:smsItem.body];
    [self setRecipients:smsItem.recipients];
    
    for (id attachment in smsItem.attachments) {
        if ([attachment isKindOfClass:[UIImage class]]) {
            UIImage *photo = (UIImage *)attachment;
            NSData *imageData = UIImageJPEGRepresentation(photo, 0.25);
            NSString *fileName = [NSString stringWithFormat:@"Image-%lu.jpg", (unsigned long)[smsItem.attachments indexOfObject:photo]];
            [self addAttachmentData:imageData typeIdentifier:@"image/jpeg" filename:fileName];
        }
    }
}

@end

