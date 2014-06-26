//
//  NSMutableURLRequest+OSKUtilities.h
//  Overshare
//
//  Created by Jared Sinclair on 10/24/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

typedef NS_ENUM(NSInteger, OSKParameterSerializationType) {
    OSKParameterSerializationType_Query,
    OSKParameterSerializationType_HTTPBody_FormData,
    OSKParameterSerializationType_HTTPBody_JSON,
};

@interface NSMutableURLRequest (OSKUtilities)

+ (NSMutableURLRequest *)osk_requestWithMethod:(NSString *)method
                                     URLString:(NSString *)URLString
                                    parameters:(NSDictionary *)parameters
                                 serialization:(OSKParameterSerializationType)serialization;

+ (NSMutableURLRequest *)osk_MultipartFormUploadRequestWithMethod:(NSString *)method
                                                        URLString:(NSString *)URLstring
                                                       parameters:(NSDictionary *)parameters
                                                       uploadData:(NSData *)uploadData
                                                         filename:(NSString *)filename
                                                         formName:(NSString *)formName
                                                         mimeType:(NSString *)mimeType
                                                    serialization:(OSKParameterSerializationType)serialization
                                                         bodyData:(NSData **)outputData;

@end
