//
//  OSKQuoteSmartener.m
//  Overshare
//
//  Created by Jared on 1/25/14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

#import "OSKSmartPunctuation.h"

#import "NSString+OSKEmoji.h"
#import "OSKLogger.h"

static NSString *dumbSingle = @"'";
static NSString *dumbDouble = @"\"";
static NSString *smartLeftSingle = @"‘";
static NSString *smartLeftDouble = @"“";
static NSString *smartRightSingle = @"’";
static NSString *smartRightDouble = @"”";
static NSString *dash = @"-";
static NSString *en_dash = @"–";
static NSString *em_dash = @"—";
static NSString *dot = @".";
static NSString *elipsis = @"…";

static NSString *regexThatShouldBeFollowedByLeftQuotes_leftToRight = @"(\\s|\\(|\\[|\\{|\\<|\\〈|‘|“|'|\")";
static NSString *regexThatShouldBeFollowedByRightQuotes_RightToLeft = @"(\\s|\\(|\\[|\\{|\\<|\\〈|’|”|'|\")";

typedef NS_ENUM(NSInteger, OSKQuoteDirection) {
    OSKQuoteDirection_Left,
    OSKQuoteDirection_Right,
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

@interface OSKSmartPunctuationComposedCharacterItem : NSObject

@property (copy, nonatomic) NSString *string;
@property (assign, nonatomic) NSRange range;

@end

@implementation OSKSmartPunctuationComposedCharacterItem

- (NSString *)description {
    return [NSString stringWithFormat:@"%lu, %lu string: %@", (unsigned long)self.range.location, (unsigned long)self.range.length, self.string];
}

@end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

@implementation OSKSmartPunctuation

#pragma mark - Public

+ (NSInteger)fixDumbPunctuation:(NSTextStorage *)textStorage
                    editedRange:(NSRange)editedRange
                textInputObject:(id<UITextInput>)textInputObject {
    
    // Not every edit should trigger a punctuation fix.

    if ([self _shouldAttemptCorrections:textStorage editedRange:editedRange] == NO) {
        // Don't attempt to make corrections for this edit.
        return 0;
    }
    
    UITextWritingDirection writingDirection;
    @try {
        writingDirection = [textInputObject
                            baseWritingDirectionForPosition:textInputObject.selectedTextRange.start
                            inDirection:UITextStorageDirectionBackward];
    }
    @catch (NSException *exception) {
        writingDirection = UITextWritingDirectionLeftToRight;
    }
    @finally {
        //
    }
    
    // Make a quick fix if possible.
    
    BOOL didMakeAQuickFix = [self _attemptQuickFixes:textStorage
                                         editedRange:editedRange
                                    writingDirection:writingDirection];
    
    if (didMakeAQuickFix) {
        // Don't need to proceed after a "quick fix".
        return 0;
    }
    
    // No quick fix was possible. Let's perform a more involved procedure.
    
    NSArray *previousTwoPlusCurrent = [self _composedCharacterItems:textStorage
                                                  startingWithRange:editedRange
                                               desiredPreviousCount:2
                                              desiredFollowingCount:0];
    
    // Elipses
    
    BOOL fixedAnElipsis = [self _attemptElipsisFix:textStorage
                                       editedRange:editedRange
                                  targetCharacterItems:previousTwoPlusCurrent];
    
    if (fixedAnElipsis) {
        // No need to proceed.
        return -2;
    }
    
    // Dashes
    
    NSInteger dashFixLengthChange = [self _attemptDashFix:textStorage
                                              editedRange:editedRange
                                     targetCharacterItems:previousTwoPlusCurrent
                                         writingDirection:writingDirection];
    
    if (dashFixLengthChange != 0) {
        // No need to proceed.
        return dashFixLengthChange;
    }
    
    // Smart Quotes
    
    [self _attemptSmartQuoteFixes:textStorage editedRange:editedRange writingDirection:writingDirection];
    
    return 0;
}

#pragma mark - Private

+ (BOOL)_shouldAttemptCorrections:(NSTextStorage *)textStorage
                      editedRange:(NSRange)editedRange {
    
    BOOL shouldAttempt = YES;
    
    if (editedRange.length < 1) {
        // User performed a delete or cut. Don't make any edits.
        shouldAttempt = NO;
    }
    else {
        NSString *editedPortion = [textStorage.string substringWithRange:editedRange];
        NSInteger composedLength = [editedPortion osk_lengthAdjustingForComposedCharacters];
        if (composedLength != 1) {
            // User performed a copy/paste operation. Don't make any edits.
            shouldAttempt = NO;
        }
    }
    
    return shouldAttempt;
}

+ (NSArray *)_composedCharacterItems:(NSTextStorage *)textStorage
                   startingWithRange:(NSRange)editedRange
                desiredPreviousCount:(NSInteger)desiredPreviousCount
               desiredFollowingCount:(NSInteger)desiredFollowingCount {
    
    NSMutableArray *characters = [[NSMutableArray alloc] init];
    
    __block NSInteger numberOfPrevious = 0;
    
    if (desiredPreviousCount) {
        [textStorage.string
         enumerateSubstringsInRange:NSMakeRange(0, editedRange.location)
         options:NSStringEnumerationReverse | NSStringEnumerationByComposedCharacterSequences
         usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
             
             OSKSmartPunctuationComposedCharacterItem *item = [[OSKSmartPunctuationComposedCharacterItem alloc] init];
             item.string = substring;
             item.range = substringRange;
             [characters insertObject:item atIndex:0];
             
             numberOfPrevious++;
             
             if (numberOfPrevious >= desiredPreviousCount) {
                 *stop = YES;
             }
         }];
    }
    
    
    NSString *centerCharacter = [textStorage.string substringWithRange:editedRange];
    if (centerCharacter) {
        OSKSmartPunctuationComposedCharacterItem *item = [[OSKSmartPunctuationComposedCharacterItem alloc] init];
        item.string = centerCharacter;
        item.range = editedRange;
        [characters addObject:item];
    } else {
        NSAssert(NO, @"Something went wrong. The edited range must not be valid.");
    }
    
    __block NSInteger numberOfFollowing = 0;
    
    if (desiredFollowingCount && editedRange.location + editedRange.length < textStorage.string.length) {
        NSInteger start = editedRange.location + editedRange.length;
        NSInteger length = textStorage.length - start;
        [textStorage.string
         enumerateSubstringsInRange:NSMakeRange(start, length)
         options:NSStringEnumerationByComposedCharacterSequences
         usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
             
             OSKSmartPunctuationComposedCharacterItem *item = [[OSKSmartPunctuationComposedCharacterItem alloc] init];
             item.string = substring;
             item.range = substringRange;
             [characters addObject:item];
             
             numberOfFollowing++;
             
             if (numberOfFollowing >= desiredFollowingCount) {
                 *stop = YES;
             }
         }];
    }
    
    return characters;
}

