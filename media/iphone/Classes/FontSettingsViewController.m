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
@synthesize fontSizeSgement;

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
}

- (void)viewWillAppear:(BOOL)animated {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([userPreferences stringForKey:@"fontStyle"]) {
        if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-san-serif"]) {
            [self setSanSerif];
        } else if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-serif"]) {    
            [self setSerif];
        }
    }
    int userPreferenceFontSize = [userPreferences integerForKey:@"fontSize"];
    if(userPreferenceFontSize){
        switch (userPreferenceFontSize) {
            case 12:
                [fontSizeSgement setSelectedSegmentIndex:0];
                break;
            case 14:
                [fontSizeSgement setSelectedSegmentIndex:1];
                break;
            case 16:
                [fontSizeSgement setSelectedSegmentIndex:2];
                break;
            case 22:
                [fontSizeSgement setSelectedSegmentIndex:3];
                break;
            case 26:
                [fontSizeSgement setSelectedSegmentIndex:4];
                break;
            default:
                break;
        }
    }
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [self setFontStyleSegment:nil];
    [self setFontSizeSgement:nil];
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
    [fontStyleSegment release];
    [fontSizeSgement release];
    [super dealloc];
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
        [appDelegate.storyDetailViewController setFontSize:12];
        [userPreferences setInteger:12 forKey:@"fontSize"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [appDelegate.storyDetailViewController setFontSize:14];
        [userPreferences setInteger:14 forKey:@"fontSize"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [appDelegate.storyDetailViewController setFontSize:16];
        [userPreferences setInteger:16 forKey:@"fontSize"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [appDelegate.storyDetailViewController setFontSize:22];
        [userPreferences setInteger:22 forKey:@"fontSize"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [appDelegate.storyDetailViewController setFontSize:26];
        [userPreferences setInteger:26 forKey:@"fontSize"];
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
