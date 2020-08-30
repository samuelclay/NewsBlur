//
//  FTUXAddNewsBlurViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FirstTimeUserAddNewsBlurViewController.h"
#import "NewsBlur-Swift.h"

@implementation FirstTimeUserAddNewsBlurViewController

@synthesize appDelegate;
@synthesize nextButton;
@synthesize instructionsLabel;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Start reading" style:UIBarButtonItemStyleDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"All Done";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationItem.rightBarButtonItem setStyle:UIBarButtonItemStyleDone];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self addSite:@"http://blog.newsblur.com/rss"];
    [self addPopular];
}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//    // Return YES for supported orientations
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        return YES;
//    } else if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
//        return YES;
//    }
//    
//    return NO;
//}


- (IBAction)tapNextButton {
    [appDelegate.ftuxNavigationController dismissViewControllerAnimated:YES completion:nil];
        [appDelegate.feedsViewController fetchFeedList:NO];
}

- (IBAction)tapNewsBlurButton:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.selected = YES;
    button.userInteractionEnabled = NO;

    UIImage *checkmark = [UIImage imageNamed:@"258-checkmark"];
    UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:checkmark];
    checkmarkView.frame = CGRectMake(button.frame.origin.x + button.frame.size.width - 24,
                                     button.frame.origin.y + 8,
                                     16,
                                     16);
    [self.view addSubview:checkmarkView];
    
    [self addSite:@"http://blog.newsblur.com/rss"];
}

- (IBAction)tapPopularButton:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.selected = YES;
    button.userInteractionEnabled = NO;
    
    UIImage *checkmark = [UIImage imageNamed:@"258-checkmark"];
    UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:checkmark];
    checkmarkView.frame = CGRectMake(button.frame.origin.x + button.frame.size.width - 24,
                                     button.frame.origin.y + 8,
                                     16,
                                     16);
    [self.view addSubview:checkmarkView];
    [self addPopular];
}

#pragma mark -
#pragma mark Add Site

- (void)addPopular {
    NSString *urlString = [NSString stringWithFormat:@"%@/social/follow/",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    [params setObject:@"social:popular" forKey:@"user_id"];     

    [appDelegate POST:urlString parameters:params target:self success:@selector(finishAddSite:) failure:@selector(informError:)];
}

- (void)addSite:(NSString *)siteUrl {
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/add_url/",
                           self.appDelegate.url];

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:siteUrl forKey:@"url"]; 
    [params setObject:@"true" forKey:@"auto_active"]; 
    [params setObject:@"true" forKey:@"skip_fetch"]; 

    [appDelegate POST:urlString parameters:params target:self success:@selector(finishAddSite:) failure:@selector(informError:)];
}

- (void)finishAddSite:(NSDictionary *)results {
    NSLog(@"results are %@", results);
}

@end
