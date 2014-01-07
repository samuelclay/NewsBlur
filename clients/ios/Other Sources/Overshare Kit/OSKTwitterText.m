//
//  OSKTwitterText.m
//
//  Copyright 2012 Twitter, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//

#import "OSKTwitterText.h"

//
// These regular expressions are ported from twitter-text-rb on Apr 24 2012.
//

#define TWUControlCharacters        @"\\u0009-\\u000D"
#define TWUSpace                    @"\\u0020"
#define TWUControl85                @"\\u0085"
#define TWUNoBreakSpace             @"\\u00A0"
#define TWUOghamBreakSpace          @"\\u1680"
#define TWUMongolianVowelSeparator  @"\\u180E"
#define TWUWhiteSpaces              @"\\u2000-\\u200A"
#define TWULineSeparator            @"\\u2028"
#define TWUParagraphSeparator       @"\\u2029"
#define TWUNarrowNoBreakSpace       @"\\u202F"
#define TWUMediumMathematicalSpace  @"\\u205F"
#define TWUIdeographicSpace         @"\\u3000"

#define TWUUnicodeSpaces \
    TWUControlCharacters \
    TWUSpace \
    TWUControl85 \
    TWUNoBreakSpace \
    TWUOghamBreakSpace \
    TWUMongolianVowelSeparator \
    TWUWhiteSpaces \
    TWULineSeparator \
    TWUParagraphSeparator \
    TWUNarrowNoBreakSpace \
    TWUMediumMathematicalSpace \
    TWUIdeographicSpace

#define TWUInvalidCharacters        @"\\uFFFE\\uFEFF\\uFFFF\\u202A-\\u202E"

#define TWULatinAccents \
    @"\\u00C0-\\u00D6\\u00D8-\\u00F6\\u00F8-\\u00FF\\u0100-\\u024F\\u0253-\\u0254\\u0256-\\u0257\\u0259\\u025b\\u0263\\u0268\\u026F\\u0272\\u0289\\u02BB\\u1E00-\\u1EFF"

//
// Hashtag
//

#define TWUCyrillicHashtagChars                     @"\\u0400-\\u04FF"
#define TWUCyrillicSupplementHashtagChars           @"\\u0500-\\u0527"
#define TWUCyrillicExtendedAHashtagChars            @"\\u2DE0-\\u2DFF"
#define TWUCyrillicExtendedBHashtagChars            @"\\uA640-\\uA69F"
#define TWUHebrewHashtagChars                       @"\\u0591-\\u05BF\\u05C1-\\u05C2\\u05C4-\\u05C5\\u05C7\\u05D0-\\u05EA\\u05F0-\\u05F4"
#define TWUHebrewPresentationFormsHashtagChars      @"\\uFB12-\\uFB28\\uFB2A-\\uFB36\\uFB38-\\uFB3C\\uFB3E\\uFB40-\\uFB41\\uFB43-\\uFB44\\uFB46-\\uFB4F"
#define TWUArabicHashtagChars                       @"\\u0610-\\u061A\\u0620-\\u065F\\u066E-\\u06D3\\u06D5-\\u06DC\\u06DE-\\u06E8\\u06EA-\\u06EF\\u06FA-\\u06FC\\u06FF"
#define TWUArabicSupplementHashtagChars             @"\\u0750-\\u077F"
#define TWUArabicExtendedAHashtagChars              @"\\u08A0\\u08A2-\\u08AC\\u08E4-\\u08FE"
#define TWUArabicPresentationFormsAHashtagChars     @"\\uFB50-\\uFBB1\\uFBD3-\\uFD3D\\uFD50-\\uFD8F\\uFD92-\\uFDC7\\uFDF0-\\uFDFB"
#define TWUArabicPresentationFormsBHashtagChars     @"\\uFE70-\\uFE74\\uFE76-\\uFEFC"
#define TWUZeroWidthNonJoiner                       @"\\u200C"
#define TWUThaiHashtagChars                         @"\\u0E01-\\u0E3A"
#define TWUHangulHashtagChars                       @"\\u0E40-\\u0E4E"
#define TWUHangulJamoHashtagChars                   @"\\u1100-\\u11FF"
#define TWUHangulCompatibilityJamoHashtagChars      @"\\u3130-\\u3185"
#define TWUHangulJamoExtendedAHashtagChars          @"\\uA960-\\uA97F"
#define TWUHangulSyllablesHashtagChars              @"\\uAC00-\\uD7AF"
#define TWUHangulJamoExtendedBHashtagChars          @"\\uD7B0-\\uD7FF"
#define TWUHalfWidthHangulHashtagChars              @"\\uFFA1-\\uFFDC"

