//
//  StoryDetailContainerViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/23/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "StoryDetailContainerViewController.h"
#import "NewsBlurAppDelegate.h"
#import "StoryDetailViewController.h"
#import "FontSettingsViewController.h"

@implementation StoryDetailContainerViewController

@synthesize appDelegate;
@synthesize popoverController;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self.view addSubview:appDelegate.storyDetailViewController.view];
    
    [self addChildViewController:appDelegate.storyDetailViewController];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    
    UIBarButtonItem *originalButton = [[UIBarButtonItem alloc] 
                                       initWithTitle:@"Original" 
                                       style:UIBarButtonItemStyleBordered 
                                       target:self 
                                       action:@selector(showOriginalSubview:)
                                       ];
    
    UIBarButtonItem *fontSettingsButton = [[UIBarButtonItem alloc] 
                                           initWithTitle:@"Aa" 
                                           style:UIBarButtonItemStyleBordered 
                                           target:self 
                                           action:@selector(toggleFontSize:)
                                           ];
    
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:originalButton, fontSettingsButton, nil];

}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidDisappear:(BOOL)animated {
    [popoverController dismissPopoverAnimated:YES];
    [appDelegate hideShareView:YES];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {    
    [appDelegate adjustStoryDetailWebView];
}

- (IBAction)toggleFontSize:(id)sender {

    if (popoverController == nil) {
        popoverController = [[UIPopoverController alloc]
                             initWithContentViewController:appDelegate.fontSettingsViewController];
        
        popoverController.delegate = self;
    } else {
        if (popoverController.isPopoverVisible) {
            [popoverController dismissPopoverAnimated:YES];
            return;
        }
        
        [popoverController setContentViewController:appDelegate.fontSettingsViewController];
    }
    
    [popoverController setPopoverContentSize:CGSizeMake(274.0, 130.0)];
    
    [popoverController presentPopoverFromBarButtonItem:sender
                                  permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void)showOriginalSubview:(id)sender {
    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory 
                                       objectForKey:@"story_permalink"]];
    [appDelegate showOriginalStory:url];
}

@end
