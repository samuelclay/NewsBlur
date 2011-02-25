//
//  Controller.m
//  Reader Helper
//
//  Created by Geoff Hulette on 7/28/08.
//  Copyright 2008 Collidescope. All rights reserved.
//

#import "Controller.h"

@implementation Controller

- (id)init
{
	self = [super init];
	if(self) {
		//NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/ReaderHelperDebug.log"];
		//freopen([logPath fileSystemRepresentation], "a", stderr);
		
		NSAppleEventManager *manager = [NSAppleEventManager sharedAppleEventManager];
		if(manager) {
			[manager setEventHandler:self
						 andSelector:@selector(handleOpenLocationAppleEvent:withReplyEvent:)
					   forEventClass:'GURL'
						  andEventID:'GURL'];
		}
	}
	return self;
}


/*
 * Borrowed more-or-less verbatim from reader-notifier
 */
- (void)handleOpenLocationAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)reply
{
    NSAppleEventDescriptor *descriptor = [event paramDescriptorForKeyword:keyDirectObject];
    if(descriptor) {
		NSString *urlString = [descriptor stringValue];
		if(urlString) {
			NSScanner *scanner = [NSScanner scannerWithString:urlString];
			
			NSString *urlPrefix;
			[scanner scanUpToString:@":" intoString:&urlPrefix];
			[scanner scanString:@":" intoString:nil];
			if ([urlPrefix isEqualToString:@"feed"]) {
				NSString *feedScheme = nil;
				[scanner scanString:@"//" intoString:nil];
				[scanner scanString:@"http:" intoString:&feedScheme];
				[scanner scanString:@"https:" intoString:&feedScheme];
				[scanner scanString:@"//" intoString:nil];
				if(feedScheme == nil) {
					feedScheme = @"http:";
				}
			 
				NSString *linkPath;
				[scanner scanUpToString:@"" intoString:&linkPath];
				
				NSString *rssUrl = [NSString stringWithFormat:@"%@//%@", feedScheme, linkPath];
				if(rssUrl) {
					NSLog(@"Subscribing to feed: %@", rssUrl);
					[GoogleReader subscribeToFeed:rssUrl];
				}
				else {
					NSRunAlertPanel(@"Error", @"The feed URL is malformed", @"Continue", nil, nil);
				}
			}
		}
	}
	//[NSApp terminate:self];
}

@end
