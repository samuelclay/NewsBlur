//
//  ShareViewController.m
//  Share Extension
//
//  Created by David Sinclair on 2015-12-18.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import "ShareViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface ShareViewController () <NSURLSessionDelegate>

@end

@implementation ShareViewController

- (BOOL)isContentValid {
    for (NSExtensionItem *item in self.extensionContext.inputItems) {
        for (NSItemProvider *itemProvider in item.attachments) {
            return [itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeURL] || [itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeText];
        }
    }
    
    return NO;
}

- (void)didSelectPost {
    NSItemProvider *itemProvider = [self providerWithURL];
    
    NSLog(@"ShareExt: didSelectPost");
    
    if (itemProvider) {
        [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeURL options:nil completionHandler:^(NSURL *item, NSError * _Null_unspecified error) {
            if (item) {
                [self sendURL:item orText:nil];
                [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
            }
        }];
    } else {
        itemProvider = [self providerWithText];
        
        if (itemProvider) {
            [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeText options:nil completionHandler:^(NSString *item, NSError * _Null_unspecified error) {
                if (item) {
                    [self sendURL:nil orText:item];
                    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
                }
            }];
        }
    }
}

- (NSItemProvider *)providerWithURL {
    for (NSExtensionItem *extensionItem in self.extensionContext.inputItems) {
        for (NSItemProvider *itemProvider in extensionItem.attachments) {
            if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeURL]) {
                return itemProvider;
            }
        }
    }
    
    return nil;
}

- (NSItemProvider *)providerWithText {
    for (NSExtensionItem *extensionItem in self.extensionContext.inputItems) {
        for (NSItemProvider *itemProvider in extensionItem.attachments) {
            if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeText]) {
                return itemProvider;
            }
        }
    }
    
    return nil;
}

- (void)sendURL:(NSURL *)url orText:(NSString *)text {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.newsblur.NewsBlur-Group"];
    NSString *host = [defaults objectForKey:@"share:host"];
    NSString *token = [defaults objectForKey:@"share:token"];
    NSString *comments = self.contentText;
    
    if (text && [comments isEqualToString:text]) {
        comments = @"";
    }
    
    NSCharacterSet *characterSet = [NSCharacterSet URLQueryAllowedCharacterSet];
    NSString *encodedURL = url ? [url.absoluteString stringByAddingPercentEncodingWithAllowedCharacters:characterSet] : @"";
    NSString *encodedContent = text ? [text stringByAddingPercentEncodingWithAllowedCharacters:characterSet] : @"";
    NSString *encodedComments = [comments stringByAddingPercentEncodingWithAllowedCharacters:characterSet];
    //                        NSInteger time = [[NSDate date] timeIntervalSince1970];
    NSURLSession *mySession = [self configureMySession];
    //    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/add_site_load_script/%@/?url=%@&time=%@&comments=%@", host, token, encodedURL, @(time), encodedComments]];
    //    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/share_story/%@", host, token]];
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/api/share_story/%@", host, token]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
    request.HTTPMethod = @"POST";
    NSString *postBody = [NSString stringWithFormat:@"story_url=%@&title=&content=%@&comments=%@", encodedURL, encodedContent, encodedComments];
    request.HTTPBody = [postBody dataUsingEncoding:NSUTF8StringEncoding];
    NSURLSessionTask *myTask = [mySession dataTaskWithRequest:request];
    [myTask resume];
    
    NSLog(@"ShareExt: sendURL %@ or text %@ to %@ with body %@", url, text, requestURL, postBody);
}

- (NSURLSession *)configureMySession {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"group.com.newsblur.share"];
    // To access the shared container you set up, use the sharedContainerIdentifier property on your configuration object.
    config.sharedContainerIdentifier = @"group.com.newsblur.NewsBlur-Group";
    NSURLSession *mySession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    return mySession;
}

//- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
// completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * __nullable credential))completionHandler {
//    
//    
//}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    NSLog(@"URLSession completed with error: %@", error);  // log
}

- (NSArray *)configurationItems {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    return @[];
}

@end
