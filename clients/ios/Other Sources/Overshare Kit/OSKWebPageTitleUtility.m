//
//  OSKWebPageTitleUtility.m
//  Unread
//
//  Created by Jared on 4/30/14.
//  Copyright (c) 2014 Nice Boy LLC. All rights reserved.
//

#import "OSKWebPageTitleUtility.h"

@implementation OSKWebPageTitleUtility

+ (void)getWebPageTitleForURL:(NSString *)url completion:(void(^)(NSString *fetchedTitle))completion {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSURLSession *sesh = [NSURLSession sharedSession];
    [[sesh dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __block NSString *title = nil;
            if (data) {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (html.length) {
                    NSError *error = NULL;
                    NSRegularExpression *regex = [NSRegularExpression
                                                  regularExpressionWithPattern:@"<title>(.+)</title>"
                                                  options:NSRegularExpressionCaseInsensitive
                                                  error:&error];
                    [regex enumerateMatchesInString:html options:0 range:NSMakeRange(0, [html length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop){
                        title = [html substringWithRange:[match rangeAtIndex:1]];
                        *stop = YES;
                    }];
                }
            }
            
            if (title.length) {
                title = [title stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                title = [self stripHTMLEntitiesFromString:title];
            }
            
            if (title.length == 0) {
                NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
                title = [NSString stringWithFormat:@"Saved with %@", appName];
            }
            
            if (completion) {
                completion(title);
            }
        });
    }] resume];
}

+ (NSString *)stripHTMLEntitiesFromString:(NSString *)sourceString {
    if (sourceString.length == 0) {
        return @"";
    }
    NSMutableString *string = [NSMutableString stringWithString:sourceString];
    NSDictionary *symbolReplacementPairs = @{
                                             @"&nbsp;":@" ",
                                             @"&amp;":@"&",
                                             @"&cent;":@"¢",
                                             @"&pound;":@"£",
                                             @"&yen;":@"¥",
                                             @"&euro;":@"€",
                                             @"&copy;":@"©",
                                             @"&reg;":@"®",
                                             @"&trade;":@"™",
                                             @"&nbsp;":@" ",
                                             @"&quot;":@"\"",
                                             @"&apos;":@"'",
                                             @"&iexcl;":@"¡",
                                             @"&ndash;":@"–",
                                             @"&mdash;":@"—",
                                             @"&lsquo;":@"‘",
                                             @"&rsquo;":@"’",
                                             @"&ldquo;":@"“",
                                             @"&rdquo;":@"”",
                                             @"&#8211;":@"–",
                                             @"&#39;":@"'",
                                             @"&#34;":@"\"",
                                             @"&#38;":@"&",
                                             @"&#8216;":@"‘",
                                             @"&#8217;":@"’",
                                             @"&#8220;":@"“",
                                             @"&#8221;":@"”	",
                                             };
    for (NSString *key in symbolReplacementPairs.allKeys) {
        NSString *replacement = [symbolReplacementPairs objectForKey:key];
        [string replaceOccurrencesOfString:key
                                withString:replacement
                                   options:NSCaseInsensitiveSearch
                                     range:NSMakeRange(0, string.length)];
    }
    return string;
}

@end
