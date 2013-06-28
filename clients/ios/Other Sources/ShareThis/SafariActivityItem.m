/* Copyright 2012 IGN Entertainment, Inc. */

#import "SafariActivityItem.h"
#import "SafariService.h"

@implementation SafariActivityItem
- (NSString *)activityType
{
    return SafariActivity;
}

- (NSString *)activityTitle
{
    return @"Safari";
}

- (UIImage *)activityImage
{
    return [UIImage imageNamed:@"UIActivitySafari.png"];
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
    NSDictionary *dict = [[NSDictionary alloc] initWithObjects:activityItems forKeys:([activityItems count] == 3) ? @[@"title",@"url", @"image"] : @[@"title",@"url"]];
    [SafariService shareWithParams:dict onViewController:nil];
}
@end