#define TWUNonLatinHashtagChars \
    TWUCyrillicHashtagChars \
    TWUCyrillicSupplementHashtagChars \
    TWUCyrillicExtendedAHashtagChars \
    TWUCyrillicExtendedBHashtagChars \
    TWUHebrewHashtagChars \
    TWUHebrewPresentationFormsHashtagChars \
    TWUArabicHashtagChars \
    TWUArabicSupplementHashtagChars \
    TWUArabicExtendedAHashtagChars \
    TWUArabicPresentationFormsAHashtagChars \
    TWUArabicPresentationFormsBHashtagChars \
    TWUZeroWidthNonJoiner \
    TWUThaiHashtagChars \
    TWUHangulHashtagChars \
    TWUHangulJamoHashtagChars \
    TWUHangulCompatibilityJamoHashtagChars \
    TWUHangulJamoExtendedAHashtagChars \
    TWUHangulSyllablesHashtagChars \
    TWUHangulJamoExtendedBHashtagChars \
    TWUHalfWidthHangulHashtagChars

#define TWUKatakanaHashtagChars                 @"\\u30A1-\\u30FA\\u30FC-\\u30FE"
#define TWUKatakanaHalfWidthHashtagChars        @"\\uFF66-\\uFF9F"
#define TWULatinFullWidthHashtagChars           @"\\uFF10-\\uFF19\\uFF21-\\uFF3A\\uFF41-\\uFF5A"
#define TWUHiraganaHashtagChars                 @"\\u3041-\\u3096\\u3099-\\u309E"
#define TWUCJKExtensionAHashtagChars            @"\\u3400-\\u4DBF"
#define TWUCJKUnifiedHashtagChars               @"\\u4E00-\\u9FFF"
#define TWUCJKExtensionBHashtagChars            @"\\U00020000-\\U0002A6DF"
#define TWUCJKExtensionCHashtagChars            @"\\U0002A700-\\U0002B73F"
#define TWUCJKExtensionDHashtagChars            @"\\U0002B740-\\U0002B81F"
#define TWUCJKSupplementHashtagChars            @"\\U0002F800-\\U0002FA1F\\u3003\\u3005\\u303B"

#define TWUCJKHashtagCharacters \
    TWUKatakanaHashtagChars \
    TWUKatakanaHalfWidthHashtagChars \
    TWULatinFullWidthHashtagChars \
    TWUHiraganaHashtagChars \
    TWUCJKExtensionAHashtagChars \
    TWUCJKUnifiedHashtagChars \
    TWUCJKExtensionBHashtagChars \
    TWUCJKExtensionCHashtagChars \
    TWUCJKExtensionDHashtagChars \
    TWUCJKSupplementHashtagChars

#define TWUPunctuationChars                             @"\\-_!\"#$%&'()*+,./:;<=>?@\\[\\]^`{|}~"
#define TWUPunctuationCharsWithoutHyphen                @"_!\"#$%&'()*+,./:;<=>?@\\[\\]^`{|}~"
#define TWUPunctuationCharsWithoutHyphenAndUnderscore   @"!\"#$%&'()*+,./:;<=>?@\\[\\]^`{|}~"
#define TWUCtrlChars                                    @"\\x00-\\x1F\\x7F"

#define TWHashtagAlpha \
@"[a-z_" \
    TWULatinAccents \
    TWUNonLatinHashtagChars \
    TWUCJKHashtagCharacters \
@"]"

#define TWUHashtagAlphanumeric \
@"[a-z0-9_" \
    TWULatinAccents \
    TWUNonLatinHashtagChars \
    TWUCJKHashtagCharacters \
@"]"

