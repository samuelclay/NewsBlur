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
    [notificationsTable reloadData];
    
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
    headerLabel.textColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    headerLabel.highlightedTextColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    headerLabel.font = [UIFont boldSystemFontOfSize:11];
    headerLabel.frame = CGRectMake(36.0, 1.0, 286.0, headerLabelHeight);
    headerLabel.shadowColor = [UIColor colorWithRed:.94 green:0.94 blue:0.97 alpha:1.0];
    headerLabel.shadowOffset = CGSizeMake(0.0, 1.0);
    if (self.feedId && section == 0) {
        headerLabel.text = @"SITE NOTIFICATIONS";
    } else {
        headerLabel.text = @"ALL NOTIFICATIONS";
    }
    
    customView.backgroundColor = [UIColorFromRGB(0xF7F7F5)
                                  colorWithAlphaComponent:0.8];
    [customView addSubview:headerLabel];
    
    UIImage *folderImage;
    int folderImageViewX = 10;
    
    if (self.feedId && section == 0) {
        folderImage = [UIImage imageNamed:@"menu_icn_notifications.png"];
    } else {
        folderImage = [UIImage imageNamed:@"menu_icn_notifications.png"];
    }
    folderImageViewX = 9;
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
    return MAX(appDelegate.notificationFeedIds.count, 1);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGRect vb = self.view.bounds;
    
    static NSString *CellIdentifier = @"NotificationFeedCellIdentifier";
    NotificationFeedCell *cell = [tableView
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[NotificationFeedCell alloc]
                initWithStyle:UITableViewCellStyleValue1
                reuseIdentifier:CellIdentifier];
    }
    
    if (appDelegate.notificationFeedIds.count == 0) {
        UILabel *msg = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, vb.size.width, 140)];
        [cell.contentView addSubview:msg];
        msg.text = @"No results.";
        msg.textColor = UIColorFromRGB(0x7a7a7a);
        if (vb.size.width > 320) {
            msg.font = [UIFont fontWithName:@"Helvetica-Bold" size: 20.0];
        } else {
            msg.font = [UIFont fontWithName:@"Helvetica-Bold" size: 14.0];
        }
        msg.textAlignment = NSTextAlignmentCenter;
    } else {
        NSDictionary *feed;
        NSString *feedIdStr;
        if (self.feedId && indexPath.section == 0) {
            feedIdStr = feedId;
            feed = [appDelegate.dictFeeds objectForKey:feedId];
        } else {
            feedIdStr = [NSString stringWithFormat:@"%@",
                         appDelegate.notificationFeedIds[indexPath.row]];
            feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        }
        cell.feedId = feedIdStr;
        cell.textLabel.text = [feed objectForKey:@"feed_title"];
        cell.imageView.image = [self.appDelegate getFavicon:feedIdStr isSocial:NO isSaved:NO];
        cell.detailTextLabel.text = [NSString localizedStringWithFormat:NSLocalizedString(@"%@ stories/month", @"average stories per month"), feed[@"average_stories_per_month"]];
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

@end
