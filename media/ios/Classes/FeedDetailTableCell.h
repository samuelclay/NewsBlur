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

@property (nonatomic, retain) IBOutlet UILabel *storyTitle;
@property (nonatomic, retain) IBOutlet UILabel *storyAuthor;
@property (nonatomic, retain) IBOutlet UILabel *storyDate;
@property (nonatomic, retain) IBOutlet UIImageView *storyUnreadIndicator;

@property (nonatomic, retain) IBOutlet UIView *feedGradient;

@end
