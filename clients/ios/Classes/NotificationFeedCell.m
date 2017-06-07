//
//  NotificationFeedCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/23/16.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "NotificationFeedCell.h"
#import "NewsBlurAppDelegate.h"

@implementation NotificationFeedCell

@synthesize appDelegate;
@synthesize filterControl;
@synthesize notificationTypeControl;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        // Initialization code
        self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];

        self.tintColor = UIColorFromRGB(0x707070);
        self.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
        self.detailTextLabel.font = [UIFont fontWithName:@"Helvetica" size:13.0];
        [self setSeparatorInset:UIEdgeInsetsMake(0, 38, 0, 0)];
        UIView *background = [[UIView alloc] init];
        [background setBackgroundColor:UIColorFromRGB(0xFFFFFF)];
        [self setBackgroundView:background];
        
        UIView *selectedBackground = [[UIView alloc] init];
        [selectedBackground setBackgroundColor:UIColorFromRGB(0xECEEEA)];
        [self setSelectedBackgroundView:selectedBackground];
        
        NSDictionary *controlAttrs = @{NSForegroundColorAttributeName: [UIColor lightGrayColor]};
        self.filterControl = [[UISegmentedControl alloc] initWithItems:@[@"Unread Stories",
                                                                         @"Focus Stories"]];
        self.filterControl.tintColor = UIColorFromRGB(0x8F918B);
        [self.filterControl.subviews objectAtIndex:1].accessibilityLabel = @"Focus Stories";
        [self.filterControl.subviews objectAtIndex:0].accessibilityLabel = @"Unread Stories";
        [self.filterControl setTitle:@"Unread Stories" forSegmentAtIndex:0];
        [self.filterControl setTitle:@"Focus Stories" forSegmentAtIndex:1];
        [self.filterControl setImage:[UIImage imageNamed:@"unread_yellow.png"] forSegmentAtIndex:0];
        [self.filterControl setImage:[UIImage imageNamed:@"unread_green.png"] forSegmentAtIndex:1];
        [self.filterControl setWidth:CGRectGetWidth(self.frame)*0.44 forSegmentAtIndex:0];
        [self.filterControl setWidth:CGRectGetWidth(self.frame)*0.44 forSegmentAtIndex:1];
        [self.filterControl setTitleTextAttributes:controlAttrs forState:UIControlStateNormal];
        self.filterControl.frame = CGRectMake(36, 38, CGRectGetWidth(self.frame), 28);
        [self.contentView addSubview:self.filterControl];
        
        self.notificationTypeControl = [[MultiSelectSegmentedControl alloc] initWithItems:@[@"Email",
                                                                         @"Web",
                                                                         @"iOS",
                                                                         @"Android"]];
        self.notificationTypeControl.delegate = self;
        self.notificationTypeControl.tintColor = UIColorFromRGB(0x8F918B);
        [self.notificationTypeControl.subviews objectAtIndex:0].accessibilityLabel = @"Email";
        [self.notificationTypeControl.subviews objectAtIndex:1].accessibilityLabel = @"Web";
        [self.notificationTypeControl.subviews objectAtIndex:2].accessibilityLabel = @"iOS";
        [self.notificationTypeControl.subviews objectAtIndex:3].accessibilityLabel = @"Android";
        [self.notificationTypeControl setTitle:@"Email" forSegmentAtIndex:0];
        [self.notificationTypeControl setTitle:@"Web" forSegmentAtIndex:1];
        [self.notificationTypeControl setTitle:@"iOS" forSegmentAtIndex:2];
        [self.notificationTypeControl setTitle:@"Android" forSegmentAtIndex:3];
        [self.notificationTypeControl setWidth:CGRectGetWidth(self.frame)*0.22 forSegmentAtIndex:0];
        [self.notificationTypeControl setWidth:CGRectGetWidth(self.frame)*0.22 forSegmentAtIndex:1];
        [self.notificationTypeControl setWidth:CGRectGetWidth(self.frame)*0.22 forSegmentAtIndex:2];
        [self.notificationTypeControl setWidth:CGRectGetWidth(self.frame)*0.22 forSegmentAtIndex:3];
        [self.notificationTypeControl setTitleTextAttributes:controlAttrs forState:UIControlStateNormal];
        self.notificationTypeControl.frame = CGRectMake(36, 76, CGRectGetWidth(self.frame), 28);
        [self.contentView addSubview:self.notificationTypeControl];
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.textLabel.backgroundColor = [UIColor clearColor];
    self.textLabel.textColor = UIColorFromRGB(0x303030);
    self.textLabel.shadowColor = UIColorFromRGB(0xF0F0F0);
    self.textLabel.shadowOffset = CGSizeMake(0, 1);
    self.textLabel.highlightedTextColor = UIColorFromRGB(0x303030);
    self.detailTextLabel.highlightedTextColor = UIColorFromRGB(0x505050);
    self.detailTextLabel.textColor = UIColorFromRGB(0x505050);
    self.backgroundColor = UIColorFromRGB(0xFFFFFF);
    self.backgroundView.backgroundColor = UIColorFromRGB(0xFFFFFF);
    self.selectedBackgroundView.backgroundColor = UIColorFromRGB(0xECEEEA);
    
    self.imageView.frame = CGRectMake(10.0, 10.0, 16.0, 16.0);
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    [self.textLabel sizeToFit];
    CGRect frame = self.textLabel.frame;
    frame.origin.x = 35.0;
    frame.size.width = self.detailTextLabel.frame.origin.x - self.textLabel.frame.origin.x;
    self.textLabel.frame = frame;
        CGRect textFrame = self.textLabel.frame;
    textFrame.origin.y = 10;
    self.textLabel.frame = textFrame;

    CGRect detailFrame = self.detailTextLabel.frame;
    detailFrame.origin.y = 10;
    self.detailTextLabel.frame = detailFrame;

    CGFloat detailTextLabelWidth = self.detailTextLabel.attributedText.size.width;
    CGRect detailTextLabelFrame = self.detailTextLabel.frame;
    CGFloat detailTextLabelExtraWidth = detailTextLabelWidth - detailTextLabelFrame.size.width;
    if (detailTextLabelExtraWidth > 0) {
        detailTextLabelFrame.origin.x -= detailTextLabelExtraWidth;
        detailTextLabelFrame.size.width = detailTextLabelWidth;
        self.detailTextLabel.frame = detailTextLabelFrame;
        
        CGRect textLabelFrame = self.textLabel.frame;
        textLabelFrame.size.width = self.detailTextLabel.frame.origin.x - self.textLabel.frame.origin.x;
        self.textLabel.frame = textLabelFrame;
    }
    
    NSDictionary *feed = [appDelegate.dictFeeds objectForKey:self.feedId];
    if ([[feed objectForKey:@"notification_filter"] isEqualToString:@"focus"]) {
        self.filterControl.selectedSegmentIndex = 1;
    } else {
        self.filterControl.selectedSegmentIndex = 0;
    }
    
    NSMutableIndexSet *types = [NSMutableIndexSet indexSet];
    NSArray *notificationTypes = [feed objectForKey:@"notification_types"];
    if ([notificationTypes containsObject:@"email"]) [types addIndex:0];
    if ([notificationTypes containsObject:@"web"]) [types addIndex:1];
    if ([notificationTypes containsObject:@"ios"]) [types addIndex:2];
    if ([notificationTypes containsObject:@"android"]) [types addIndex:3];
    [self.notificationTypeControl setSelectedSegmentIndexes:types];
}

