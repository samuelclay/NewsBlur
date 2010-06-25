//
//  StoryDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "StoryDetailViewController.h"
#import "NewsBlurAppDelegate.h"


@implementation StoryDetailViewController

@synthesize appDelegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"Loaded Story view: %@", appDelegate.activeStory);
    
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [appDelegate release];
    [super dealloc];
}


@end
