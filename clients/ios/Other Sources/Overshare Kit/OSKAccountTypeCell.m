//
//  OSKAccountTypeself.m
//  Overshare
//
//  Created by Jared Sinclair 10/30/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKAccountTypeCell.h"

#import "OSKInMemoryImageCache.h"
#import "OSKActivity.h"
#import "OSKPresentationManager.h"
#import "OSKManagedAccountStore.h"
#import "OSKManagedAccount.h"
#import "OSKActivity_GenericAuthentication.h"

NSString * const OSKAccountTypeCellIdentifier = @"OSKAccountTypeCellIdentifier";

static UIBezierPath *clippingPath;

@interface OSKAccountTypeCell()

@property (copy, nonatomic) NSString *imageKey;
@property (strong, nonatomic) OSKActivity <OSKActivity_GenericAuthentication> *genericActivity;

@end

@implementation OSKAccountTypeCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
        OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
        UIColor *bgColor = [presentationManager color_groupedTableViewCells];
        self.backgroundColor = bgColor;
        self.backgroundView.backgroundColor = bgColor;
        self.textLabel.textColor = [presentationManager color_text];
        self.detailTextLabel.textColor = [presentationManager color_hashtags];
        UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
        if (descriptor) {
            [self.textLabel setFont:[UIFont fontWithDescriptor:descriptor size:16]];
            [self.detailTextLabel setFont:[UIFont fontWithDescriptor:descriptor size:12]];
        } else {
            [self.textLabel setFont:[UIFont systemFontOfSize:16]];
            [self.detailTextLabel setFont:[UIFont systemFontOfSize:12]];
        }
        self.selectedBackgroundView = [[UIView alloc] initWithFrame:self.bounds];
        self.selectedBackgroundView.backgroundColor = presentationManager.color_cancelButtonColor_BackgroundHighlighted;
        self.tintColor = presentationManager.color_action;
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.imageView.image = [UIImage imageNamed:@"osk-settingsPlaceholder.png"]; // fixes UIKit bug.
    }
    return self;
}

- (void)setActivityClass:(Class)activityClass {
    if ([_activityClass isEqual:activityClass] == NO) {
        _activityClass = activityClass;
        NSString *name = [activityClass activityName];
        [self.textLabel setText:name];
        [self updateIcon:activityClass];
    }
    OSKAuthenticationMethod method = [_activityClass authenticationMethod];
    if (method == OSKAuthenticationMethod_ManagedAccounts) {
        [self setGenericActivity:nil];
        [self updateExistingAccountsDescription];
    }
    else if (method == OSKAuthenticationMethod_Generic) {
        _genericActivity = [[_activityClass alloc] initWithContentItem:nil];
        [self updateGenericAccountDescription];
    }
}

- (void)updateExistingAccountsDescription {
    NSArray *accounts = [[OSKManagedAccountStore sharedInstance] accountsForActivityType:[_activityClass activityType]];
    NSMutableString *detailText = nil;
    if (accounts.count) {
        detailText = [[NSMutableString alloc] init];
        for (OSKManagedAccount *account in accounts) {
            [detailText appendString:[account nonNilDisplayName]];
            if (account != accounts.lastObject) {
                [detailText appendFormat:@", "];
            }
        }
    }
    [self.detailTextLabel setText:detailText];
}

- (void)updateGenericAccountDescription {
    if ([_genericActivity isAuthenticated]) {
        [self.detailTextLabel setText:@"Connected"];
    } else {
        [self.detailTextLabel setText:nil];
    }
}

- (void)maskImage:(UIImage *)image completion:(void(^)(UIImage *maskedImage))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(29.0f, 29.0f), NO, 0);
        if (clippingPath == nil) {
            clippingPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 29, 29) cornerRadius:6.5f];
        }
        [clippingPath addClip];
        [image drawInRect:CGRectMake(0, 0, 29.0f, 29.0f)];
        UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(result);
            }
        });
    });
}

- (NSString *)keyForActivityType:(NSString *)type {
    return [NSString stringWithFormat:@"%@_settings", type];
}

- (void)updateIcon:(Class)activityClass {
    NSString *imageKey = [self keyForActivityType:[activityClass activityType]];
    if ([_imageKey isEqualToString:imageKey] == NO) {
        
        [self setImageKey:imageKey];
        
        UIImage *cachedImage = [[OSKInMemoryImageCache sharedInstance] objectForKey:imageKey];
        
        if (cachedImage) {
            [self.imageView setImage:cachedImage];
        } else {
            UIImage *settingsIcon = [activityClass settingsIcon];
            if (settingsIcon == nil) {
                settingsIcon = [[OSKInMemoryImageCache sharedInstance] settingsIconMaskImage];
            }

            __weak OSKAccountTypeCell *weakSelf = self;
            [self maskImage:settingsIcon completion:^(UIImage *maskedImage) {
                if ([weakSelf.imageKey isEqualToString:imageKey]) { // May have changed during processing
                    [weakSelf.imageView setImage:maskedImage];
                    [[OSKInMemoryImageCache sharedInstance] setObject:maskedImage forKey:imageKey];
                }
            }];
        }
    }
}

@end





