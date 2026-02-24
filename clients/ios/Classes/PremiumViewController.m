//
//  PremiumViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/9/17.
//  Copyright © 2017 NewsBlur. All rights reserved.
//

#import "PremiumViewController.h"
#import "NewsBlur-Swift.h"
#import "PremiumManager.h"

@interface PremiumViewController ()

@property (nonatomic, strong) PremiumViewHostingController *swiftUIController;

@end

@implementation PremiumViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.swiftUIController = [[PremiumViewHostingController alloc] init];
    self.swiftUIController.scrollToArchive = self.scrollToArchive;
    self.swiftUIController.scrollToPro = self.scrollToPro;

    [self addChildViewController:self.swiftUIController];
    self.swiftUIController.view.frame = self.view.bounds;
    self.swiftUIController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.swiftUIController.view];
    [self.swiftUIController didMoveToParentViewController:self];

    // Disconnect and hide the legacy table view - now using SwiftUI
    self.premiumTable.delegate = nil;
    self.premiumTable.dataSource = nil;
    self.premiumTable.hidden = YES;

    // Hide navigation bar items since SwiftUI handles them
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = nil;
    self.navigationController.navigationBarHidden = YES;
}

- (void)closeDialog:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)configureScrollToArchive:(BOOL)scrollToArchive scrollToPro:(BOOL)scrollToPro {
    self.scrollToArchive = scrollToArchive;
    self.scrollToPro = scrollToPro;

    // Remove existing SwiftUI controller if present
    if (self.swiftUIController) {
        [self.swiftUIController willMoveToParentViewController:nil];
        [self.swiftUIController.view removeFromSuperview];
        [self.swiftUIController removeFromParentViewController];
        self.swiftUIController = nil;
    }

    // Create new SwiftUI controller with updated scroll target
    self.swiftUIController = [[PremiumViewHostingController alloc] init];
    self.swiftUIController.scrollToArchive = scrollToArchive;
    self.swiftUIController.scrollToPro = scrollToPro;

    [self addChildViewController:self.swiftUIController];
    self.swiftUIController.view.frame = self.view.bounds;
    self.swiftUIController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.swiftUIController.view];
    [self.swiftUIController didMoveToParentViewController:self];
}

#pragma mark - StoreKit

- (void)loadedProducts {
    [self.swiftUIController loadedProducts];
}

- (void)finishedTransaction {
    [self.swiftUIController finishedTransaction];
}

- (void)informError:(id)error {
    [super informError:error];
}

@end