#define TWUHashtagBoundary \
@"^|$|[^&a-z0-9_" \
    TWULatinAccents \
    TWUNonLatinHashtagChars \
    TWUCJKHashtagCharacters \
@"]"

#define TWUValidHashtag \
    @"(?:" TWUHashtagBoundary @")([#＃]" TWUHashtagAlphanumeric @"*" TWHashtagAlpha TWUHashtagAlphanumeric @"*)"

#define TWUEndHashTagMatch      @"\\A(?:[#＃]|://)"

//
// Cashtag
//

#define TWUCashtag          @"[a-z]{1,6}(?:[._][a-z]{1,2})?"
#define TWUValidCashtag \
    @"(?:^|[" TWUUnicodeSpaces @"])" \
    @"(\\$" TWUCashtag @")" \
    @"(?=$|\\s|[" TWUPunctuationChars @"])"

//
// Mention and list name
//

#define TWUValidMentionPrecedingChars   @"(?:[^a-zA-Z0-9_!#$%&*@＠]|^|RT:?)"
#define TWUAtSigns                      @"[@＠]"
#define TWUValidUsername                @"\\A" TWUAtSigns @"[a-zA-Z0-9_]{1,20}\\z"
#define TWUValidList                    @"\\A" TWUAtSigns @"[a-zA-Z0-9_]{1,20}/[a-zA-Z][a-zA-Z0-9_\\-]{0,24}\\z"

#define TWUValidMentionOrList \
    @"(" TWUValidMentionPrecedingChars @")" \
    @"(" TWUAtSigns @")" \
    @"([a-zA-Z0-9_]{1,20})" \
    @"(/[a-zA-Z][a-zA-Z0-9_\\-]{0,24})?"

#define TWUValidReply                   @"\\A(?:[" TWUUnicodeSpaces @"])*" TWUAtSigns @"([a-zA-Z0-9_]{1,20})"
#define TWUEndMentionMatch              @"\\A(?:" TWUAtSigns @"|[" TWULatinAccents @"]|://)"

//
// URL
//

#define TWUValidURLPrecedingChars       @"(?:[^a-zA-Z0-9@＠$#＃" TWUInvalidCharacters @"]|^)"

#define TWUDomainValidStartEndChars \
@"[^" \
    TWUPunctuationChars \
    TWUCtrlChars \
    TWUInvalidCharacters \
    TWUUnicodeSpaces \
@"]"

#define TWUSubdomainValidMiddleChars \
@"[^" \
    TWUPunctuationCharsWithoutHyphenAndUnderscore \
    TWUCtrlChars \
    TWUInvalidCharacters \
    TWUUnicodeSpaces \
@"]"

#define TWUDomainValidMiddleChars \
@"[^" \
    TWUPunctuationCharsWithoutHyphen \
    TWUCtrlChars \
    TWUInvalidCharacters \
    TWUUnicodeSpaces \
@"]"

#define TWUValidSubdomain \
@"(?:" \
    @"(?:" TWUDomainValidStartEndChars TWUSubdomainValidMiddleChars @"*)?" TWUDomainValidStartEndChars @"\\." \
@")"

#define TWUValidDomainName \
@"(?:" \
    @"(?:" TWUDomainValidStartEndChars TWUDomainValidMiddleChars @"*)?" TWUDomainValidStartEndChars @"\\." \
@")"

