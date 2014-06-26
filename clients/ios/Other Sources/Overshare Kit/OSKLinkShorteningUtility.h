//
//  OSKLinkShorteningUtility.h
//  Unread
//
//  Created by Jared Sinclair 11/19/13.
//  Copyright (c) 2013 Nice Boy LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OSKLinkShorteningUtility : NSObject

+ (BOOL)shorteningRecommended:(NSString *)longURL;

+ (void)shortenURL:(NSString *)longURL completion:(void(^)(NSString *shortURL))completion;

@end
