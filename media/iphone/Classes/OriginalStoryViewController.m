//
//  OriginalStoryViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/13/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "OriginalStoryViewController.h"


@implementation OriginalStoryViewController

@synthesize appDelegate;
@synthesize closeButton;
@synthesize webView;
@synthesize back;
@synthesize forward;
@synthesize refresh;
@synthesize pageAction;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"Original Story View: %@", [appDelegate activeOriginalStoryURL]);
    [appDelegate showNavigationBar:NO];
    NSURLRequest *request = [[[NSURLRequest alloc] initWithURL:[appDelegate activeOriginalStoryURL]] autorelease];
    [webView loadRequest:request];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.webView = nil;
    self.back = nil;
    self.forward = nil;
    self.refresh = nil;
    self.pageAction = nil;
}


- (void)dealloc {
    [super dealloc];
    [closeButton release];
    [webView release];
    [back release];
    [forward release];
    [refresh release];
    [pageAction release];
}


- (IBAction)doCloseOriginalStoryViewController {
    NSLog(@"Close Original Story: %@", appDelegate);
    [appDelegate closeOriginalStory];
}


@end
