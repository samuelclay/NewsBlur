//
//  NSMutableURLRequest+OSKUtilities.m
//  Overshare
//
//  Created by Jared Sinclair on 10/24/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "NSMutableURLRequest+OSKUtilities.h"

#import "OSKLogger.h"

static NSString * OSKBoundaryString = @"OvershareKit-nT6YdBLrnos4eaUY";
static NSString * OSKCRLF = @"\r\n";
static NSString * kOSKCharactersToBeEscapedInQueryString = @":/?&=;+!@#$()',*";

static NSString * OSKPercentEscapedQueryStringKeyFromStringWithEncoding(NSString *string, NSStringEncoding encoding) {
    static NSString * const kOSKCharactersToLeaveUnescapedInQueryStringPairKey = @"[].";
    
	return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, (__bridge CFStringRef)kOSKCharactersToLeaveUnescapedInQueryStringPairKey, (__bridge CFStringRef)kOSKCharactersToBeEscapedInQueryString, CFStringConvertNSStringEncodingToEncoding(encoding));
}

static NSString * OSKPercentEscapedQueryStringValueFromStringWithEncoding(NSString *string, NSStringEncoding encoding) {
	return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, (__bridge CFStringRef)kOSKCharactersToBeEscapedInQueryString, CFStringConvertNSStringEncodingToEncoding(encoding));
}


// ====================================================================================================


@interface OSKQueryStringPair : NSObject

@property (readwrite, nonatomic, strong) id field;
@property (readwrite, nonatomic, strong) id value;

- (id)initWithField:(id)field value:(id)value;

- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding;

@end

@implementation OSKQueryStringPair

- (id)initWithField:(id)field value:(id)value {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.field = field;
    self.value = value;
    
    return self;
}

- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding {
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return OSKPercentEscapedQueryStringKeyFromStringWithEncoding([self.field description], stringEncoding);
    } else {
        return [NSString stringWithFormat:@"%@=%@", OSKPercentEscapedQueryStringKeyFromStringWithEncoding([self.field description], stringEncoding), OSKPercentEscapedQueryStringValueFromStringWithEncoding([self.value description], stringEncoding)];
    }
}

@end


// ====================================================================================================


extern NSArray * OSKQueryStringPairsFromDictionary(NSDictionary *dictionary);
extern NSArray * OSKQueryStringPairsFromKeyAndValue(NSString *key, id value);

NSArray * OSKQueryStringPairsFromDictionary(NSDictionary *dictionary) {
    return OSKQueryStringPairsFromKeyAndValue(nil, dictionary);
}

NSArray * OSKQueryStringPairsFromKeyAndValue(NSString *key, id value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        // Sort dictionary keys to ensure consistent ordering in query string, which is important when deserializing potentially ambiguous sequences, such as an array of dictionaries
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(caseInsensitiveCompare:)];
        for (id nestedKey in [dictionary.allKeys sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            id nestedValue = [dictionary objectForKey:nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObjectsFromArray:OSKQueryStringPairsFromKeyAndValue((key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey), nestedValue)];
            }
        }
    } else if ([value isKindOfClass:[NSArray class]]) {
        NSArray *array = value;
        for (id nestedValue in array) {
            [mutableQueryStringComponents addObjectsFromArray:OSKQueryStringPairsFromKeyAndValue([NSString stringWithFormat:@"%@[]", key], nestedValue)];
        }
    } else if ([value isKindOfClass:[NSSet class]]) {
        NSSet *set = value;
        for (id obj in set) {
            [mutableQueryStringComponents addObjectsFromArray:OSKQueryStringPairsFromKeyAndValue(key, obj)];
        }
    } else {
        [mutableQueryStringComponents addObject:[[OSKQueryStringPair alloc] initWithField:key value:value]];
    }
    
    return mutableQueryStringComponents;
}

static NSString * OSKQueryStringFromParametersWithEncoding(NSDictionary *parameters, NSStringEncoding stringEncoding) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (OSKQueryStringPair *pair in OSKQueryStringPairsFromDictionary(parameters)) {
        [mutablePairs addObject:[pair URLEncodedStringValueWithEncoding:stringEncoding]];
    }
    
    return [mutablePairs componentsJoinedByString:@"&"];
}


// ====================================================================================================


@implementation NSMutableURLRequest (OSKUtilities)

+ (NSMutableURLRequest *)osk_requestWithMethod:(NSString *)method URLString:(NSString *)URLString parameters:(NSDictionary *)parameters serialization:(OSKParameterSerializationType)serialization {
    NSParameterAssert(method);
    NSParameterAssert(URLString);
    
    NSURL *url = [NSURL URLWithString:URLString];
    
    NSParameterAssert(url);
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:method];
    
    if (serialization == OSKParameterSerializationType_HTTPBody_JSON) {
        request = [[self osk_requestByJSONSerializingRequest:request withParameters:parameters error:nil] mutableCopy];
    }
    else if (serialization == OSKParameterSerializationType_HTTPBody_FormData) {
        request = [[self osk_requestByHTTPSerializingRequest:request withParameters:parameters error:nil] mutableCopy];
    }
    else {
        request = [[self osk_requestByQueryStringSerializingRequest:request withParameters:parameters error:nil] mutableCopy];
    }
    
	return request;
}

