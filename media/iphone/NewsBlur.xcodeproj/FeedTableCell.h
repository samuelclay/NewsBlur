//
//  FeedTableCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/18/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ABTableViewCell.h"


@interface FeedTableCell : ABTableViewCell {    
    UILabel *feedTitle;
    UIImageView *feedFavicon;
    int _positiveCount;
    int _neutralCount;
    int _negativeCount;
    NSString *_positiveCountStr;
    NSString *_neutralCountStr;
    NSString *_negativeCountStr;
}

@property (nonatomic, retain) IBOutlet UILabel *feedTitle;
@property (nonatomic, retain) IBOutlet UIImageView *feedFavicon;
@property (assign, nonatomic) int positiveCount;
@property (assign, nonatomic) int neutralCount;
@property (assign, nonatomic) int negativeCount;
@property (nonatomic, retain) NSString *positiveCountStr;
@property (nonatomic, retain) NSString *neutralCountStr;
@property (nonatomic, retain) NSString *negativeCountStr;

@end
