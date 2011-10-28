//
//  FeedDetailTableCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/14/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "FeedDetailTableCell.h"


@implementation FeedDetailTableCell

@synthesize storyTitle;
@synthesize storyAuthor;
@synthesize storyDate;
@synthesize storyUnreadIndicator;
@synthesize feedTitle;
@synthesize feedFavicon;
@synthesize feedGradient;

- (id)initWithStyle:(UITableViewCellStyle)style 
    reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        // Initialization code
    }
    return self;
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];
}


- (void)dealloc {
    [storyTitle release];
    [storyAuthor release];
    [storyDate release];
    [storyUnreadIndicator release];
    [feedTitle release];
    [feedFavicon release];
    [feedGradient release];
    [super dealloc];
}


@end
