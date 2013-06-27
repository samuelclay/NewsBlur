/* Copyright 2012 IGN Entertainment, Inc. */

#import "ReadabilityActivityItem.h"
#import "ReadabilityService.h"

@implementation ReadabilityActivityItem
- (NSString *)activityType
{
    return ReadabilityActivity;
}

- (NSString *)activityTitle
{
    return @"Readability";
}

- (UIImage *)activityImage
{
    return [UIImage imageNamed:@"Readability-Icon"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    return YES;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    // Need to check if image is nil
    // If image item is nil then make a dictionary with only url and title
    // url and title will never be nil as they will just be empty strings if nil was passed in
    NSDictionary *dict = [[NSDictionary alloc] initWithObjects:activityItems forKeys:([activityItems count] == 3) ? @[ @"title",@"url", @"image" ] : @[ @"title",@"url" ]];
    [ReadabilityService shareWithParams:dict onViewController:nil];
}
@end