- (void)multiSelect:(MultiSelectSegmentedControl *)multiSelectSegmendedControl didChangeValue:(BOOL)value atIndex:(NSUInteger)index {
    [self saveNotifications];
}

- (void)saveNotifications {
    NSMutableArray *notificationTypes = [NSMutableArray array];
    NSString *notificationFilter = self.filterControl.selectedSegmentIndex == 0 ? @"unread": @"focus";
    
    if ([self.notificationTypeControl.selectedSegmentIndexes containsIndex:0])
        [notificationTypes addObject:@"email"];
    if ([self.notificationTypeControl.selectedSegmentIndexes containsIndex:1])
        [notificationTypes addObject:@"web"];
    if ([self.notificationTypeControl.selectedSegmentIndexes containsIndex:2])
        [notificationTypes addObject:@"ios"];
    if ([self.notificationTypeControl.selectedSegmentIndexes containsIndex:3])
        [notificationTypes addObject:@"android"];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:self.feedId forKey:@"feed_id"];
    NSMutableArray *notifications = [NSMutableArray array];
    for (NSString *notificationType in notificationTypes) {
        [notifications addObject:notificationType];
    }
    [params setObject:notifications forKey:@"notification_types"];
    [params setObject:notificationFilter forKey:@"notification_filter"];

    [appDelegate updateNotifications:params feed:self.feedId];
}

@end
