//
//  StoryTitleAttributedString.m
//  NewsBlur
//
//  Created by Nicholas Riley on 1/6/2018.
//  Copyright © 2018 NewsBlur. All rights reserved.
//

#import "StoryTitleAttributedString.h"

@implementation StoryTitleAttributedString

- (instancetype)initWithAttributedString:(NSAttributedString *)attrStr plainString:(NSString *)plainStr {
    if ( (self = [self init]) != nil) {
        attributedString = attrStr;
        plainString = plainStr;
    }
    return self;
}

+ (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider {
    return NSAttributedString.writableTypeIdentifiersForItemProvider;
}

#pragma mark - NSItemProviderWriting

- (nullable NSProgress *)loadDataWithTypeIdentifier:(nonnull NSString *)typeIdentifier forItemProviderCompletionHandler:(nonnull void (^)(NSData * _Nullable, NSError * _Nullable))completionHandler {

    // NSLog(@"drag type identifier requested: %@", typeIdentifier);

    if ([typeIdentifier isEqualToString:(NSString *)kUTTypeUTF8PlainText])
        return [plainString loadDataWithTypeIdentifier:typeIdentifier forItemProviderCompletionHandler:completionHandler];

    return [attributedString loadDataWithTypeIdentifier:typeIdentifier forItemProviderCompletionHandler:completionHandler];
}

@end
