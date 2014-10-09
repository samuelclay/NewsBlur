//
//  NBURLCache.m
//  NewsBlur
//
//  Created by Samuel Clay on 9/26/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import "NBURLCache.h"
#import "Utilities.h"

@implementation NBURLCache

- (NSString *)substitutePath:(NSString *)pathString {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *storyImagesDirectory = [[paths objectAtIndex:0]
                                      stringByAppendingPathComponent:@"story_images"];
    NSString *cachedImage = [[storyImagesDirectory
                             stringByAppendingPathComponent:[Utilities md5:pathString]] stringByAppendingPathExtension:[pathString pathExtension]];
    return cachedImage;
}

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request
{
    // Get the path for the request
    NSString *pathString = [[request URL] absoluteString];
    
    if (!pathString) return [super cachedResponseForRequest:request];
    
    // See if we have a substitution file for this path
    NSString *substitutionFileName = [self substitutePath:pathString];
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:substitutionFileName];
    if (!substitutionFileName || !exists)
    {
//        NSLog(@"No cache found: %@ / %@", pathString, substitutionFileName);
        // No substitution file, return the default cache response
        return [super cachedResponseForRequest:request];
    }
    
    // If we've already created a cache entry for this path, then return it.
    NSCachedURLResponse *cachedResponse = [cachedResponses objectForKey:pathString];
    if (cachedResponse)
    {
//        NSLog(@"Memory cached: %@", pathString);
        return cachedResponse;
    }
    
    // Get the path to the substitution file
    NSString *substitutionFilePath = substitutionFileName;
    
    // Load the data
    NSData *data = [NSData dataWithContentsOfFile:substitutionFilePath];
    
    // Create the cacheable response
    NSURLResponse *response = [[NSURLResponse alloc]
                               initWithURL:[request URL]
                               MIMEType:nil
                               expectedContentLength:[data length]
                               textEncodingName:nil];
    cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response
                                                              data:data];
    
//    NSLog(@"Got cached response: %@ / %@", pathString, substitutionFileName);
    // Add it to our cache dictionary for subsequent responses
    if (!cachedResponses)
    {
        cachedResponses = [[NSMutableDictionary alloc] init];
    }
    [cachedResponses setObject:cachedResponse forKey:pathString];
    
    return cachedResponse;
}

@end
