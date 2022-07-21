//
//  NotificationsViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/23/16.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "NotificationsViewController.h"
#import "NotificationFeedCell.h"

@interface NotificationsViewController ()

@end

@implementation NotificationsViewController

@synthesize notificationsTable;
@synthesize appDelegate;
@synthesize feedId;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    self.navigationItem.title = @"Notifications";
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle: @"Done"
                                                                     style: UIBarButtonItemStylePlain
                                                                    target: self
                                                                    action: @selector(doCancelButton)];
    [self.navigationItem setRightBarButtonItem:cancelButton];
    
    // Do any additional setup after loading the view from its nib.
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    notificationsTable = [[UITableView alloc] init];
    notificationsTable.delegate = self;
    notificationsTable.dataSource = self;
    notificationsTable.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);;
    notificationsTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    notificationsTable.separatorStyle = UITableViewCellSeparatorStyleNone;

    [self.view addSubview:notificationsTable];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)doCancelButton {
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    notificationsTable.backgroundColor = UIColorFromRGB(0xECEEEA);
    notificationsTable.separatorColor = UIColorFromRGB(0xF0F0F0);
    notificationsTable.sectionIndexColor = UIColorFromRGB(0x303030);
    notificationsTable.sectionIndexBackgroundColor = UIColorFromRGB(0xDCDFD6);
    
    notificationFeedIds = [appDelegate.notificationFeedIds copy];
    [notificationsTable reloadData];
    
    [notificationsTable setContentOffset:CGPointZero];
    
    self.view.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"notifications table: %@ / %@", NSStringFromCGRect(notificationsTable.frame), NSStringFromCGRect(self.view.frame));
}
#pragma mark - Table view delegate


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 36;
}

- (UIView *)tableView:(UITableView *)tableView
viewForHeaderInSection:(NSInteger)section {
    int headerLabelHeight, folderImageViewY;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        headerLabelHeight = 36;
        folderImageViewY = 8;
    } else {
        headerLabelHeight = 36;
        folderImageViewY = 8;
    }
    
    // create the parent view that will hold header Label
    UIControl* customView = [[UIControl alloc]
                             initWithFrame:CGRectMake(0.0, 0.0,
                                                      tableView.bounds.size.width, headerLabelHeight + 1)];
    UIView *borderTop = [[UIView alloc]
                         initWithFrame:CGRectMake(0.0, 0,
                                                  tableView.bounds.size.width, 1.0)];
    borderTop.backgroundColor = UIColorFromRGB(0xe0e0e0);
    borderTop.opaque = NO;
    [customView addSubview:borderTop];
    
    
    UIView *borderBottom = [[UIView alloc]
                            initWithFrame:CGRectMake(0.0, headerLabelHeight,
                                                     tableView.bounds.size.width, 1.0)];
    borderBottom.backgroundColor = [UIColorFromRGB(0xB7BDC6) colorWithAlphaComponent:0.5];
    borderBottom.opaque = NO;
    [customView addSubview:borderBottom];
    
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    customView.opaque = NO;
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = UIColorFromRGB(0x4C4C4C);
    headerLabel.highlightedTextColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    headerLabel.font = [UIFont boldSystemFontOfSize:11];
    headerLabel.frame = CGRectMake(36.0, 1.0, 286.0, headerLabelHeight);
    headerLabel.shadowColor = UIColorFromRGB(0xF0F0F7);
    headerLabel.shadowOffset = CGSizeMake(0.0, 1.0);
    if (self.feedId && section == 0) {
        headerLabel.text = @"SITE NOTIFICATIONS";
    } else {
        headerLabel.text = @"ALL NOTIFICATIONS";
    }
    
    customView.backgroundColor = [UIColorFromRGB(0xF7F7F5)
                                  colorWithAlphaComponent:0.8];
    [customView addSubview:headerLabel];
    
    UIImage *folderImage = [UIImage imageNamed:@"dialog-notifications"];
    int folderImageViewX = 9;
    UIImageView *folderImageView = [[UIImageView alloc] initWithImage:folderImage];
    folderImageView.frame = CGRectMake(folderImageViewX, folderImageViewY, 20, 20);
    [customView addSubview:folderImageView];
    [customView setAutoresizingMask:UIViewAutoresizingNone];
    return customView;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.feedId) {
        return 2;
    }
    
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 118;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.feedId && section == 0) {
        return 1;
    }
    return MAX(notificationFeedIds.count, 1);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL feedSection = NO;
    if (self.feedId != nil && indexPath.section == 0) feedSection = YES;
    if (notificationFeedIds.count == 0 && !feedSection) {
        UITableViewCell *cell = [[UITableViewCell alloc] init];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor clearColor];
        CGRect vb = self.view.bounds;
        CGFloat height = [self tableView:tableView heightForRowAtIndexPath:indexPath];
        UILabel *msg = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, vb.size.width, height)];
        [cell.contentView addSubview:msg];
        msg.text = @"No notifications yet.";
        msg.textColor = UIColorFromRGB(0x7a7a7a);
        if (vb.size.width > 320) {
            msg.font = [UIFont fontWithName:@"WhitneySSm-Medium" size: 21.0];
        } else {
            msg.font = [UIFont fontWithName:@"WhitneySSm-Medium" size: 15.0];
        }
        msg.textAlignment = NSTextAlignmentCenter;
        
        return cell;
    }
    
    static NSString *CellIdentifier = @"NotificationFeedCellIdentifier";
    NotificationFeedCell *cell = [tableView
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[NotificationFeedCell alloc]
                initWithStyle:UITableViewCellStyleValue1
                reuseIdentifier:CellIdentifier];
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    NSDictionary *feed;
    NSString *feedIdStr;
    if (self.feedId && indexPath.section == 0) {
        feedIdStr = feedId;
        feed = [appDelegate.dictFeeds objectForKey:feedId];
    } else {
        feedIdStr = [NSString stringWithFormat:@"%@",
                     notificationFeedIds[indexPath.row]];
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
    }
    cell.feedId = feedIdStr;
    cell.textLabel.text = [feed objectForKey:@"feed_title"];
    cell.imageView.image = [self.appDelegate getFavicon:feedIdStr isSocial:NO isSaved:NO];
    cell.detailTextLabel.text = [NSString localizedStringWithFormat:NSLocalizedString(@"%@ stories/month", @"average stories per month"), feed[@"average_stories_per_month"]];
    
    return cell;
}

@end