#define TWUValidGTLD    @"(?:(?:aero|asia|biz|cat|com|coop|edu|gov|info|int|jobs|mil|mobi|museum|name|net|org|pro|tel|travel|xxx)(?=[^0-9a-z]|$))"
#define TWUValidCCTLD \
@"(?:" \
    @"(?:" \
        @"ac|ad|ae|af|ag|ai|al|am|an|ao|aq|ar|as|at|au|aw|ax|az|ba|bb|bd|be|bf|bg|bh|" \
        @"bi|bj|bm|bn|bo|br|bs|bt|bv|bw|by|bz|ca|cc|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|" \
        @"cs|cu|cv|cx|cy|cz|dd|de|dj|dk|dm|do|dz|ec|ee|eg|eh|er|es|et|eu|fi|fj|fk|fm|" \
        @"fo|fr|ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gs|gt|gu|gw|gy|hk|hm|hn|hr|" \
        @"ht|hu|id|ie|il|im|in|io|iq|ir|is|it|je|jm|jo|jp|ke|kg|kh|ki|km|kn|kp|kr|kw|" \
        @"ky|kz|la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly|ma|mc|md|me|mg|mh|mk|ml|mm|mn|mo|mp|" \
        @"mq|mr|ms|mt|mu|mv|mw|mx|my|mz|na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz|om|pa|pe|" \
        @"pf|pg|ph|pk|pl|pm|pn|pr|ps|pt|pw|py|qa|re|ro|rs|ru|rw|sa|sb|sc|sd|se|sg|sh|" \
        @"si|sj|sk|sl|sm|sn|so|sr|ss|st|su|sv|sy|sz|tc|td|tf|tg|th|tj|tk|tl|tm|tn|to|" \
        @"tp|tr|tt|tv|tw|tz|ua|ug|uk|us|uy|uz|va|vc|ve|vg|vi|vn|vu|wf|ws|ye|yt|za|zm|" \
        @"zw" \
    @")" \
    @"(?=[^0-9a-z]|$)" \
@")"

#define TWUValidPunycode                @"(?:xn--[0-9a-z]+)"

#define TWUValidDomain \
@"(?:" \
    TWUValidSubdomain @"*" TWUValidDomainName \
    @"(?:" TWUValidGTLD @"|" TWUValidCCTLD @"|" TWUValidPunycode @")" \
@")"

#define TWUValidASCIIDomain \
    @"(?:[a-zA-Z0-9\\-_" TWULatinAccents @"]+\\.)+" \
    @"(?:" TWUValidGTLD @"|" TWUValidCCTLD @"|" TWUValidPunycode @")" \

#define TWUValidTCOURL                  @"https?://t\\.co/[a-zA-Z0-9]+"
#define TWUInvalidShortDomain           @"\\A" TWUValidDomainName TWUValidCCTLD @"\\z"

#define TWUValidPortNumber              @"[0-9]+"
#define TWUValidGeneralURLPathChars     @"[a-zA-Z0-9!\\*';:=+,.$/%#\\[\\]\\-_~&|@" TWULatinAccents @"]"

#define TWUValidURLBalancedParens       @"\\(" TWUValidGeneralURLPathChars @"+\\)"
#define TWUValidURLPathEndingChars      @"[a-zA-Z0-9=_#/+\\-" TWULatinAccents @"]|(?:" TWUValidURLBalancedParens @")"

#define TWUValidURLPath \
@"(?:" \
    @"(?:" \
        TWUValidGeneralURLPathChars @"*" \
        @"(?:" TWUValidURLBalancedParens TWUValidGeneralURLPathChars @"*)*" TWUValidURLPathEndingChars \
    @")" \
    @"|" \
    @"(?:" TWUValidGeneralURLPathChars @"+/)" \
@")"

#define TWUValidURLQueryChars           @"[a-zA-Z0-9!?*'\\(\\);:&=+$/%#\\[\\]\\-_\\.,~|@]"
#define TWUValidURLQueryEndingChars     @"[a-zA-Z0-9_&=#/]"

#define TWUValidURL \
@"(" \
    @"(" TWUValidURLPrecedingChars @")" \
    @"(" \
        @"(https?://)?" \
        @"(" TWUValidDomain @")" \
        @"(?::(" TWUValidPortNumber @"))?" \
        @"(/" TWUValidURLPath @"*)?" \
        @"(\\?" TWUValidURLQueryChars @"*" TWUValidURLQueryEndingChars @")?" \
    @")" \
@")"

static const NSInteger MaxTweetLength = 140;
static const NSInteger HTTPShortURLLength = 22;
static const NSInteger HTTPSShortURLLength = 23;

@implementation OSKTwitterText

