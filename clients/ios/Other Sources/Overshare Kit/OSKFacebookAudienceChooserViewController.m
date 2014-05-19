//
//  OSKFacebookAudienceChooserViewController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/30/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Accounts;

#import "OSKFacebookAudienceChooserViewController.h"

#import "OSKPresentationManager.h"

@interface OSKFacebookAudienceChooserViewController ()

@property (copy, nonatomic) NSString *selectedAudience;
@property (weak, nonatomic) id <OSKFacebookAudienceChooserDelegate> delegate;

@end

#define EVERYONE_INDEX 0
#define FRIENDS_INDEX 1
#define ONLY_ME_INDEX 2

@implementation OSKFacebookAudienceChooserViewController

- (id)initWithSelectedAudience:(NSString *)selectedAudience delegate:(id<OSKFacebookAudienceChooserDelegate>)delegate {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _selectedAudience = [selectedAudience copy];
        _delegate = delegate;
        OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
        [self setTitle:[presentationManager localizedText_FacebookAudience_Audience]];
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
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        UIColor *bgColor = [presentationManager color_groupedTableViewCells];
        cell.backgroundColor = bgColor;
        cell.backgroundView.backgroundColor = bgColor;
        cell.textLabel.textColor = [presentationManager color_text];
        cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.bounds];
        cell.selectedBackgroundView.backgroundColor = presentationManager.color_cancelButtonColor_BackgroundHighlighted;
        cell.tintColor = presentationManager.color_action;
        UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
        if (descriptor) {
            [cell.textLabel setFont:[UIFont fontWithDescriptor:descriptor size:17]];
        } else {
            [cell.textLabel setFont:[UIFont systemFontOfSize:17]];
        }
    }
    
    NSString *text = nil;
    NSString *audience = nil;
    
    switch (indexPath.row) {
        case EVERYONE_INDEX: {
            text = [presentationManager localizedText_FacebookAudience_Public];
            audience = ACFacebookAudienceEveryone;
        } break;
        case FRIENDS_INDEX: {
            text = [presentationManager localizedText_FacebookAudience_Friends];
            audience = ACFacebookAudienceFriends;
        } break;
        case ONLY_ME_INDEX: {
            text = [presentationManager localizedText_FacebookAudience_OnlyMe];
            audience = ACFacebookAudienceOnlyMe;
        } break;
        default:
            break;
    }
    
    [cell.textLabel setText:text];
    
    if ([audience isEqualToString:self.selectedAudience]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *audience = nil;
    switch (indexPath.row) {
        case EVERYONE_INDEX: {
            audience = ACFacebookAudienceEveryone;
        } break;
        case FRIENDS_INDEX: {
            audience = ACFacebookAudienceFriends;
        } break;
        case ONLY_ME_INDEX: {
            audience = ACFacebookAudienceOnlyMe;
        } break;
        default:
            break;
    }
    [self setSelectedAudience:audience];
    [self.tableView reloadData];
    [self.delegate audienceChooser:self didChooseNewAudience:audience];
    
    // A tiny delay feels less jarring...
    __weak OSKFacebookAudienceChooserViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [weakSelf.navigationController popViewControllerAnimated:YES];
    });
}

@end




