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

@import UIKit;

// OSKRPSTPasswordManagementAppType implies functionality that is available since
// a given version was released, and not necessarily that a given version
// number has been installed. There are significant differences between
// version 1Password 4.0 and 4.1, for example. Not every dot release will be included
// here; only significant releases that affect URL schemes.

typedef enum {
    OSKRPSTPasswordManagementAppTypeNone,
    OSKRPSTPasswordManagementAppType1Password_v3,
    OSKRPSTPasswordManagementAppType1Password_v4,
    OSKRPSTPasswordManagementAppType1Password_v4_1,
} OSKRPSTPasswordManagementAppType;

@interface OSKRPSTPasswordManagementAppService : NSObject

// Checking Availability
+ (BOOL)passwordManagementAppIsAvailable;
+ (NSString *)availablePasswordManagementAppDisplayName;
+ (OSKRPSTPasswordManagementAppType)availablePasswordManagementApp;

// Searching for Entries
+ (NSURL *)passwordManagementAppCompleteURLForSearchQuery:(NSString *)query;

// Open in Web View
+ (BOOL)passwordManagementAppSupportsOpenWebView;
+ (NSURL *)passwordManagementAppCompleteURLForOpenWebViewHTTP:(NSString *)urlString;
+ (NSURL *)passwordManagementAppCompleteURLForOpenWebViewHTTPS:(NSString *)urlString;

@end
