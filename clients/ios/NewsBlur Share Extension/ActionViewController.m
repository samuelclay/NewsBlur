//
//  ActionViewController.m
//  NewsBlur Share Extension
//
//  Created by Samuel Clay on 9/30/15.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import "NewsBlur_Prefix.pch"
#import "ActionViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface ActionViewController ()

@property(strong,nonatomic) IBOutlet NSURL *postUrl;
@property(strong,nonatomic) IBOutlet NSString *postTitle;
@property(strong,nonatomic) IBOutlet NSString *postText;

@end

@implementation ActionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    for (NSExtensionItem *item in self.extensionContext.inputItems) {
        for (NSItemProvider *itemProvider in item.attachments) {
            if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeURL]) {
                [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeURL options:nil completionHandler:^(NSURL *item, NSError * _Null_unspecified error) {
                    if (item) {
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            self.postUrl = item;
                        }];
                    }
                }];
            } else if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeText]) {
                [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeURL options:nil completionHandler:^(NSString *item, NSError * _Null_unspecified error) {
                    if (item) {
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            self.postText = item;
                        }];
                    }
                }];
            }
        }
    }
}

- (void)didSelectPost {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.newsblur.NewsBlur-Group"];
    NSString *token = [defaults objectForKey:@"share:token"];
    NSLog(@"Secret token: %@", token);
    NSURLSession *mySession = [self configureMySession];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/api/share_story/%@", NEWSBLUR_HOST, token]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];

    NSString *postBody = [NSString stringWithFormat:@"story_url=%@&comments=%@",
                          [self.postUrl.absoluteString
                           stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                          [self.contentText
                           stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    [request setHTTPBody:[postBody dataUsingEncoding:NSUTF8StringEncoding]];
    NSURLSessionTask *myTask = [mySession dataTaskWithRequest:request];
    [myTask resume];
}


- (NSURLSession *) configureMySession {
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"group.com.newsblur.share"];
    // To access the shared container you set up, use the sharedContainerIdentifier property on your configuration object.
    config.sharedContainerIdentifier = @"group.com.newsblur.NewsBlur-Group";
    NSURLSession *mySession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    return mySession;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)done {
    // Return any edited content to the host app.
    // This template doesn't do anything, so we just echo the passed in items.
    [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems completionHandler:nil];
}

@end
