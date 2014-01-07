//
//  OSKTwitterText.h
//
//  Copyright 2012 Twitter, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

@import Foundation;

#import "OSKTwitterTextEntity.h"

@interface OSKTwitterText : NSObject

+ (NSArray*)entitiesInText:(NSString*)text;
+ (NSArray*)URLsInText:(NSString*)text;
+ (NSArray*)hashtagsInText:(NSString*)text checkingURLOverlap:(BOOL)checkingURLOverlap;
+ (NSArray*)symbolsInText:(NSString*)text checkingURLOverlap:(BOOL)checkingURLOverlap;
+ (NSArray*)mentionedScreenNamesInText:(NSString*)text;
+ (NSArray*)mentionsOrListsInText:(NSString*)text;
+ (OSKTwitterTextEntity*)repliedScreenNameInText:(NSString*)text;

+ (NSInteger)tweetLength:(NSString*)text;
+ (NSInteger)tweetLength:(NSString*)text httpURLLength:(NSInteger)httpURLLength httpsURLLength:(NSInteger)httpsURLLength;

+ (NSInteger)remainingCharacterCount:(NSString*)text;
+ (NSInteger)remainingCharacterCount:(NSString*)text httpURLLength:(NSInteger)httpURLLength httpsURLLength:(NSInteger)httpsURLLength;

@end
