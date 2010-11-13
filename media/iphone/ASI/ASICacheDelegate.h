//
//  ASICacheDelegate.h
//  Part of ASIHTTPRequest -> http://allseeing-i.com/ASIHTTPRequest
//
//  Created by Ben Copsey on 01/05/2010.
//  Copyright 2010 All-Seeing Interactive. All rights reserved.
//

#import <Foundation/Foundation.h>
@class ASIHTTPRequest;

typedef enum _ASICachePolicy {
	ASIDefaultCachePolicy = 0,
	ASIIgnoreCachePolicy = 1,
	ASIReloadIfDifferentCachePolicy = 2,
	ASIOnlyLoadIfNotCachedCachePolicy = 3,
	ASIUseCacheIfLoadFailsCachePolicy = 4
} ASICachePolicy;

typedef enum _ASICacheStoragePolicy {
	ASICacheForSessionDurationCacheStoragePolicy = 0,
	ASICachePermanentlyCacheStoragePolicy = 1
} ASICacheStoragePolicy;


@protocol ASICacheDelegate <NSObject>

@required

// Should return the cache policy that will be used when requests have their cache policy set to ASIDefaultCachePolicy
- (ASICachePolicy)defaultCachePolicy;

// Should Remove cached data for a particular request
- (void)removeCachedDataForRequest:(ASIHTTPRequest *)request;

// Should return YES if the cache considers its cached response current for the request
// Should return NO is the data is not cached, or (for example) if the cached headers state the request should have expired
- (BOOL)isCachedDataCurrentForRequest:(ASIHTTPRequest *)request;

// Should store the response for the passed request in the cache
// When a non-zero maxAge is passed, it should be used as the expiry time for the cached response
- (void)storeResponseForRequest:(ASIHTTPRequest *)request maxAge:(NSTimeInterval)maxAge;

// Should return an NSDictionary of cached headers for the passed request, if it is stored in the cache
- (NSDictionary *)cachedHeadersForRequest:(ASIHTTPRequest *)request;

// Should return the cached body of a response for the passed request, if it is stored in the cache
- (NSData *)cachedResponseDataForRequest:(ASIHTTPRequest *)request;

// Same as the above, but returns a path to the cached response body instead
- (NSString *)pathToCachedResponseDataForRequest:(ASIHTTPRequest *)request;
- (NSString *)pathToCachedResponseHeadersForRequest:(ASIHTTPRequest *)request;

// Clear cached data stored for the passed storage policy
- (void)clearCachedResponsesForStoragePolicy:(ASICacheStoragePolicy)cachePolicy;
@end
