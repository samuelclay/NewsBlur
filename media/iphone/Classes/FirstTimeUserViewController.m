//
//  FirstTimeUserViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/13/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FirstTimeUserViewController.h"
#import "NewsBlurAppDelegate.h"

@implementation FirstTimeUserViewController

@synthesize categoriesView;
@synthesize browseCategoriesButton;
@synthesize googleReaderButton;
@synthesize addSitesButton;

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
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [self setBrowseCategoriesButton:nil];
    [self setCategoriesView:nil];
    [self setBrowseCategoriesButton:nil];
    [self setGoogleReaderButton:nil];
    [self setAddSitesButton:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (IBAction)tapGoogleReaderButton {
}

- (IBAction)tapAddSitesButton {
    
}

- (IBAction)tapCategoriesButton:(id)sender {
    UIButton *categoryButton = (UIButton *)sender;
    if (categoryButton.currentTitle == @"Go Back") {
        [UIView animateWithDuration:0.5 
                         animations:^{
                             [UIView animateWithDuration:0.5 animations:^{
                                 categoriesView.alpha = 0.0;
                             }]; 
                         }
                         completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.5 animations:^{
                                 [browseCategoriesButton setTitle:@"Browse Categories" forState:UIControlStateNormal];
                                 categoriesView.hidden = YES;
                                 browseCategoriesButton.frame = CGRectMake(277, 407, browseCategoriesButton.frame.size.width, browseCategoriesButton.frame.size.height);
                                 googleReaderButton.alpha = 1.0;
                                 addSitesButton.alpha = 1.0;
                             }];
                             
                         }
         ];
    } else {
        [UIView animateWithDuration:0.5 
                         animations:^{
                             browseCategoriesButton.frame = CGRectMake(20, 201, browseCategoriesButton.frame.size.width, browseCategoriesButton.frame.size.height);
                             googleReaderButton.alpha = 0.0;
                             addSitesButton.alpha = 0.0;
                         }
                         completion:^(BOOL finished) {
                             categoriesView.hidden = NO;
                             [UIView animateWithDuration:0.5 animations:^{
                                 [browseCategoriesButton setTitle:@"Go Back" forState:UIControlStateNormal];
                                 categoriesView.alpha = 1.0;
                             }];   
                         }
         ];
    }

}

- (void)dealloc {
    [categoriesView release];
    [browseCategoriesButton release];
    [googleReaderButton release];
    [addSitesButton release];
    [super dealloc];
}

@end