+ (NSArray*)entitiesInText:(NSString*)text
{
    if (!text.length) {
        return [NSArray array];
    }

    NSMutableArray *results = [NSMutableArray array];

    NSArray *urls = [self URLsInText:text];
    [results addObjectsFromArray:urls];

    NSArray *hashtags = [self hashtagsInText:text withURLEntities:urls];
    [results addObjectsFromArray:hashtags];

    NSArray *cashtags = [self symbolsInText:text withURLEntities:urls];
    [results addObjectsFromArray:cashtags];

    NSArray *mentionsAndLists = [self mentionsOrListsInText:text];
    NSMutableArray *addingItems = [NSMutableArray array];

    for (OSKTwitterTextEntity *entity in mentionsAndLists) {
        NSRange entityRange = entity.range;
        BOOL found = NO;
        for (OSKTwitterTextEntity *existingEntity in results) {
            if (NSIntersectionRange(existingEntity.range, entityRange).length > 0) {
                found = YES;
                break;
            }
        }
        
        if (!found) {
            [addingItems addObject:entity];
        }
    }

    [results addObjectsFromArray:addingItems];
    [results sortUsingSelector:@selector(compare:)];

    return results;
}

+ (NSArray*)URLsInText:(NSString*)text
{
    if (!text.length) {
        return [NSArray array];
    }

    NSMutableArray *results = [NSMutableArray array];
    NSInteger len = text.length;
    NSInteger position = 0;
    NSRange allRange = NSMakeRange(0, 0);

    while (1) {
        position = NSMaxRange(allRange);
        NSTextCheckingResult *urlResult = [[self validURLRegexp] firstMatchInString:text options:NSMatchingWithoutAnchoringBounds range:NSMakeRange(position, len - position)];
        if (!urlResult || urlResult.numberOfRanges < 9) {
            break;
        }

        allRange = urlResult.range;
        NSRange precedingRange = [urlResult rangeAtIndex:2];
        NSRange urlRange = [urlResult rangeAtIndex:3];
        NSRange protocolRange = [urlResult rangeAtIndex:4];
        NSRange domainRange = [urlResult rangeAtIndex:5];

        // If protocol is missing and domain contains non-ASCII characters,
        // extract ASCII-only domains.
        if (protocolRange.location == NSNotFound) {
            if (precedingRange.location != NSNotFound && precedingRange.length > 0) {
                NSString *preceding = [text substringWithRange:precedingRange];
                NSRange suffixRange = [preceding rangeOfCharacterFromSet:[self invalidURLWithoutProtocolPrecedingCharSet] options:NSBackwardsSearch | NSAnchoredSearch];
                if (suffixRange.location != NSNotFound) {
                    continue;
                }
            }

            NSInteger domainStart = domainRange.location;
            NSInteger domainEnd = NSMaxRange(domainRange);
            OSKTwitterTextEntity *lastEntity = nil;
            BOOL lastInvalidShortResult = NO;

            while (domainStart < domainEnd) {
                NSTextCheckingResult *asciiResult = [[self validASCIIDomainRegexp] firstMatchInString:text options:0 range:NSMakeRange(domainStart, domainEnd - domainStart)];
                if (!asciiResult) {
                    break;
                }

                urlRange = asciiResult.range;
                lastEntity = [OSKTwitterTextEntity entityWithType:OSKTwitterTextEntityURL range:urlRange];

                NSTextCheckingResult *invalidShortResult = [[self invalidShortDomainRegexp] firstMatchInString:text options:0 range:urlRange];
                lastInvalidShortResult = (invalidShortResult != nil);
                if (!lastInvalidShortResult) {
                    [results addObject:lastEntity];
                }

                domainStart = NSMaxRange(urlRange);
            }

            if (!lastEntity) {
                continue;
            }

            NSRange pathRange = [urlResult rangeAtIndex:7];
            if (pathRange.location != NSNotFound && NSMaxRange(lastEntity.range) == pathRange.location) {
                if (lastInvalidShortResult) {
                    [results addObject:lastEntity];
                }
                NSRange entityRange = lastEntity.range;
                entityRange.length += pathRange.length;
                lastEntity.range = entityRange;
            }

        } else {
            // In the case of t.co URLs, don't allow additional path characters
            NSRange tcoRange = [[self validTCOURLRegexp] rangeOfFirstMatchInString:text options:0 range:urlRange];
            if (tcoRange.location != NSNotFound) {
                urlRange.length = tcoRange.length;
            }

            OSKTwitterTextEntity *entity = [OSKTwitterTextEntity entityWithType:OSKTwitterTextEntityURL range:urlRange];
            [results addObject:entity];
        }
    }

    return results;
}

