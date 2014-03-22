//
//  OSKAppDotNetUtility.m
//  Overshare
//
//  Created by Jared Sinclair on 10/10/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKAppDotNetUtility.h"

#import "OSKActivity.h"
#import "OSKManagedAccountCredential.h"
#import "OSKShareableContentItem.h"
#import "OSKApplicationCredential.h"
#import "OSKLogger.h"
#import "NSDictionary+OSKModel.h"
#import "OSKManagedAccount.h"
#import "NSMutableURLRequest+OSKUtilities.h"
#import "NSHTTPURLResponse+OSKUtilities.h"
#import "UIImage+OSKUtilities.h"

static NSString * OSKAppDotNetUtility_BaseURL = @"https://alpha-api.app.net/";
static NSString * OSKAppDotNetUtility_URL_FetchMe = @"stream/0/users/me?access_token=%@";
static NSString * OSKAppDotNetUtility_URL_WriteNewPost = @"stream/0/posts?access_token=%@&include_post_annotations=1";

#define kAccountID @"id"
#define kUsername @"username"
#define kName @"name"
#define kAvatarObject @"avatar_image"
#define kAvatarURL @"url"

@implementation OSKAppDotNetUtility

#pragma mark - Write Post

+ (void)postContentItem:(OSKMicroblogPostContentItem *)item withCredential:(OSKManagedAccountCredential *)credential appCredential:(OSKApplicationCredential *)appCredential completion:(void(^)(BOOL success, NSError *error))completion {
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if(completion) {
            completion(NO, nil);
        }
    }];
    
    if (item.images.count) {
        [self uploadImages:item.images accountCredential:credential appCredential:appCredential completion:^(NSArray *fileDictionaries, NSError *error) {
            [self _postContentItem:item fileAPIDictionaries:fileDictionaries withCredential:credential appCredential:appCredential completion:^(BOOL success, NSError *error) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(success, nil);
                        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                    });
                }
            }];
        }];
    } else {
        [self _postContentItem:item fileAPIDictionaries:nil withCredential:credential appCredential:appCredential completion:^(BOOL success, NSError *error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(success, nil);
                    [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                });
            }
        }];
    }
}

+ (void)_postContentItem:(OSKMicroblogPostContentItem *)item fileAPIDictionaries:(NSArray *)dictionaries withCredential:(OSKManagedAccountCredential *)credential appCredential:(OSKApplicationCredential *)appCredential completion:(void(^)(BOOL success, NSError *error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *subPath = [NSString stringWithFormat:OSKAppDotNetUtility_URL_WriteNewPost, credential.token];
        NSString *fullPath = [NSString stringWithFormat:@"%@%@", OSKAppDotNetUtility_BaseURL, subPath];
        NSDictionary *dictionaryRep = [self _dictionaryRepresentationForContentItem:item attachedImageDictionaries:dictionaries];
        
        NSURLSession *sesh = [NSURLSession sharedSession];
        
        NSMutableURLRequest *request = [NSMutableURLRequest osk_requestWithMethod:@"POST" URLString:fullPath parameters:dictionaryRep serialization:OSKParameterSerializationType_HTTPBody_JSON];
        
        [[sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError *theError = error;
                    if ([NSHTTPURLResponse statusCodeAcceptableForResponse:response] == NO && error == nil) {
                        theError = [NSError errorWithDomain:@"OSKAppDotNetUtility" code:400 userInfo:@{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Request failed: %@", response.description]}];
                    }
                    if (theError) {
                        OSKLog(@"Failed to send App.net post: %@", error);
                    }
                    completion((theError == nil), theError);
                });
            }
        }] resume];
    });
}

+ (NSDictionary *)_dictionaryRepresentationForContentItem:(OSKMicroblogPostContentItem *)item attachedImageDictionaries:(NSArray *)dictionaries {
    NSMutableDictionary *rep = [[NSMutableDictionary alloc] init];
    if (dictionaries.count) {
        NSArray *fileReps = [self _annotationDictionariesForFileAPIDictionaries:dictionaries];
        if (fileReps.count) {
            [rep setObject:fileReps forKey:@"annotations"];
        }
    }
    [rep setObject:item.text forKey:@"text"];
    return rep;
}

