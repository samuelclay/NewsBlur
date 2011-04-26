//
//  GoogleReader.m
//  Reader Helper
//
//  Created by Geoff Hulette on 7/28/08.
//  Copyright 2008 Collidescope. All rights reserved.
//

#import "GoogleReader.h"


@implementation GoogleReader

+(void)subscribeToFeed:(NSString *)feedURL
{
	NSString *apiStr = @"http://www.google.com/reader/preview/*/feed/";
	CFStringRef feedStr = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)feedURL, NULL, (CFStringRef)@";/?:@&=+$,", kCFStringEncodingUTF8);
	NSString *cmdStr = [apiStr stringByAppendingString:[NSString stringWithFormat:@"%@", feedStr]];
	NSLog(cmdStr);
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:cmdStr]];
}

@end
