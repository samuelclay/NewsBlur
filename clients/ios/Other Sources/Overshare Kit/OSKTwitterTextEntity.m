//
//  OSKTwitterTextEntity.m
//
//  Copyright 2012 Twitter, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

#import "OSKTwitterTextEntity.h"

@implementation OSKTwitterTextEntity

@synthesize type;
@synthesize range;

- (id)initWithType:(OSKTwitterTextEntityType)aType range:(NSRange)aRange
{
    self = [super init];
    if (self) {
        type = aType;
        range = aRange;
    }
    return self;
}

+ (id)entityWithType:(OSKTwitterTextEntityType)type range:(NSRange)range
{
    OSKTwitterTextEntity *entity = [[self alloc] initWithType:type range:range];
#if !__has_feature(objc_arc)
    [entity autorelease];
#endif
    return entity;
}

- (NSComparisonResult)compare:(OSKTwitterTextEntity*)right
{
    NSInteger leftLocation = range.location;
    NSInteger leftLength = range.length;
    NSRange rightRange = right.range;
    NSInteger rightLocation = rightRange.location;
    NSInteger rightLength = rightRange.length;
    
    if (leftLocation < rightLocation) {
        return NSOrderedAscending;
    } else if (leftLocation > rightLocation) {
        return NSOrderedDescending;
    } else if (leftLength < rightLength) {
        return NSOrderedAscending;
    } else if (leftLength > rightLength) {
        return NSOrderedDescending;
    } else {
        return NSOrderedSame;
    }
}

- (NSString*)description
{
    NSString *typeString = nil;
    switch (type) {
        case OSKTwitterTextEntityURL:
            typeString = @"URL";
            break;
        case OSKTwitterTextEntityScreenName:
            typeString = @"ScreenName";
            break;
        case OSKTwitterTextEntityHashtag:
            typeString = @"Hashtag";
            break;
        case OSKTwitterTextEntityListName:
            typeString = @"ListName";
            break;
        case OSKTwitterTextEntitySymbol:
            typeString = @"Symbol";
            break;
    }
    return [NSString stringWithFormat:@"<%@: %@ %@>", NSStringFromClass([self class]), typeString, NSStringFromRange(range)];
}

@end
