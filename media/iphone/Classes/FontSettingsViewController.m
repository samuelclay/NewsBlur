//
//  FontPopover.m
//  NewsBlur
//
//  Created by Roy Yang on 6/18/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FontSettingsViewController.h"
#import "NewsBlurAppDelegate.h"
#import "StoryDetailViewController.h"

@implementation FontSettingsViewController

@synthesize appDelegate;
@synthesize smallFontSizeLabel;
@synthesize largeFontSizeLabel;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    self.contentSizeForViewInPopover = CGSizeMake(274.0,130.0);
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    smallFontSizeLabel = nil;
    largeFontSizeLabel = nil;
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)dealloc {
    [appDelegate release];
    [smallFontSizeLabel release];
    [largeFontSizeLabel release];
    [super dealloc];
}


- (IBAction)changeFontStyle:(id)sender {
    if ([sender selectedSegmentIndex] == 0) {
        UIFont *smallFont = [UIFont fontWithName:@"Helvetica" size:15.0];
        [self.smallFontSizeLabel setFont:smallFont];
        UIFont *largeFont = [UIFont fontWithName:@"Georgia" size:24.0];
        [self.largeFontSizeLabel setFont:largeFont];
        [appDelegate.storyDetailViewController setFontStyle:@"Helvetica"];

    } else {
        UIFont *smallFont = [UIFont fontWithName:@"Georgia" size:15.0];
        [self.smallFontSizeLabel setFont:smallFont];
        UIFont *largeFont = [UIFont fontWithName:@"Georgia" size:24.0];
        [self.largeFontSizeLabel setFont:largeFont];
        [appDelegate.storyDetailViewController setFontStyle:@"Georgia"];
    }

}

- (IBAction)changeFontSize:(UISlider *)sender {
    [appDelegate.storyDetailViewController setFontSize:[sender value]];
}
@end
