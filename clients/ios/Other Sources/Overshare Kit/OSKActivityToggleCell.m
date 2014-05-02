//
//  OSKActivityToggleCell.m
//  Overshare
//
//  Created by Jared Sinclair on 10/30/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKActivityToggleCell.h"

#import "OSKPresentationManager.h"
#import "OSKActivity.h"
#import "OSKActivitiesManager.h"
#import "OSKInMemoryImageCache.h"

NSString * const OSKActivityToggleCellIdentifier = @"OSKActivityToggleCellIdentifier";

static UIBezierPath *clippingPath;

@interface OSKActivityToggleCell ()

@property (copy, nonatomic) NSString *imageKey;
@property (strong, nonatomic) UISwitch *toggle;

@end

@implementation OSKActivityToggleCell

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
            [self.detailTextLabel setFont:[UIFont fontWithDescriptor:descriptor size:11]];
        } else {
            [self.textLabel setFont:[UIFont systemFontOfSize:16]];
            [self.detailTextLabel setFont:[UIFont systemFontOfSize:11]];
        }
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.tintColor = presentationManager.color_action;
        self.imageView.image = [UIImage imageNamed:@"osk-settingsPlaceholder.png"]; // fixes UIKit bug.
        _toggle = [[UISwitch alloc] init];
        [_toggle setTintColor:presentationManager.color_pageIndicatorColor_other];
        [_toggle setOnTintColor:presentationManager.color_action];
        [_toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        self.accessoryView = _toggle;
    }
    return self;
}

- (void)setActivityClass:(Class)activityClass {
    if ([_activityClass isEqual:activityClass] == NO) {
        _activityClass = activityClass;
        NSString *name = [_activityClass activityName];
        [self.textLabel setText:name];
        [self updateIcon:_activityClass];
    }
    BOOL activityEnabled = ![[OSKActivitiesManager sharedInstance] activityTypeIsAlwaysExcluded:[_activityClass activityType]];
    [self.toggle setOn:activityEnabled];
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
            
            __weak OSKActivityToggleCell *weakSelf = self;
            [self maskImage:settingsIcon completion:^(UIImage *maskedImage) {
                if ([weakSelf.imageKey isEqualToString:imageKey]) { // May have changed during processing
                    [weakSelf.imageView setImage:maskedImage];
                    [[OSKInMemoryImageCache sharedInstance] setObject:maskedImage forKey:imageKey];
                }
            }];
        }
    }
}

- (void)toggleChanged:(UISwitch *)toggle {
    BOOL enabled = ![toggle isOn];
    [[OSKActivitiesManager sharedInstance] markActivityTypes:@[[_activityClass activityType]] alwaysExcluded:enabled];
}

@end
