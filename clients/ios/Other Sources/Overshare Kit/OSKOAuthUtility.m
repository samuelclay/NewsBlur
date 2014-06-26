//
//  OSKOAuthUtility.m
//  Overshare Kit
//
//  Created by Jared Sinclair October 20, 2013.
//  Copyright (c) 2013 Jared Sinclair & Justin Williams LLC. All rights reserved.
//

#import "OSKOAuthUtility.h"

#import "NSString+OSKDerp.h"
#import "NSData+OSKDerp.h"

#define koauth_consumer_key @"oauth_consumer_key"
#define koauth_nonce @"oauth_nonce"
#define koauth_signature @"oauth_signature"
#define koauth_signature_method @"oauth_signature_method"
#define koauth_timestamp @"oauth_timestamp"
#define koauth_token @"oauth_token"
#define koauth_version @"oauth_version"

#define kOauthVersionValue @"1.0"
#define kOauthSignatureMethodValue @"HMAC-SHA1"

@implementation OSKOAuthUtility

+ (NSString *)oauth_headerStringWithHTTPMethod:(NSString *)method
                                       baseURL:(NSString *)baseURL
                             queryStringParams:(NSDictionary *)queryParams
                                    bodyParams:(NSDictionary *)bodyParams
                                   consumerKey:(NSString *)consumerKey
                                consumerSecret:(NSString *)consumerSecret
                                   accessToken:(NSString *)tokenOrNil
                             accessTokenSecret:(NSString *)tokenSecretOrNil {
    
    NSString *nonce = [OSKOAuthUtility nonceWithLength:32];
    NSString *timestamp = [OSKOAuthUtility oauthTimeStamp];
    NSDictionary *basicOauthParams = [OSKOAuthUtility percentEncodedDictionaryWithConsumerKey:[consumerKey copy]
                                                                                     nonce:nonce
                                                                           signatureMethod:kOauthSignatureMethodValue
                                                                                 timeStamp:timestamp
                                                                                 authToken:[tokenOrNil copy]
                                                                              oauthVersion:kOauthVersionValue];
    
    NSDictionary *basicOauthParams_percentEncoded = [OSKOAuthUtility percentEncodedKeyValuePairs:basicOauthParams];
    NSDictionary *queryParams_percentEncoded = [OSKOAuthUtility percentEncodedKeyValuePairs:queryParams];
    NSDictionary *bodyParams_percentEncoded = [OSKOAuthUtility percentEncodedKeyValuePairs:bodyParams];
    
    NSMutableDictionary *allKeyValuePairs = [NSMutableDictionary dictionary];
    [allKeyValuePairs addEntriesFromDictionary:basicOauthParams_percentEncoded];
    [allKeyValuePairs addEntriesFromDictionary:queryParams_percentEncoded];
    [allKeyValuePairs addEntriesFromDictionary:bodyParams_percentEncoded];
    
    NSArray *alphabetizedKeys = [OSKOAuthUtility alphabetizedArrayOfKeys:allKeyValuePairs];
    NSMutableString *parameterString = [NSMutableString string];
    for (NSString *key in alphabetizedKeys) {
        if (parameterString.length) {
            [parameterString appendFormat:@"&"];
        }
        NSString *value = [allKeyValuePairs objectForKey:key];
        [parameterString appendFormat:@"%@=%@", key, value];
    }
    
    NSMutableString *signatureBaseString = [NSMutableString string];
    [signatureBaseString appendString:[method uppercaseString]];
    [signatureBaseString appendFormat:@"&"];
    [signatureBaseString appendString:[baseURL osk_derp_stringByEscapingPercents]];
    [signatureBaseString appendFormat:@"&"];
    [signatureBaseString appendString:[parameterString osk_derp_stringByEscapingPercents]]; // yes, percent encode this again here
    
    NSString *signingKey = [OSKOAuthUtility oauthSigningKeyFromConsumerSecret:consumerSecret tokenSecret:tokenSecretOrNil];
    NSString *oauthSignature = [OSKOAuthUtility HMAC_SHA1SignatureWithString:signatureBaseString key:signingKey];
    
    // AND FINALLY ...
    
    NSMutableString *outputString = [NSMutableString string];
    [outputString appendFormat:@"OAuth "];
    [outputString appendFormat:@"%@=\"%@\",", koauth_consumer_key, [consumerKey osk_derp_stringByEscapingPercents]];
    [outputString appendFormat:@"%@=\"%@\",", koauth_nonce, [nonce osk_derp_stringByEscapingPercents]];
    [outputString appendFormat:@"%@=\"%@\",", koauth_signature, [oauthSignature osk_derp_stringByEscapingPercents]];
    [outputString appendFormat:@"%@=\"%@\",", koauth_signature_method, [kOauthSignatureMethodValue osk_derp_stringByEscapingPercents]];
    [outputString appendFormat:@"%@=\"%@\",", koauth_timestamp, [timestamp osk_derp_stringByEscapingPercents]];
    if (tokenOrNil.length) {
        [outputString appendFormat:@"%@=\"%@\",", koauth_token, [tokenOrNil osk_derp_stringByEscapingPercents]];
    }
    [outputString appendFormat:@"%@=\"%@\"", koauth_version, [kOauthVersionValue osk_derp_stringByEscapingPercents]];
    
    return outputString;
}