+ (NSArray *)_annotationDictionariesForFileAPIDictionaries:(NSArray *)fileDictionaries {
    NSMutableArray *annotations = [[NSMutableArray alloc] initWithCapacity:fileDictionaries.count];
    for (NSDictionary *aFileDictionary in fileDictionaries) {
        NSString *fileID = [aFileDictionary osk_nonNullStringIDForKey:@"id"];
        NSString *fileToken = [aFileDictionary objectForKey:@"file_token"];
        if (fileToken.length && fileID.length) { // Prevent crash if fileID or fileToken are nil
            NSMutableDictionary *valueDictionary = [[NSMutableDictionary alloc] init];
            NSMutableDictionary *fileDict = [[NSMutableDictionary alloc] init];
            [fileDict setValue:fileID forKey:@"file_id"];
            [fileDict setValue:fileToken forKey:@"file_token"];
            [fileDict setValue:@"oembed" forKey:@"format"];
            [valueDictionary setValue:fileDict forKey:@"+net.app.core.file"];
            NSDictionary *annotation = @{@"type":@"net.app.core.oembed",
                                         @"value":valueDictionary};
            [annotations addObject:annotation];
        }
    }
    return annotations;
}

#pragma mark - Users & Accounts

+ (void)fetchUserDataWithCredential:(OSKManagedAccountCredential *)credential
                      appCredential:(OSKApplicationCredential *)appCredential
                         completion:(void(^)(NSDictionary *userDictionary, NSError *error))completion {
    NSString *path = [NSString stringWithFormat:OSKAppDotNetUtility_URL_FetchMe, credential.token];
    NSString *fullPath = [NSString stringWithFormat:@"%@%@", OSKAppDotNetUtility_BaseURL, path];
    
    NSURLSession *sesh = [NSURLSession sharedSession];
    
    NSMutableURLRequest *request = [NSMutableURLRequest osk_requestWithMethod:@"GET" URLString:fullPath parameters:nil serialization:OSKParameterSerializationType_HTTPBody_FormData];
    
    [[sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSError *theError = error;
        if ([NSHTTPURLResponse statusCodeAcceptableForResponse:response] == NO && error == nil) {
            theError = [NSError errorWithDomain:@"OSKAppDotNetUtility" code:400 userInfo:@{NSLocalizedFailureReasonErrorKey:[NSString stringWithFormat:@"Request failed: %@", response.description]}];
        }
        if (theError == nil) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSDictionary *userDictionary = nil;
                if (data) {
                    NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    userDictionary = [responseDictionary objectForKey:@"data"];
                }
                
				//There are times when the values aren't present in the dictionary
                NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
				if ([userDictionary objectForKey:kAccountID]) {
					userInfo[OSKAppDotNetUtility_UserInfoKey_accountID] = [userDictionary osk_nonNullStringIDForKey:kAccountID];
                }
                if ([userDictionary objectForKey:kUsername]) {
					userInfo[OSKAppDotNetUtility_UserInfoKey_username] = [userDictionary osk_nonNullObjectForKey:kUsername];
                }
                if ([userDictionary objectForKey:kName]) {
					userInfo[OSKAppDotNetUtility_UserInfoKey_name] = [userDictionary osk_nonNullObjectForKey:kName];
                }
            
				if ([userDictionary objectForKey:kAvatarObject])
				{
					NSDictionary *avatarObject = [userDictionary osk_nonNullObjectForKey:kAvatarObject];
					if ([avatarObject objectForKey:kAvatarURL]) {
						userInfo[OSKAppDotNetUtility_UserInfoKey_avatarURL] = [avatarObject osk_nonNullObjectForKey:kAvatarURL];
                    }
                }
				if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(userInfo, nil);
                    });
                }
            });
        } else {
            completion(nil, theError);
        }
    }] resume];
}

+ (void)createNewUserWithAccessToken:(NSString *)token appCredential:(OSKApplicationCredential *)appCredential completion:(void(^)(OSKManagedAccount *account, NSError *error))completion {
    NSString *identifier = [OSKManagedAccount generateNewOvershareAccountIdentifier];
    OSKManagedAccountCredential *accountCredential = nil;
    accountCredential = [[OSKManagedAccountCredential alloc] initWithOvershareAccountIdentifier:identifier accessToken:token];
    [self fetchUserDataWithCredential:accountCredential appCredential:appCredential completion:^(NSDictionary *userDictionary, NSError *error) {
        OSKManagedAccount *account = nil;
        if (userDictionary) {
            account = [self _createAccountWithUserInfo:userDictionary
                                    accountCredential:accountCredential
                                    accountIdentifier:identifier];
        }
        if (account) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(account,nil);
            });
        }
        else {
            OSKLog(@"Unable to create account for App.net, error fetching user info: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
    }];
}