+ (BOOL)_attemptQuickFixes:(NSTextStorage *)textStorage
               editedRange:(NSRange)editedRange
          writingDirection:(UITextWritingDirection)writingDirection {
    
    BOOL didMakeQuickFix = NO;
    
    if (editedRange.location == 0) {
        
        // Quick check for opening quotes, which are easy to solve.
        
        NSString *editedPortion = [textStorage.string substringWithRange:editedRange];
        
        if ([editedPortion isEqualToString:dumbSingle]) {
            if (writingDirection == UITextWritingDirectionLeftToRight || writingDirection == UITextWritingDirectionNatural) {
                [textStorage replaceCharactersInRange:editedRange withString:smartLeftSingle];
            } else {
                [textStorage replaceCharactersInRange:editedRange withString:smartRightSingle];
            }
            didMakeQuickFix = YES;
        }
        else if ([editedPortion isEqualToString:dumbDouble]) {
            if (writingDirection == UITextWritingDirectionLeftToRight || writingDirection == UITextWritingDirectionNatural) {
                [textStorage replaceCharactersInRange:editedRange withString:smartLeftDouble];
            } else {
                [textStorage replaceCharactersInRange:editedRange withString:smartRightDouble];
            }
            didMakeQuickFix = YES;
        }
    }
    
    return didMakeQuickFix;
}

