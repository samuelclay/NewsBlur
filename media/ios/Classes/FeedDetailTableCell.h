//
//  FeedDetailTableCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/14/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface FeedDetailTableCell : UITableViewCell {
    // All views
    UILabel *storyTitle;
    UILabel *storyAuthor;
    UILabel *storyDate;
    UIImageView *storyUnreadIndicator;
    
    // River view    
    UILabel *siteTitle;
    UIImageView *siteFavicon;
    UIView *feedGradient;
}

@property (nonatomic) IBOutlet UIView *feedGradient;
@property (nonatomic) IBOutlet UILabel *siteTitle;
@property (nonatomic) IBOutlet UIImageView *siteFavicon;

@property (nonatomic) IBOutlet UIImageView *storyUnreadIndicator;

@property (nonatomic) IBOutlet UILabel *storyTitle;
@property (nonatomic) IBOutlet UILabel *storyAuthor;
@property (nonatomic) IBOutlet UILabel *storyDate;

@end
