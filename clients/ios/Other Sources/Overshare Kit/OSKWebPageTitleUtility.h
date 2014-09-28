//
//  OSKWebPageTitleUtility.h
//  Unread
//
//  Created by Jared on 4/30/14.
//  Copyright (c) 2014 Nice Boy LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OSKWebPageTitleUtility : NSObject

+ (void)getWebPageTitleForURL:(NSString *)url completion:(void(^)(NSString *fetchedTitle))completion;

@end
