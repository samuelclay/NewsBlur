//
//  NewsBlur.m
//  Reader Helper
//
//  Created by Geoff Hulette on 7/28/08.
//  Copyright 2008 Collidescope. All rights reserved.
//

#import "NewsBlur.h"


@implementation NewsBlur

+(void)subscribeToFeed:(NSString *)feedURL
{
	NSString *apiStr = @"http://www.newsblur.com/?url=";
	CFStringRef feedStr = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)feedURL, NULL, (CFStringRef)@";/?:@&=+$,", kCFStringEncodingUTF8);
	NSString *cmdStr = [apiStr stringByAppendingString:[NSString stringWithFormat:@"%@", feedStr]];
	NSLog(cmdStr);
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:cmdStr]];
}

@end