+ (NSArray*)hashtagsInText:(NSString*)text checkingURLOverlap:(BOOL)checkingURLOverlap
{
    if (!text.length) {
        return [NSArray array];
    }

    NSArray *urls = nil;
    if (checkingURLOverlap) {
        urls = [self URLsInText:text];
    }
    return [self hashtagsInText:text withURLEntities:urls];
}

+ (NSArray*)hashtagsInText:(NSString*)text withURLEntities:(NSArray*)urlEntities
{
    if (!text.length) {
        return [NSArray array];
    }

    NSMutableArray *results = [NSMutableArray array];
    NSInteger len = text.length;
    NSInteger position = 0;

    while (1) {
        NSTextCheckingResult *matchResult = [[self validHashtagRegexp] firstMatchInString:text options:NSMatchingWithoutAnchoringBounds range:NSMakeRange(position, len - position)];
        if (!matchResult || matchResult.numberOfRanges < 2) {
            break;
        }

        NSRange hashtagRange = [matchResult rangeAtIndex:1];
        BOOL matchOk = YES;

        // Check URL overlap
        for (OSKTwitterTextEntity *urlEntity in urlEntities) {
            if (NSIntersectionRange(urlEntity.range, hashtagRange).length > 0) {
                matchOk = NO;
                break;
            }
        }

        if (matchOk) {
            NSInteger afterStart = NSMaxRange(hashtagRange);
            if (afterStart < len) {
                NSRange endMatchRange = [[self endHashtagRegexp] rangeOfFirstMatchInString:text options:0 range:NSMakeRange(afterStart, len - afterStart)];
                if (endMatchRange.location != NSNotFound) {
                    matchOk = NO;
                }
            }

            if (matchOk) {
                OSKTwitterTextEntity *entity = [OSKTwitterTextEntity entityWithType:OSKTwitterTextEntityHashtag range:hashtagRange];
                [results addObject:entity];
            }
        }

        position = NSMaxRange(matchResult.range);
    }

    return results;
}

+ (NSArray*)symbolsInText:(NSString*)text checkingURLOverlap:(BOOL)checkingURLOverlap
{
    if (!text.length) {
        return [NSArray array];
    }

    NSArray *urls = nil;
    if (checkingURLOverlap) {
        urls = [self URLsInText:text];
    }
    return [self symbolsInText:text withURLEntities:urls];
}

+ (NSArray*)symbolsInText:(NSString*)text withURLEntities:(NSArray*)urlEntities
{
    if (!text.length) {
        return [NSArray array];
    }

    NSMutableArray *results = [NSMutableArray array];
    NSInteger len = text.length;
    NSInteger position = 0;

    while (1) {
        NSTextCheckingResult *matchResult = [[self validCashtagRegexp] firstMatchInString:text options:NSMatchingWithoutAnchoringBounds range:NSMakeRange(position, len - position)];
        if (!matchResult || matchResult.numberOfRanges < 2) {
            break;
        }

        NSRange symbolRange = [matchResult rangeAtIndex:1];
        BOOL matchOk = YES;

        // Check URL overlap
        for (OSKTwitterTextEntity *urlEntity in urlEntities) {
            if (NSIntersectionRange(urlEntity.range, symbolRange).length > 0) {
                matchOk = NO;
                break;
            }
        }

        if (matchOk) {
            OSKTwitterTextEntity *entity = [OSKTwitterTextEntity entityWithType:OSKTwitterTextEntitySymbol range:symbolRange];
            [results addObject:entity];
        }

        position = NSMaxRange(matchResult.range);
    }

    return results;
}

+ (NSArray*)mentionedScreenNamesInText:(NSString*)text
{
    if (!text.length) {
        return [NSArray array];
    }

    NSArray *mentionsOrLists = [self mentionsOrListsInText:text];
    NSMutableArray *results = [NSMutableArray array];

    for (OSKTwitterTextEntity *entity in mentionsOrLists) {
        if (entity.type == OSKTwitterTextEntityScreenName) {
            [results addObject:entity];
        }
    }

    return results;
}