+ (OSKManagedAccount *)_createAccountWithUserInfo:(NSDictionary *)userInfo accountCredential:(OSKManagedAccountCredential *)credential accountIdentifier:(NSString *)identifier {
    OSKManagedAccount *account = nil;
    account = [[OSKManagedAccount alloc] initWithOvershareAccountIdentifier:identifier
                                                               activityType:OSKActivityType_API_AppDotNet
                                                                 credential:credential];
    [account setUsername:userInfo[OSKAppDotNetUtility_UserInfoKey_username]];
    [account setFullName:userInfo[OSKAppDotNetUtility_UserInfoKey_name]];
    [account setAccountID:userInfo[OSKAppDotNetUtility_UserInfoKey_accountID]];
    return account;
}

#pragma mark - File Upload

+ (void)uploadImages:(NSArray *)images accountCredential:(OSKManagedAccountCredential *)credential appCredential:(OSKApplicationCredential *)appCredential completion:(void (^)(NSArray *fileDictionaries, NSError *error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *fileDictionaries = [[NSMutableArray alloc] initWithCapacity:images.count];
        __block NSError *firstError = nil;
        dispatch_queue_t queue = dispatch_get_global_queue(0,0);
        dispatch_group_t group = dispatch_group_create();
        for (UIImage *image in images) {
            dispatch_group_async(group,queue,^{
                dispatch_semaphore_t sema = dispatch_semaphore_create(0);
                [self uploadImage:image accountCredential:credential appCredential:appCredential completion:^(NSDictionary *fileDictionary, NSError *uploadError) {
                    if (fileDictionary && [fileDictionary isKindOfClass:[NSDictionary class]]) {
                        [fileDictionaries addObject:fileDictionary];
                    } else {
                        if (firstError == nil) {
                            firstError = uploadError;
                        }
                    }
                    dispatch_semaphore_signal(sema);
                }];
                dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            });
        }
        dispatch_group_notify(group,queue,^{
            if (completion) {
                completion(fileDictionaries, firstError);
            }
        });
    });
}

+ (void)uploadImage:(UIImage *)image accountCredential:(OSKManagedAccountCredential *)credential appCredential:(OSKApplicationCredential *)appCredential completion:(void (^)(NSDictionary *fileDictionary, NSError *error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *parameters = @{@"type":@"net.overshare.image",
                                     @"mime_type":@"image/jpeg",
                                     @"kind":@"image",
                                     @"public":@(YES)};
        parameters = [[NSDictionary alloc] initWithDictionary:parameters];
        NSString *path = [NSString stringWithFormat:@"stream/0/files?access_token=%@", credential.token];
        NSString *fullPath = [NSString stringWithFormat:@"%@%@", OSKAppDotNetUtility_BaseURL, path];
        NSString *mimeType = @"image/jpeg";
        NSString *suffix = @"jpg";
		NSString *dateSuffix = [self _todaysDateSuffix];
        CGFloat quality = [UIImage osk_recommendedUploadQuality:image];
        NSData *imageData = UIImageJPEGRepresentation(image, quality);
        NSString *appName = appCredential.appName.copy;
        NSString *filename = [NSString stringWithFormat:@"Image_from_%@_%@.%@", appName, dateSuffix, suffix];
        
        NSURLSession *sesh = [NSURLSession sharedSession];
        
        NSMutableURLRequest *request = nil;
        NSData *requestData = nil;
        request = [NSMutableURLRequest osk_MultipartFormUploadRequestWithMethod:@"POST" URLString:fullPath parameters:parameters uploadData:imageData filename:filename formName:@"content" mimeType:mimeType serialization:OSKParameterSerializationType_HTTPBody_JSON bodyData:&requestData];
        
        [[sesh uploadTaskWithRequest:request fromData:requestData completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error == nil) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSError *error = nil;
                    NSDictionary *responseDictionary = nil;
                    if (data) {
                        responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    }
                    if (completion) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            completion([responseDictionary objectForKey:@"data"], error);
                        });
                    }
                });
            } else {
                OSKLog(@"OSKAppDotNetUtility: Image upload failed: %@", error);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, error);
                });
            }
        }] resume];
    });
}

+ (NSString *)_todaysDateSuffix {
	NSDate *today = [NSDate date];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.dateFormat = @"yyyy-MM-dd";
	NSString *suffix = [formatter stringFromDate:today];
	return suffix;
}

@end


