//
//  PocketAPIActivity.m
//  ThinkSocial
//
//  Created by David Beck on 12/1/12.
//  Copyright (c) 2012 ThinkUltimate. All rights reserved.
//

#import "PocketAPIActivity.h"

#import "PocketAPI.h"


@implementation PocketAPIActivity
{
	NSArray *_URLs;
}

- (NSString *)activityType
{
	return @"Pocket";
}

- (NSString *)activityTitle
{
	return NSLocalizedString(@"Pocket", nil);
}

- (UIImage *)activityImage
{
	return [UIImage imageNamed:@"PocketActivity.png"];
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
	for (id activityItem in activityItems) {
		if ([activityItem isKindOfClass:[NSURL class]]) {
            return YES;
			NSURL *pocketURL = [NSURL URLWithString:[[PocketAPI pocketAppURLScheme] stringByAppendingString:@":test"]];
			NSLog(@"In here");
            NSLog(@"%@", pocketURL.description);
            if ([[UIApplication sharedApplication] canOpenURL:pocketURL]) {
				return YES;
			}
		}
	}
	return NO;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
	NSMutableArray *URLs = [NSMutableArray array];
	
	for (id activityItem in activityItems) {
		if ([activityItem isKindOfClass:[NSURL class]]) {
			[URLs addObject:activityItem];
		}
	}
	[_URLs release];
	_URLs = [URLs copy];
}

- (void)performActivity
{
    if (![PocketAPI sharedAPI].loggedIn)
    {
        [[PocketAPI sharedAPI] loginWithHandler: ^(PocketAPI *API, NSError *error)
        {
            if (error != nil)
            {
                // Handle error here
                NSLog(@"Error! Error Will Robinson!");
            }
            else
            {
                [self performActivity];
                return;
            }
        }];
    }
    else
    {
        __block NSUInteger URLsLeft = _URLs.count;
        __block BOOL URLFailed = NO;
        
        for (NSURL *URL in _URLs)
        {
            [[PocketAPI sharedAPI] saveURL:URL handler: ^(PocketAPI *API, NSURL *URL, NSError *error)
            {
                if (error != nil)
                {
                    URLFailed = YES;
                }
                URLsLeft--;
                if (URLsLeft == 0)
                {
                    [self activityDidFinish:!URLFailed];
                }
            }];
        }
    }
}

- (void) activityDidFinish:(BOOL)completed
{
    [super activityDidFinish:completed];
    if (completed)
    {
        // Show you successfully saved the article
        NSLog(@"Finished successfully");
    }
    else
    {
        // Show an error
        NSLog(@"Error");
    }
}

- (void)dealloc
{
	[_URLs release];
	[super dealloc];
}

@end
