//
//  ReadabilityActivity.m
//
//  Created by Brendan Lynch on 12-09-20.
//  Copyright (c) 2012 Readability LLC. All rights reserved.
//

#import "ReadabilityActivity.h"

static NSString * const ReadabilityActivityURI = @"readability://";
static NSString * const ReadabilityActivityAdd = @"add";

@implementation ReadabilityActivity

- (NSString *)activityType
{
    return @"UIActivityReadability";
}

- (NSString *)activityTitle
{
    return @"Readability";
}

- (UIImage *)activityImage {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return [UIImage imageNamed:@"Readability-activity-iPad"];
    }
    
    return [UIImage imageNamed:@"Readability-activity-iPhone"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    if (![ReadabilityActivity canPerformActivity]) {
        return NO;
    }
    for (NSObject *item in activityItems) {
        if (![item isKindOfClass:[NSURL class]] && ![item isKindOfClass:[NSString class]]) {
            return NO;
        }
    }
    return YES;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    _activityItems = activityItems;
}

- (void)performActivity {
    if ([ReadabilityActivity canPerformActivity]){
        NSString *activityURL = nil;
        
        if([_activityItems[0] isKindOfClass:[NSURL class]]) {
            activityURL = [_activityItems[0] absoluteString];
            
        } else {
            activityURL = _activityItems[0];
        }
        
        NSString *readabilityURLString = [NSString stringWithFormat:@"%@%@/%@", ReadabilityActivityURI, ReadabilityActivityAdd, activityURL];
        
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:readabilityURLString]];
        [self activityDidFinish:YES];
    } else{
        [self activityDidFinish:NO];
    }
}

+ (BOOL)canPerformActivity {
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:ReadabilityActivityURI]])
    {
        return YES;
    }
    
    return NO;
}

@end