+ (NSArray *)alphabetizedArrayOfKeys:(NSDictionary *)dictionary {
    return [[dictionary allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSString *string1 = (NSString *)obj1;
        NSString *string2 = (NSString *)obj2;
        return [string1 compare:string2];
    }];
}

+ (NSString *)oauthSigningKeyFromConsumerSecret:(NSString *)secret tokenSecret:(NSString *)tokenSecretOrNil {
    NSMutableString *signingKey = [NSMutableString stringWithFormat:@"%@&", [secret osk_derp_stringByEscapingPercents]];
    if (tokenSecretOrNil.length) {
        [signingKey appendString:[tokenSecretOrNil osk_derp_stringByEscapingPercents]];
    }
    return signingKey;
}

+ (NSString *)HMAC_SHA1SignatureWithString:(NSString *)string key:(NSString *)key {
    return [string osk_derp_HMAC_SHA1SignatureWithKey:key];
}

+ (NSString *)nonceWithLength:(NSUInteger)length {
    return [[NSString osk_derp_randomStringWithLength:length] osk_derp_stringByBase64EncodingString];
}

+ (NSString *)oauthTimeStamp {
    return [[NSString alloc] initWithFormat:@"%ld", time(NULL)];
}

+ (NSDictionary *)percentEncodedKeyValuePairs:(NSDictionary *)keyValuePairs {
    NSMutableDictionary *encodedPairs = [NSMutableDictionary dictionaryWithCapacity:keyValuePairs.allKeys.count];
    for (NSString *key in keyValuePairs.allKeys) {
        NSString *value = [keyValuePairs objectForKey:key];
        [encodedPairs setObject:[value osk_derp_stringByEscapingPercents] forKey:[key osk_derp_stringByEscapingPercents]];
    }
    return encodedPairs;
}

+ (NSDictionary *)percentEncodedDictionaryWithConsumerKey:(NSString *)consumerKey
                                                    nonce:(NSString *)nonce
                                          signatureMethod:(NSString *)signatureMethod
                                                timeStamp:(NSString *)timeStamp
                                                authToken:(NSString *)tokenOrNil
                                             oauthVersion:(NSString *)oauthVersion {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
                             koauth_consumer_key : consumerKey,
                                    koauth_nonce : nonce,
                         koauth_signature_method : signatureMethod,
                                koauth_timestamp : timeStamp,
                                  koauth_version : oauthVersion
     }];
    if (tokenOrNil.length) {
        [dictionary setObject:[tokenOrNil copy] forKey:koauth_token];
    }
    return dictionary;
}

@end







