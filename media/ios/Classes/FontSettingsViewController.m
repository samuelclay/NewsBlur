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
@synthesize fontStyleSegment;
@synthesize fontSizeSegment;

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
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate]; 
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([userPreferences stringForKey:@"fontStyle"]) {
        if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-san-serif"]) {
            [fontStyleSegment setSelectedSegmentIndex:0];
        } else if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-serif"]) {    
            [fontStyleSegment setSelectedSegmentIndex:1];
        }
    }

    if([userPreferences stringForKey:@"fontSizing"]){
        NSString *fontSize = [NSString stringWithFormat:@"%@", [userPreferences stringForKey:@"fontSizing"]];
        if ([fontSize isEqualToString:@"NB-extra-small"]) {
            [fontSizeSegment setSelectedSegmentIndex:0]; 
        } else if ([fontSize isEqualToString:@"NB-small"]) {
            [fontSizeSegment setSelectedSegmentIndex:1];
        } else if ([fontSize isEqualToString:@"NB-medium"]) {
            [fontSizeSegment setSelectedSegmentIndex:2];
        } else if ([fontSize isEqualToString:@"NB-large"]) {
            [fontSizeSegment setSelectedSegmentIndex:3];
        } else if ([fontSize isEqualToString:@"NB-extra-large"]) {
            [fontSizeSegment setSelectedSegmentIndex:4];
        }
    }
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{

    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (IBAction)changeFontStyle:(id)sender {
    if ([sender selectedSegmentIndex] == 0) {
        [self setSanSerif];
    } else {
        [self setSerif];
    }
}

- (IBAction)changeFontSize:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([sender selectedSegmentIndex] == 0) {
        [appDelegate.storyDetailViewController changeFontSize:@"NB-extra-small"];
        [userPreferences setObject:@"NB-extra-small" forKey:@"fontSizing"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [appDelegate.storyDetailViewController changeFontSize:@"NB-small"];
        [userPreferences setObject:@"NB-small" forKey:@"fontSizing"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [appDelegate.storyDetailViewController changeFontSize:@"NB-medium"];
        [userPreferences setObject:@"NB-medium" forKey:@"fontSizing"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [appDelegate.storyDetailViewController changeFontSize:@"NB-large"];
        [userPreferences setObject:@"NB-large" forKey:@"fontSizing"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [appDelegate.storyDetailViewController changeFontSize:@"NB-extra-large"];
        [userPreferences setObject:@"NB-extra-large" forKey:@"fontSizing"];
    }
    [userPreferences synchronize];
}

- (void)setSanSerif {
    [fontStyleSegment setSelectedSegmentIndex:0];
    [appDelegate.storyDetailViewController setFontStyle:@"Helvetica"];
}
        
- (void)setSerif {
    [fontStyleSegment setSelectedSegmentIndex:1];
    [appDelegate.storyDetailViewController setFontStyle:@"Georgia"];
}

@end
