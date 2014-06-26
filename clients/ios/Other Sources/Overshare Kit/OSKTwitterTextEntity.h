//
//  OSKTwitterTextEntity.h
//
//  Copyright 2012 Twitter, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// Via:
// https://github.com/twitter/twitter-text-objc

@import Foundation;

typedef enum {
    OSKTwitterTextEntityURL,
    OSKTwitterTextEntityScreenName,
    OSKTwitterTextEntityHashtag,
    OSKTwitterTextEntityListName,
    OSKTwitterTextEntitySymbol,
} OSKTwitterTextEntityType;

@interface OSKTwitterTextEntity : NSObject

@property (nonatomic, assign) OSKTwitterTextEntityType type;
@property (nonatomic, assign) NSRange range;
@property (assign, nonatomic) BOOL screenNameIsValid; // Means the user exists in the ADNUserController

+ (id)entityWithType:(OSKTwitterTextEntityType)type range:(NSRange)range;

@end
