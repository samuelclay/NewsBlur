//
//  VUPinboardActivity.m
//  UIActivityDemo
//
//  Created by Boris Buegling on 29.09.12.
//  Copyright (c) 2012 Boris Buegling. All rights reserved.
//

#import "VUPinboardActivity.h"
#import "VUPinboardViewController.h"

@interface VUPinboardActivity ()

@property (nonatomic, strong) VUPinboardViewController* viewController;

@end

#pragma mark -

@implementation VUPinboardActivity

#pragma mark - Activity information

-(UIImage*)activityImage {
    return [UIImage imageNamed:@"PinboardActivityImage"];
}

-(NSString*)activityTitle {
    return @"Pinboard";
}

-(NSString*)activityType {
    return @"pinboard";
}

-(UIViewController*)activityViewController {
    return self.viewController;
}

#pragma mark - Perform the activity

-(BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
    return activityItems.count >= 1 && [[activityItems lastObject] isKindOfClass:[NSURL class]];
}

-(void)performActivity {
    [self activityDidFinish:NO];
}

-(void)prepareWithActivityItems:(NSArray *)activityItems {
    self.viewController = [[VUPinboardViewController alloc] initWithURL:[activityItems lastObject] activity:self];
}

#pragma mark - 

-(void)presentError:(NSError*)error {
    NSString* msg = [NSString stringWithFormat:@"%@", error.localizedDescription];
    UIAlertView* errorView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"") message:msg delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
    [errorView show];
    
    [self activityDidFinish:NO];
}

@end
