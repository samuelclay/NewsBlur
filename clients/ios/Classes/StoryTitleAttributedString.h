//
//  StoryTitleAttributedString.h
//  NewsBlur
//
//  Created by Nicholas Riley on 1/6/2018.
//  Copyright © 2018 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StoryTitleAttributedString : NSObject <NSItemProviderWriting>
{
    NSAttributedString *attributedString;
    NSString *plainString;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attrStr plainString:(NSString *)plainStr;

@end