+ (NSArray*)mentionsOrListsInText:(NSString*)text
{
    if (!text.length) {
        return [NSArray array];
    }

    NSMutableArray *results = [NSMutableArray array];
    NSInteger len = text.length;
    NSInteger position = 0;

    while (1) {
        NSTextCheckingResult *matchResult = [[self validMentionOrListRegexp] firstMatchInString:text options:NSMatchingWithoutAnchoringBounds range:NSMakeRange(position, len - position)];
        if (!matchResult || matchResult.numberOfRanges < 5) {
            break;
        }

        NSRange allRange = matchResult.range;
        NSInteger end = NSMaxRange(allRange);

        NSRange endMentionRange = [[self endMentionRegexp] rangeOfFirstMatchInString:text options:0 range:NSMakeRange(end, len - end)];
        if (endMentionRange.location == NSNotFound) {
            NSRange atSignRange = [matchResult rangeAtIndex:2];
            NSRange screenNameRange = [matchResult rangeAtIndex:3];
            NSRange listNameRange = [matchResult rangeAtIndex:4];

            if (listNameRange.location == NSNotFound) {
                OSKTwitterTextEntity *entity = [OSKTwitterTextEntity entityWithType:OSKTwitterTextEntityScreenName range:NSMakeRange(atSignRange.location, NSMaxRange(screenNameRange) - atSignRange.location)];
                [results addObject:entity];
            } else {
                OSKTwitterTextEntity *entity = [OSKTwitterTextEntity entityWithType:OSKTwitterTextEntityListName range:NSMakeRange(atSignRange.location, NSMaxRange(listNameRange) - atSignRange.location)];
                [results addObject:entity];
            }
        } else {
            // Avoid matching the second username in @username@username
            end++;
        }

        position = end;
    }

    return results;
}

+ (OSKTwitterTextEntity*)repliedScreenNameInText:(NSString*)text
{
    if (!text.length) {
        return nil;
    }

    NSInteger len = text.length;

    NSTextCheckingResult *matchResult = [[self validReplyRegexp] firstMatchInString:text options:(NSMatchingWithoutAnchoringBounds | NSMatchingAnchored) range:NSMakeRange(0, len)];
    if (!matchResult || matchResult.numberOfRanges < 2) {
        return nil;
    }

    NSRange replyRange = [matchResult rangeAtIndex:1];
    NSInteger replyEnd = NSMaxRange(replyRange);

    NSRange endMentionRange = [[self endMentionRegexp] rangeOfFirstMatchInString:text options:0 range:NSMakeRange(replyEnd, len - replyEnd)];
    if (endMentionRange.location != NSNotFound) {
        return nil;
    }

    return [OSKTwitterTextEntity entityWithType:OSKTwitterTextEntityScreenName range:replyRange];
}

+ (NSInteger)tweetLength:(NSString*)text
{
    return [self tweetLength:text httpURLLength:HTTPShortURLLength httpsURLLength:HTTPSShortURLLength];
}

+ (NSInteger)tweetLength:(NSString*)text httpURLLength:(NSInteger)httpURLLength httpsURLLength:(NSInteger)httpsURLLength
{
    text = [text precomposedStringWithCanonicalMapping];

    if (!text.length) {
        return 0;
    }

    // Remove URLs from text and add t.co length
    NSMutableString *string = [text mutableCopy];
#if !__has_feature(objc_arc)
    [string autorelease];
#endif

    int urlLengthOffset = 0;
    NSArray *urlEntities = [self URLsInText:text];
    for (NSInteger i=urlEntities.count-1; i>=0; i--) {
        OSKTwitterTextEntity *entity = [urlEntities objectAtIndex:i];
        NSRange urlRange = entity.range;
        NSString *url = [string substringWithRange:urlRange];
        if ([url rangeOfString:@"https" options:(NSCaseInsensitiveSearch | NSAnchoredSearch)].location == 0) {
            urlLengthOffset += httpsURLLength;
        } else {
            urlLengthOffset += httpURLLength;
        }
        [string deleteCharactersInRange:urlRange];
    }

    NSInteger len = string.length;
    NSInteger charCount = len + urlLengthOffset;

    if (len > 0) {
        // Adjust count for non-BMP characters
        UniChar buffer[len];
        [string getCharacters:buffer range:NSMakeRange(0, len)];

        for (int i=0; i<len; i++) {
            UniChar c = buffer[i];
            if (CFStringIsSurrogateHighCharacter(c)) {
                if (i+1 < len) {
                    UniChar d = buffer[i+1];
                    if (CFStringIsSurrogateLowCharacter(d)) {
                        charCount--;
                        i++;
                    }
                }
            }
        }
    }

    return charCount;
}