+ (NSURLRequest *)osk_requestByQueryStringSerializingRequest:(NSURLRequest *)request withParameters:(NSDictionary *)parameters error:(NSError *__autoreleasing *)error {
    NSParameterAssert(request);
    
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    
    if (!parameters) {
        return mutableRequest;
    }
    
    NSString *query = OSKQueryStringFromParametersWithEncoding(parameters, NSUTF8StringEncoding);
    mutableRequest.URL = [NSURL URLWithString:[[mutableRequest.URL absoluteString] stringByAppendingFormat:mutableRequest.URL.query ? @"&%@" : @"?%@", query]];
    
    return mutableRequest;
}

+ (NSURLRequest *)osk_requestByHTTPSerializingRequest:(NSURLRequest *)request withParameters:(NSDictionary *)parameters error:(NSError *__autoreleasing *)error {
    NSParameterAssert(request);
    
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    
    if (!parameters) {
        return mutableRequest;
    }
    
    NSString *query = OSKQueryStringFromParametersWithEncoding(parameters, NSUTF8StringEncoding);
    [mutableRequest setHTTPBody:[query dataUsingEncoding:NSUTF8StringEncoding]];
    [mutableRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    return mutableRequest;
}

+ (NSURLRequest *)osk_requestByJSONSerializingRequest:(NSURLRequest *)request withParameters:(NSDictionary *)parameters error:(NSError *__autoreleasing *)error {
    NSParameterAssert(request);
    
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    
    if (!parameters) {
        return mutableRequest;
    }
    
    NSString *charset = (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    
    [mutableRequest setValue:[NSString stringWithFormat:@"application/json; charset=%@", charset] forHTTPHeaderField:@"Content-Type"];
    [mutableRequest setHTTPBody:[NSJSONSerialization dataWithJSONObject:parameters options:0 error:error]];
    
    return mutableRequest;
}

+ (NSMutableURLRequest *)osk_MultipartFormUploadRequestWithMethod:(NSString *)method URLString:(NSString *)URLstring parameters:(NSDictionary *)parameters uploadData:(NSData *)uploadData filename:(NSString *)filename formName:(NSString *)formName mimeType:(NSString *)mimeType serialization:(OSKParameterSerializationType)serialization bodyData:(NSData **)outputData{
    
    NSMutableData *mutableBodyData = [NSMutableData data];
    
    NSString *openingBoundary = [NSString stringWithFormat:@"%@--%@%@", OSKCRLF, OSKBoundaryString, OSKCRLF];
    [mutableBodyData appendData:[openingBoundary dataUsingEncoding:NSUTF8StringEncoding]];
    
    if (parameters) {
        if (serialization == OSKParameterSerializationType_HTTPBody_JSON) {
            NSString *contentDisposition = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"metadata\"; filename=\"metadata.json\"%@", OSKCRLF];
            [mutableBodyData appendData:[contentDisposition dataUsingEncoding:NSUTF8StringEncoding]];
            
            NSString *contentType = [NSString stringWithFormat:@"Content-Type: application/json%@%@", OSKCRLF, OSKCRLF];
            [mutableBodyData appendData:[contentType dataUsingEncoding:NSUTF8StringEncoding]];
            
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];
            if (jsonData) {
                [mutableBodyData appendData:jsonData];
            }
        }
        else if (serialization == OSKParameterSerializationType_HTTPBody_FormData) {
            for (OSKQueryStringPair *pair in OSKQueryStringPairsFromDictionary(parameters)) {
                NSString *escapedKey = OSKPercentEscapedQueryStringKeyFromStringWithEncoding(pair.field, NSUTF8StringEncoding);
                NSString *escapedValue = OSKPercentEscapedQueryStringValueFromStringWithEncoding(pair.value, NSUTF8StringEncoding);
                NSString *contentDisposition = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"%@", escapedKey, OSKCRLF];
                [mutableBodyData appendData:[contentDisposition dataUsingEncoding:NSUTF8StringEncoding]];
                [mutableBodyData appendData:[escapedValue dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
        else {
            NSAssert(NO, @"Multipart form data requests cannot use the query string parameter serialization type.");
        }
        NSString *closingBoundary = [NSString stringWithFormat:@"%@--%@", OSKCRLF, OSKBoundaryString];
        [mutableBodyData appendData:[closingBoundary dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    if (uploadData) {
        NSString *contentDisposition = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"%@", formName, filename, OSKCRLF];
        [mutableBodyData appendData:[contentDisposition dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSString *contentType = [NSString stringWithFormat:@"Content-Type: %@%@%@", mimeType, OSKCRLF, OSKCRLF];
        [mutableBodyData appendData:[contentType dataUsingEncoding:NSUTF8StringEncoding]];
        
        [mutableBodyData appendData:[NSData dataWithData:uploadData]];
        
        NSString *closingBoundary = [NSString stringWithFormat:@"%@--%@", OSKCRLF, OSKBoundaryString];
        [mutableBodyData appendData:[closingBoundary dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    NSString *closingDashes = @"--";
    [mutableBodyData appendData:[closingDashes dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", OSKBoundaryString];
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    [request setURL:[NSURL URLWithString:URLstring]];
    [request setHTTPMethod:method];
    
    *outputData = [NSData dataWithData:mutableBodyData];
    
    return request;
}

@end







