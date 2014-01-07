//
//  RPPasswordManagementAppService.h
//  Riposte
//
//  Copyright (c) 2013 Riposte LLC. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
//  PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
//  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "OSKRPSTPasswordManagementAppService.h"

@implementation OSKRPSTPasswordManagementAppService

#pragma mark - Constants

// Search Schemes
NSString * const OSKRPSTOnePasswordSearch_v3 = @"onepassword3://";
NSString * const OSKRPSTOnePasswordSearch_v4 = @"onepassword4://";
NSString * const OSKRPSTOnePasswordSearch_v4_1 = @"onepassword://";
NSString * const OSKRPSTOnePasswordSearch_v4_1b = @"onepasswordb://";

// Web View Schemes
NSString * const OSKRPSTOnePasswordOpenWebURLHTTP = @"ophttp://";
NSString * const OSKRPSTOnePasswordOpenWebURLHTTPS = @"ophttps://";

#pragma mark - Checking Availability

+ (BOOL)passwordManagementAppIsAvailable {
    BOOL canOpen = NO;
    UIApplication *app = [UIApplication sharedApplication];
    if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4_1b]]) {
        canOpen = YES;
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4_1]]) {
        canOpen = YES;
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4]]) {
        canOpen = YES;
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v3]]) {
        canOpen = YES;
    }
    return canOpen;
}

+ (OSKRPSTPasswordManagementAppType)availablePasswordManagementApp {
    OSKRPSTPasswordManagementAppType pwApp = NO;
    UIApplication *app = [UIApplication sharedApplication];
    if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4_1b]]) {
        pwApp = OSKRPSTPasswordManagementAppType1Password_v4_1;
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4_1]]) {
        pwApp = OSKRPSTPasswordManagementAppType1Password_v4_1;
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4]]) {
        pwApp = OSKRPSTPasswordManagementAppType1Password_v4;
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v3]]) {
        pwApp = OSKRPSTPasswordManagementAppType1Password_v3;
    }
    return pwApp;
}

+ (NSString *)availablePasswordManagementAppDisplayName {
    NSString *name = nil;
    UIApplication *app = [UIApplication sharedApplication];
    if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4_1b]]) {
        name = @"1Password";
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4_1]]) {
        name = @"1Password";
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4]]) {
        name = @"1Password";
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v3]]) {
        name = @"1Password";
    }
    return name;
}

#pragma mark - Searching Entries

+ (NSURL *)passwordManagementAppCompleteURLForSearchQuery:(NSString *)query {
    NSURL *fullURL = nil;
    UIApplication *app = [UIApplication sharedApplication];
    if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4_1b]]) {
        NSString *baseURL = OSKRPSTOnePasswordSearch_v4_1b;
        NSString *fullURLString = [NSString stringWithFormat:@"%@search/%@", baseURL, query];
        fullURL = [NSURL URLWithString:fullURLString];
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4_1]]) {
        NSString *baseURL = OSKRPSTOnePasswordSearch_v4_1;
        NSString *fullURLString = [NSString stringWithFormat:@"%@search/%@", baseURL, query];
        fullURL = [NSURL URLWithString:fullURLString];
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v4]]) {
        NSString *baseURL = OSKRPSTOnePasswordSearch_v4;
        NSString *fullURLString = [NSString stringWithFormat:@"%@search/%@", baseURL, query];
        fullURL = [NSURL URLWithString:fullURLString];
    }
    else if ([app canOpenURL:[NSURL URLWithString:OSKRPSTOnePasswordSearch_v3]]) {
        NSString *baseURL = OSKRPSTOnePasswordSearch_v3;
        NSString *fullURLString = [NSString stringWithFormat:@"%@%@", baseURL, query];
        fullURL = [NSURL URLWithString:fullURLString];
    }
    return fullURL;
}

#pragma mark - Open Web Views

+ (BOOL)passwordManagementAppSupportsOpenWebView {
	OSKRPSTPasswordManagementAppType availableAppType = [OSKRPSTPasswordManagementAppService availablePasswordManagementApp];
	BOOL supportsWebViews;
	switch (availableAppType) {
		case OSKRPSTPasswordManagementAppType1Password_v4_1: {
			supportsWebViews = YES;
		} break;
		case OSKRPSTPasswordManagementAppType1Password_v4:
		case OSKRPSTPasswordManagementAppType1Password_v3: {
			supportsWebViews = NO;
		} break;
		default: {
			supportsWebViews = NO;
		} break;
	}
	return supportsWebViews;
}

+ (NSURL *)passwordManagementAppCompleteURLForOpenWebViewHTTP:(NSString *)urlString {
	return [OSKRPSTPasswordManagementAppService
			OSKRPST_passwordManagementAppCompleteURLForOpenWebViewWithScheme:OSKRPSTOnePasswordOpenWebURLHTTP
			urlString:urlString];
}

+ (NSURL *)passwordManagementAppCompleteURLForOpenWebViewHTTPS:(NSString *)urlString {
	return [OSKRPSTPasswordManagementAppService
			OSKRPST_passwordManagementAppCompleteURLForOpenWebViewWithScheme:OSKRPSTOnePasswordOpenWebURLHTTPS
			urlString:urlString];
}

+ (NSURL *)OSKRPST_passwordManagementAppCompleteURLForOpenWebViewWithScheme:(NSString *)scheme
															   urlString:(NSString *)urlString {
    NSURL *fullURL = nil;
    UIApplication *app = [UIApplication sharedApplication];
	
    if ([app canOpenURL:[NSURL URLWithString:scheme]]) {
		
        NSString *correctedURLString = nil;
        NSRange rangeOfSchemeSeparator;
		
        rangeOfSchemeSeparator = [urlString rangeOfString:@"://"];
		
        if (rangeOfSchemeSeparator.location != NSNotFound) {
            // Remove the scheme and the :// from the string
            NSArray *components = [urlString componentsSeparatedByString:@"://"];
            if (components.count == 2) {
                correctedURLString = [components objectAtIndex:1];
            } else {
                NSLog(@"OSKRPSTPasswordManagementAppService: invalid URL string argument. Contains multiple :// separators.");
            }
        } else {
            correctedURLString = urlString;
        }
		
        if (correctedURLString.length > 0) {
            NSString *finalURLString = [NSString stringWithFormat:@"%@%@", scheme, correctedURLString];
            fullURL = [NSURL URLWithString:finalURLString];
        }
    }
    return fullURL;
}

@end

















