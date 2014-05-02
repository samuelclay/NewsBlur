//
//  OSKMailComposeViewController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/20/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKMailComposeViewController.h"

#import "OSKEmailActivity.h"
#import "OSKShareableContentItem.h"

@interface OSKMailComposeViewController () <MFMailComposeViewControllerDelegate, UINavigationControllerDelegate>

@property (strong, nonatomic) OSKEmailActivity *activity;

@end

@implementation OSKMailComposeViewController

@synthesize oskPublishingDelegate = _oskPublishingDelegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self setMailComposeDelegate:self];
    }
    return self;
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    if (result == MFMailComposeResultCancelled || result == MFMailComposeResultFailed) {
        [self.oskPublishingDelegate publishingViewControllerDidCancel:self withActivity:self.activity];
    } else {
        [self.oskPublishingDelegate publishingViewController:self didTapPublishActivity:self.activity];
    }
}

- (void)preparePublishingViewForActivity:(OSKActivity *)activity delegate:(id <OSKPublishingViewControllerDelegate>)oskPublishingDelegate {
    [self setActivity:(OSKEmailActivity *)activity];
    [self setOskPublishingDelegate:oskPublishingDelegate];
    
    [self setActivity:(OSKEmailActivity *)activity];
    [self setOskPublishingDelegate:oskPublishingDelegate];
    
    OSKEmailContentItem *emailItem = (OSKEmailContentItem *)activity.contentItem;
    
    [self setSubject:emailItem.subject];
    [self setMessageBody:emailItem.body isHTML:emailItem.isHTML];
    [self setToRecipients:emailItem.toRecipients];
    [self setCcRecipients:emailItem.ccRecipients];
    [self setBccRecipients:emailItem.bccRecipients];
    
    for (id attachment in emailItem.attachments) {
        if ([attachment isKindOfClass:[UIImage class]]) {
            UIImage *photo = (UIImage *)attachment;
            NSData *imageData = UIImageJPEGRepresentation(photo, 0.25);
            NSString *fileName = [NSString stringWithFormat:@"Image-%lu.jpg", (unsigned long)[emailItem.attachments indexOfObject:photo]];
            [self addAttachmentData:imageData mimeType:@"image/jpeg" fileName:fileName];
        }
    }
}

@end






