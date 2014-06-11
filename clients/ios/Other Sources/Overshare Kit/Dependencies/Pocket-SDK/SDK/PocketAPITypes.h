//
//  PocketAPITypes.h
//  PocketSDK
//
//  Created by Steve Streza on 5/29/12.
//  Copyright (c) 2012 Read It Later, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PocketAPI;

@protocol PocketAPIDelegate <NSObject>
@optional
-(void)pocketAPI:(PocketAPI *)api receivedRequestToken:(NSString *)requestToken;

-(void)pocketAPILoggedIn:(PocketAPI *)api;
-(void)pocketAPI:(PocketAPI *)api hadLoginError:(NSError *)error;

-(void)pocketAPI:(PocketAPI *)api savedURL:(NSURL *)url;
-(void)pocketAPI:(PocketAPI *)api failedToSaveURL:(NSURL *)url error:(NSError *)error;

-(void)pocketAPI:(PocketAPI *)api receivedResponse:(NSDictionary *)response forAPIMethod:(NSString *)APIMethod error:(NSError *)error;

-(void)pocketAPIDidStartLogin:(PocketAPI *)api;
-(void)pocketAPIDidFinishLogin:(PocketAPI *)api;
@end

@protocol PocketAPISupport <NSObject>
@optional
-(BOOL)shouldAllowPocketReverseAuth;

@end

#if NS_BLOCKS_AVAILABLE
typedef void(^PocketAPILoginHandler)(PocketAPI *api, NSError *error);
typedef void(^PocketAPISaveHandler)(PocketAPI *api, NSURL *url, NSError *error);
typedef void(^PocketAPIResponseHandler)(PocketAPI *api, NSString *apiMethod, NSDictionary *response, NSError *error);
#endif

typedef enum {
	PocketAPIDomainDefault = 0,
	PocketAPIDomainAuth = 10
} PocketAPIDomain;

typedef enum {
	PocketAPIHTTPMethodGET,
	PocketAPIHTTPMethodPOST,
	PocketAPIHTTPMethodPUT,
	PocketAPIHTTPMethodDELETE
} PocketAPIHTTPMethod;

typedef enum {
	//OAuth Errors
	PocketAPIErrorNoConsumerKey = 138,
	PocketAPIErrorNoAccessToken = 107,
	PocketAPIErrorInvalidConsumerKey = 136,
	PocketAPIErrorInvalidRequest = 130,
	PocketAPIErrorNoChangesMade = 131,
	PocketAPIErrorConsumerKeyAccessTokenMismatch = 137,
	PocketAPIErrorEndpointForbidden = 150,
	PocketAPIErrorEndpointRequiresAdditionalPermissions = 151,
	
	// Signup Errors
	PocketAPIErrorSignupInvalidUsernameAndPassword  = 100,
	PocketAPIErrorSignupInvalidUsername = 101,
	PocketAPIErrorSignupInvalidPassword = 102,
	PocketAPIErrorSignupInvalidEmail    = 103,
	PocketAPIErrorSignupUsernameTaken = 104,
	PocketAPIErrorSignupEmailTaken = 105,

	// Server Problems
	PocketAPIErrorServerMaintenance = 199
} PocketAPIError;

extern const NSString *PocketAPIErrorDomain;

extern const NSString *PocketAPILoginStartedNotification;
extern const NSString *PocketAPILoginFinishedNotification;
