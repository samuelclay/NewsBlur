//
//  FeedChooserTitleView.h
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-22.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

@protocol FeedChooserTitleDelegate <NSObject>

- (void)didSelectTitleView:(UIButton *)sender;

@end

@interface FeedChooserTitleView : UIView

@property (nonatomic) NSUInteger section;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, weak) id delegate;

@end
