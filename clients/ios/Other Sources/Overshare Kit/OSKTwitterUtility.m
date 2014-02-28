//
//  OSKTwitterUtility.m
//  Overshare
//
//  Created by Justin Williams on 10/15/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Social;
@import Accounts;

#import "OSKTwitterUtility.h"
#import "OSKShareableContentItem.h"
#import "OSKSystemAccountStore.h"
#import "OSKLogger.h"

#define kTwoWeeks (14 * 24 * 60 * 60)
#define kOSKTwitterConfigurationCache		@"OSKTwitterConfigurationCachePref"
#define kOSKTwitterConfigurationCacheDate	@"OSKTwitterConfigurationCacheDatePref"

NSString * const OSKTwitterImageHttpURLLengthKey = @"short_url_length_http";
NSString * const OSKTwitterImageHttpsURLLengthKey = @"short_url_length_https";
NSString * const OSKTwitterImageSizeLimitKey = @"photo_size_limit";

@implementation OSKTwitterUtility

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Twitter configuration caching
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (BOOL) isTwitterConfigurationCacheValid
{
	NSDate* lastCacheDate = [[NSUserDefaults standardUserDefaults] objectForKey:kOSKTwitterConfigurationCacheDate];
	if (lastCacheDate)
	{
		NSTimeInterval diff = [lastCacheDate timeIntervalSinceNow];
		if (ABS(diff) < kTwoWeeks)
		{
			return YES;
		}
	}
	
	return NO;
}

+ (void) cacheTwitterConfiguration:(NSDictionary*)configuration
{
	[[NSUserDefaults standardUserDefaults] setObject:configuration forKey:kOSKTwitterConfigurationCache];
	[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kOSKTwitterConfigurationCacheDate];
}

+ (NSDictionary*) cachedTwitterConfiguration
{
	NSDictionary* configuration = [[NSUserDefaults standardUserDefaults] objectForKey:kOSKTwitterConfigurationCache];
	return configuration;
}

+ (NSInteger) maxTwitterAttachmentSizeFromCache
{
	NSDictionary* configurationParameters = [self cachedTwitterConfiguration];
	NSNumber* photoSizeLimit = [configurationParameters objectForKey:OSKTwitterImageSizeLimitKey];
	return photoSizeLimit.integerValue;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Twitter configuration fetching
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void) requestTwitterConfiguration:(ACAccount *)account completion:(void(^)(NSError* error, NSDictionary* configurationParameters))completion
{
	//If we already have a valid configuration, let's bail early
	if ([self isTwitterConfigurationCacheValid])
	{
		NSDictionary* configurationParameters = [self cachedTwitterConfiguration];
		
		if (completion) {
			dispatch_async(dispatch_get_main_queue(), ^{
				completion(nil, configurationParameters);
			});
		}
		return;
	}
	
	//Setup the request
	SLRequestHandler requestHandler = ^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error)
	{
		if (responseData != nil)
		{
			NSInteger statusCode = urlResponse.statusCode;
            if ((statusCode >= 200) && (statusCode < 300))
            {
                NSDictionary *configurationParameters = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:NULL];
				[self cacheTwitterConfiguration:configurationParameters];
				
				if (completion) {
						dispatch_async(dispatch_get_main_queue(), ^{
							completion(nil, configurationParameters);
					});
				}
			}
			else
			{
				OSKLog(@"[OSKTwitterUtility] Error received when trying to request the configuration parameters from Twitter. Server responded with status code %li and response: %@", (long)statusCode, [NSHTTPURLResponse localizedStringForStatusCode:statusCode]);
                
					NSError *error = [NSError errorWithDomain:@"com.secondgear.PhotosPlus.Errors" code:statusCode userInfo:nil];
					dispatch_async(dispatch_get_main_queue(), ^{
						completion(error, nil);
					});
            }
		}
		else
		{
            OSKLog(@"[OSKTwitterUtility] An error occurred while attempting to request configuration parameters from Twitter: %@", [error localizedDescription]);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error, nil);
            });
		}
	};
	
    NSURL *twitterApiURL = [NSURL URLWithString:@"https://api.twitter.com/1.1/help/configuration.json"];
    NSDictionary *params = nil;
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:twitterApiURL parameters:params];
 	request.account = account;
    [request performRequestWithHandler:requestHandler];
}

