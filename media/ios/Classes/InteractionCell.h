//
//  InteractionCell.h
//  NewsBlur
//
//  Created by Roy Yang on 7/16/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OHAttributedLabel.h"

@interface InteractionCell : UIView {
    OHAttributedLabel *interactionLabel;
}

@property (retain, nonatomic) OHAttributedLabel *interactionLabel;

- (int)refreshInteraction:(NSDictionary *)interaction withWidth:(int)width;
- (NSString *)stripFormatting:(NSString *)str;
@end