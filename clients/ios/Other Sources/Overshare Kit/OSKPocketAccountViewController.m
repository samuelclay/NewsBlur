//
//  OSKPocketAccountViewController.h
//  Overshare
//
//  Created by Jared Sinclair 10/30/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKPocketAccountViewController.h"

#import "OSKPresentationManager.h"
#import "PocketAPI.h"

@interface OSKPocketAccountViewController ()

@end

@implementation OSKPocketAccountViewController

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Pocket";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
    UIColor *bgColor = [presentationManager color_groupedTableViewBackground];
    self.view.backgroundColor = bgColor;
    self.tableView.backgroundColor = bgColor;
    self.tableView.backgroundView.backgroundColor = bgColor;
    self.tableView.separatorColor = presentationManager.color_separators;
    self.tableView.separatorInset = UIEdgeInsetsZero;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
        UIColor *bgColor = [presentationManager color_groupedTableViewCells];
        cell.backgroundColor = bgColor;
        cell.backgroundView.backgroundColor = bgColor;
        cell.textLabel.textColor = [presentationManager color_action];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.bounds];
        cell.selectedBackgroundView.backgroundColor = presentationManager.color_cancelButtonColor_BackgroundHighlighted;
        cell.tintColor = presentationManager.color_action;
        UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
        if (descriptor) {
            [cell.textLabel setFont:[UIFont fontWithDescriptor:descriptor size:17]];
        }
    }
    
    NSString *title = nil;
    if ([[PocketAPI sharedAPI] isLoggedIn]) {
        title = [[OSKPresentationManager sharedInstance] localizedText_SignOut];
    } else {
        title = [[OSKPresentationManager sharedInstance] localizedText_SignIn];
    }
    cell.textLabel.text = title;
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([[PocketAPI sharedAPI] isLoggedIn]) {
        [[PocketAPI sharedAPI] logout];
        [tableView reloadData];
    } else {
        __weak OSKPocketAccountViewController *weakSelf = self;
        [[PocketAPI sharedAPI] loginWithHandler:^(PocketAPI *api, NSError *error) {
            [weakSelf.tableView reloadData];
        }];
    }
}

@end