+ (void)postContentItem:(OSKMicroblogPostContentItem *)item
        toSystemAccount:(ACAccount *)account
             completion:(void(^)(BOOL success, NSError *error))completion
{
	//If we don't have a valid configuration, we need to request it before posting
	if (![self isTwitterConfigurationCacheValid])
	{
		[self requestTwitterConfiguration:account completion:^(NSError *error, NSDictionary *configurationParameters){
			if (configurationParameters){
				[self postContentItem:item toSystemAccount:account completion:completion];
			}
			else{
				dispatch_async(dispatch_get_main_queue(), ^{
					completion(NO, error);
				});
			}
		}];
		
		return;
	}

	NSInteger photoSizeLimit = [self maxTwitterAttachmentSizeFromCache];
    SLRequestHandler requestHandler = ^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (responseData != nil)
        {
            NSInteger statusCode = urlResponse.statusCode;
            if ((statusCode >= 200) && (statusCode < 300))
            {
                NSDictionary *postResponseData =
                [NSJSONSerialization JSONObjectWithData:responseData
                                                options:NSJSONReadingMutableContainers
                                                  error:NULL];
                OSKLog(@"[OSKTwitterUtility] Successfully created Tweet with ID: %@", postResponseData[@"id_str"]);
                
                NSString *string = [NSString stringWithFormat:@"https://twitter.com/%@/status/%@", account.username, postResponseData[@"id_str"]];
                NSURL *tweetURL = [NSURL URLWithString:string];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion((tweetURL != nil), nil);
                });
                
            }
            else
            {
                NSString *responseString = nil;
                if (responseData) {
                    responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                }
                
                OSKLog(@"[OSKTwitterUtility] Error received when trying to create a new tweet. Server responded with status code %li and response: %@",
                       (long)statusCode,
                       responseString);
                
                NSError *error = [NSError errorWithDomain:@"com.secondgear.PhotosPlus.Errors" code:statusCode userInfo:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, error);
                });
            }
        }
        else
        {
            OSKLog(@"[OSKTwitterUtility] An error occurred while attempting to post a new tweet: %@", [error localizedDescription]);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error);
            });
        }
    };
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:@{ @"status" : item.text }];
    if ((item.latitude != 0.0) && (item.longitude != 0.0))
    {
        params[@"lat"] = [@(item.latitude) stringValue];
        params[@"long"] = [@(item.longitude) stringValue];
    }

    NSURL *twitterApiURL = nil;
    if ([item.images count] > 0)
    {
        twitterApiURL = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update_with_media.json"];;
    }
    else
    {
        twitterApiURL = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update.json"];
    }
    
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:twitterApiURL parameters:params];
    
    for (UIImage *image in item.images)
    {
		float quality = 1.0f;
        NSData *imageData = UIImageJPEGRepresentation(image, quality);
		
		//SLIGHT HACK WARNING:
		//We have the photo size limit from Twitter, and to make sure we are under the size requirement, we will degrade the JPEG quality
		//by 10% successively until we are under the limit. -@cheesemaker
		while (photoSizeLimit && (imageData.length > photoSizeLimit) && (quality > 0.0f))
		{
			quality -= 0.1f;
			imageData = UIImageJPEGRepresentation(image, quality);
		}
			
        [request addMultipartData:imageData withName:@"media[]" type:@"image/jpeg" filename:@"image.jpg"];
    }
    
    request.account = account;
    
    //    OSKLog(@"[OSKTwitterUtility] Beginning request to upload new tweet.");
    [request performRequestWithHandler:requestHandler];
}

@end