+ (BOOL)_attemptElipsisFix:(NSTextStorage *)textStorage
               editedRange:(NSRange)editedRange
      targetCharacterItems:(NSArray *)targetCharacterItems {
    
    BOOL fixed = NO;
    NSInteger count = targetCharacterItems.count;
    
    if (count >= 3) {
        
        OSKSmartPunctuationComposedCharacterItem *typedItem = [targetCharacterItems lastObject];
        NSString *typedCharacter = typedItem.string;
        
        if ([typedCharacter isEqualToString:dot]) {
            OSKSmartPunctuationComposedCharacterItem *prevPrevItem = nil;
            OSKSmartPunctuationComposedCharacterItem *prevItem = nil;
            
            prevPrevItem = targetCharacterItems[count-3];
            prevItem = targetCharacterItems[count-2];
            
            NSString *prevPevChar = prevPrevItem.string;
            NSString *prevChar = prevItem.string;
            
            if ([prevPevChar isEqualToString:dot] && [prevChar isEqualToString:dot]) {
                NSRange replacementRange = NSMakeRange(editedRange.location-2, 3);
                [textStorage replaceCharactersInRange:replacementRange withString:elipsis];
                fixed = YES;
            }
        }
    }
    
    return fixed;
}

+ (NSInteger)_attemptDashFix:(NSTextStorage *)textStorage
                 editedRange:(NSRange)editedRange
        targetCharacterItems:(NSArray *)targetCharacterItems
            writingDirection:(UITextWritingDirection)writingDirection {
    
    NSInteger lengthChange = 0;
    NSInteger count = targetCharacterItems.count;
    
    if (count >= 3) {
        
        OSKSmartPunctuationComposedCharacterItem *prevPrevItem = nil;
        OSKSmartPunctuationComposedCharacterItem *prevItem = nil;
        
        prevPrevItem = targetCharacterItems[count-3];
        prevItem = targetCharacterItems[count-2];
        
        NSString *prevPevChar = prevPrevItem.string;
        NSString *prevChar = prevItem.string;
        
        if ([prevPevChar isEqualToString:dash] && [prevChar isEqualToString:dash]) {
            
            OSKSmartPunctuationComposedCharacterItem *typedItem = [targetCharacterItems lastObject];
            NSString *typedCharacter = typedItem.string;

            if ([typedCharacter isEqualToString:dash]) {
                NSRange replacementRange = NSMakeRange(editedRange.location-2, 3);
                [textStorage replaceCharactersInRange:replacementRange withString:em_dash];
                lengthChange = -2;
            }
            else {
                NSRange replacementRange = NSMakeRange(editedRange.location-2, 2);
                [textStorage replaceCharactersInRange:replacementRange withString:en_dash];
                
                lengthChange = -1;
                
                if ([typedCharacter isEqualToString:dumbSingle]) {
                    if (writingDirection == UITextWritingDirectionLeftToRight || writingDirection == UITextWritingDirectionNatural) {
                        [textStorage replaceCharactersInRange:editedRange withString:smartLeftSingle];
                    } else {
                        [textStorage replaceCharactersInRange:editedRange withString:smartRightSingle];
                    }
                }
                else if ([typedCharacter isEqualToString:dumbDouble]) {
                    if (writingDirection == UITextWritingDirectionLeftToRight) {
                        [textStorage replaceCharactersInRange:editedRange withString:smartLeftDouble];
                    } else {
                        [textStorage replaceCharactersInRange:editedRange withString:smartRightDouble];
                    }
                }
            }
        }
    }
    
    return lengthChange;
}

+ (void)_attemptSmartQuoteFixes:(NSTextStorage *)textStorage
                    editedRange:(NSRange)editedRange
               writingDirection:(UITextWritingDirection)writingDirection {
    
    // Smart quote logic is affected by the preceding *and* the following characters,
    // so the scan is different than the dash/elipsis fixes above.
    
    NSArray *editableCharacterItems = [self _composedCharacterItems:textStorage
                                                  startingWithRange:editedRange
                                               desiredPreviousCount:3
                                              desiredFollowingCount:0];
    
    // Iterate through the editable characters. None of these changes will
    // result in length changes to the text storage.
    
    for (OSKSmartPunctuationComposedCharacterItem *editableItem in editableCharacterItems) {
        
        if ([editableItem.string isEqualToString:dumbSingle]
            || [editableItem.string isEqualToString:smartLeftSingle]
            || [editableItem.string isEqualToString:smartRightSingle] )
        {
            NSArray *surroundingCharacters = [self _composedCharacterItems:textStorage
                                                         startingWithRange:editableItem.range
                                                      desiredPreviousCount:1
                                                     desiredFollowingCount:4];
            
            NSString *replacement = [self _replacementStringForSingleQuoteAtIndex:1
                                                                 inCharacterItems:surroundingCharacters
                                                                 writingDirection:writingDirection];
            if (replacement) {
                [textStorage replaceCharactersInRange:editableItem.range withString:replacement];
            }
        }
        else if ([editableItem.string isEqualToString:dumbDouble]) {
            NSArray *surroundingCharacters = [self _composedCharacterItems:textStorage
                                                         startingWithRange:editableItem.range
                                                      desiredPreviousCount:1
                                                     desiredFollowingCount:4];
            NSString *replacement = [self _replacementStringForDumbDoubleQuoteAtIndex:1
                                                                     inCharacterItems:surroundingCharacters
                                                                     writingDirection:writingDirection];
            if (replacement) {
                [textStorage replaceCharactersInRange:editableItem.range withString:replacement];
            }
        }
    }
}

