//
//  FeedDetailTableCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/14/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface FeedDetailTableCell : UITableViewCell {
    // Feed view
    UILabel *storyTitle;
    UILabel *storyAuthor;
    UILabel *storyDate;
    UIImageView *storyUnreadIndicator;
    
    // River view
    UIView *feedGradient;
}

@property (nonatomic) IBOutlet UILabel *storyTitle;
@property (nonatomic) IBOutlet UILabel *storyAuthor;
@property (nonatomic) IBOutlet UILabel *storyDate;
@property (nonatomic) IBOutlet UIImageView *storyUnreadIndicator;

@property (nonatomic) IBOutlet UIView *feedGradient;

@end
