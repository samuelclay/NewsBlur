//
//  NBLoadingCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/12/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NBLoadingCell : UITableViewCell

@property (nonatomic, readwrite) BOOL animating;

- (void)animate;
- (void)endAnimation;

@end