+ (NSString *)_replacementStringForSingleQuoteAtIndex:(NSInteger)index
                                     inCharacterItems:(NSArray *)items
                                     writingDirection:(UITextWritingDirection)writingDirection {
    
    NSString *replacement = nil;
    
    if (index > 0) {
        OSKSmartPunctuationComposedCharacterItem *prevItem = items[index-1];
        NSString *prevCharacter = prevItem.string;
        OSKQuoteDirection quoteDirection = [self _quoteDirectionThatShouldFollowCharacter:prevCharacter
                                                                             forDirection:writingDirection];
        if (quoteDirection == OSKQuoteDirection_Left) {
            replacement = smartLeftSingle;
        } else {
            replacement = smartRightSingle;
        }
        
        if ((writingDirection == UITextWritingDirectionLeftToRight || writingDirection == UITextWritingDirectionNatural)
            && quoteDirection == OSKQuoteDirection_Left) {
            // Fix for decades abbreviation: ’70s, ’80s, ’90s and so forth.
            if ( (items.count - index - 1) >= 3) {
                NSInteger tensPlaceIndex = index+1;
                NSInteger zerosPlaceIndex = index+2;
                NSInteger pluralSIndex = index+3;
                OSKSmartPunctuationComposedCharacterItem *tensItem = items[tensPlaceIndex];
                OSKSmartPunctuationComposedCharacterItem *zerosItem = items[zerosPlaceIndex];
                OSKSmartPunctuationComposedCharacterItem *pluralItem = items[pluralSIndex];
                if ([tensItem.string rangeOfString:@"[0-9]" options:NSRegularExpressionSearch].location != NSNotFound) {
                    if ([zerosItem.string isEqualToString:@"0"]) {
                        if ([pluralItem.string compare:@"s" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                            replacement = smartRightSingle;
                        }
                    }
                }
            }
        }
    }
    
    return replacement;
}

+ (NSString *)_replacementStringForDumbDoubleQuoteAtIndex:(NSInteger)index
                                         inCharacterItems:(NSArray *)items
                                         writingDirection:(UITextWritingDirection)writingDirection {
    NSString *replacement = nil;
    
    if (index > 0) {
        OSKSmartPunctuationComposedCharacterItem *prevItem = items[index-1];
        NSString *prevCharacter = prevItem.string;
        OSKQuoteDirection quoteDirection = [self _quoteDirectionThatShouldFollowCharacter:prevCharacter
                                                                             forDirection:writingDirection];
        if (quoteDirection == OSKQuoteDirection_Left) {
            replacement = smartLeftDouble;
        } else {
            replacement = smartRightDouble;
        }
    }
    
    return replacement;
}

+ (OSKQuoteDirection)_quoteDirectionThatShouldFollowCharacter:(NSString *)character
                                                 forDirection:(UITextWritingDirection)writingDirection {
    
    OSKQuoteDirection quoteDirection;
    
    if (writingDirection == UITextWritingDirectionLeftToRight || writingDirection == UITextWritingDirectionNatural) {
        NSRange regexRange = [character rangeOfString:regexThatShouldBeFollowedByLeftQuotes_leftToRight options:NSRegularExpressionSearch];
        if (regexRange.location != NSNotFound) {
            quoteDirection = OSKQuoteDirection_Left;
        } else {
            quoteDirection = OSKQuoteDirection_Right;
        }
    }
    else /* Right to Left */{
        NSRange regexRange = [character rangeOfString:regexThatShouldBeFollowedByRightQuotes_RightToLeft options:NSRegularExpressionSearch];
        if (regexRange.location != NSNotFound) {
            quoteDirection = OSKQuoteDirection_Right;
        } else {
            quoteDirection = OSKQuoteDirection_Left;
        }
    }
    
    return quoteDirection;
}

@end