+ (NSInteger)remainingCharacterCount:(NSString*)text
{
    return [self remainingCharacterCount:text httpURLLength:HTTPShortURLLength httpsURLLength:HTTPSShortURLLength];
}

+ (NSInteger)remainingCharacterCount:(NSString*)text httpURLLength:(NSInteger)httpURLLength httpsURLLength:(NSInteger)httpsURLLength
{
    return MaxTweetLength - [self tweetLength:text httpURLLength:httpURLLength httpsURLLength:httpsURLLength];
}

#pragma mark - Regular Expressions and CharacterSet

+ (NSRegularExpression*)validURLRegexp
{
    static NSRegularExpression *validURLRegexp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        validURLRegexp = [[NSRegularExpression alloc] initWithPattern:TWUValidURL options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return validURLRegexp;
}

+ (NSRegularExpression*)validASCIIDomainRegexp
{
    static NSRegularExpression *validASCIIDomainRegexp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        validASCIIDomainRegexp = [[NSRegularExpression alloc] initWithPattern:TWUValidASCIIDomain options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return validASCIIDomainRegexp;
}

+ (NSRegularExpression*)invalidShortDomainRegexp
{
    static NSRegularExpression *invalidShortDomainRegexp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        invalidShortDomainRegexp = [[NSRegularExpression alloc] initWithPattern:TWUInvalidShortDomain options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return invalidShortDomainRegexp;
}

+ (NSRegularExpression*)validTCOURLRegexp
{
    static NSRegularExpression *validTCOURLRegexp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        validTCOURLRegexp = [[NSRegularExpression alloc] initWithPattern:TWUValidTCOURL options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return validTCOURLRegexp;
}

+ (NSRegularExpression*)validHashtagRegexp
{
    static NSRegularExpression *validHashtagRegexp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        validHashtagRegexp = [[NSRegularExpression alloc] initWithPattern:TWUValidHashtag options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return validHashtagRegexp;
}

+ (NSRegularExpression*)endHashtagRegexp
{
    static NSRegularExpression *endHashtagRegexp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        endHashtagRegexp = [[NSRegularExpression alloc] initWithPattern:TWUEndHashTagMatch options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return endHashtagRegexp;
}

+ (NSRegularExpression*)validCashtagRegexp
{
    static NSRegularExpression *validCashtagRegexp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        validCashtagRegexp = [[NSRegularExpression alloc] initWithPattern:TWUValidCashtag options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return validCashtagRegexp;
}

+ (NSRegularExpression*)validMentionOrListRegexp
{
    static NSRegularExpression *validMentionOrListRegexp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        validMentionOrListRegexp = [[NSRegularExpression alloc] initWithPattern:TWUValidMentionOrList options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return validMentionOrListRegexp;
}

+ (NSRegularExpression*)validReplyRegexp
{
    static NSRegularExpression *validReplyRegexp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        validReplyRegexp = [[NSRegularExpression alloc] initWithPattern:TWUValidReply options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return validReplyRegexp;
}

+ (NSRegularExpression*)endMentionRegexp
{
    static NSRegularExpression *endMentionRegexp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        endMentionRegexp = [[NSRegularExpression alloc] initWithPattern:TWUEndMentionMatch options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return endMentionRegexp;
}

+ (NSCharacterSet*)invalidURLWithoutProtocolPrecedingCharSet
{
    static NSCharacterSet *invalidURLWithoutProtocolPrecedingCharSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        invalidURLWithoutProtocolPrecedingCharSet = [NSCharacterSet characterSetWithCharactersInString:@"-_./"];
#if !__has_feature(objc_arc)
        [invalidURLWithoutProtocolPrecedingCharSet retain];
#endif
    });
    return invalidURLWithoutProtocolPrecedingCharSet;
}

@end
