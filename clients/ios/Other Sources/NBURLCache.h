//
//  NBURLCache.h
//  NewsBlur
//
//  Created by Samuel Clay on 9/26/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NBURLCache : NSURLCache {
    NSMutableDictionary *cachedResponses;
}

@end
