//
//  NSString+HTML.m
//  MWFeedParser
//
//  Copyright (c) 2010 Michael Waterfall
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  1. The above copyright notice and this permission notice shall be included
//     in all copies or substantial portions of the Software.
//
//  2. This Software cannot be used to archive or collect data such as (but not
//     limited to) that of events, news, experiences and activities, for the
//     purpose of any concept relating to diary/journal keeping.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "NSString+HTML.h"
#import "GTMNString+HTML.h"

@implementation NSString (HTML)

#pragma mark - Instance Methods

- (NSString *)convertHTML {
    NSScanner *scanner = [NSScanner scannerWithString:self];
    NSMutableString *output = [NSMutableString string];
    NSString *string = nil;
    
    while ([scanner isAtEnd] == NO) {
        if ([scanner scanUpToString:@"<" intoString:&string] == YES && string != nil) {
            [output appendString:string];
            [output appendString:@" "];
        }
        
        [scanner scanUpToString:@">" intoString:NULL];
        [scanner scanString:@">" intoString:NULL];
    }
    
    return [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)stringByDecodingXMLEntities {
    NSUInteger myLength = [self length];
    NSUInteger ampIndex = [self rangeOfString:@"&" options:NSLiteralSearch].location;
    
    // Short-circuit if there are no ampersands.
    if (ampIndex == NSNotFound) {
        return self;
    }
    // Make result string with some extra capacity.
    NSMutableString *result = [NSMutableString stringWithCapacity:(myLength * 1.25)];
    
    // First iteration doesn't need to scan to & since we did that already, but for code simplicity's sake we'll do it again with the scanner.
    NSScanner *scanner = [NSScanner scannerWithString:self];
    
    [scanner setCharactersToBeSkipped:nil];
    
    NSCharacterSet *boundaryCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r;"];
    
    do {
        // Scan up to the next entity or the end of the string.
        NSString *nonEntityString;
        if ([scanner scanUpToString:@"&" intoString:&nonEntityString]) {
            [result appendString:nonEntityString];
        }
        if ([scanner isAtEnd]) {
            goto finish;
        }
        // Scan either a HTML or numeric character entity reference.
        if ([scanner scanString:@"&amp;" intoString:NULL])
            [result appendString:@"&"];
        else if ([scanner scanString:@"&apos;" intoString:NULL])
            [result appendString:@"'"];
        else if ([scanner scanString:@"&quot;" intoString:NULL])
            [result appendString:@"\""];
        else if ([scanner scanString:@"&lt;" intoString:NULL])
            [result appendString:@"<"];
        else if ([scanner scanString:@"&gt;" intoString:NULL])
            [result appendString:@">"];
        else if ([scanner scanString:@"&#" intoString:NULL]) {
            BOOL gotNumber;
            unsigned charCode;
            NSString *xForHex = @"";
            
            // Is it hex or decimal?
            if ([scanner scanString:@"x" intoString:&xForHex]) {
                gotNumber = [scanner scanHexInt:&charCode];
            }
            else {
                gotNumber = [scanner scanInt:(int*)&charCode];
            }
            
            if (gotNumber) {
                [result appendFormat:@"%C", (unichar)charCode];
                
                [scanner scanString:@";" intoString:NULL];
            }
            else {
                NSString *unknownEntity = @"";
                
                [scanner scanUpToCharactersFromSet:boundaryCharacterSet intoString:&unknownEntity];
                
                
                [result appendFormat:@"&#%@%@", xForHex, unknownEntity];
                
                //[scanner scanUpToString:@";" intoString:&unknownEntity];
                //[result appendFormat:@"&#%@%@;", xForHex, unknownEntity];
                NSLog(@"Expected numeric character entity but got &#%@%@;", xForHex, unknownEntity);
                
            }
            
        }
        else {
            NSString *amp;
            
            [scanner scanString:@"&" intoString:&amp];  //an isolated & symbol
            [result appendString:amp];
            
            /*
             NSString *unknownEntity = @"";
             [scanner scanUpToString:@";" intoString:&unknownEntity];
             NSString *semicolon = @"";
             [scanner scanString:@";" intoString:&semicolon];
             [result appendFormat:@"%@%@", unknownEntity, semicolon];
             NSLog(@"Unsupported XML character entity %@%@", unknownEntity, semicolon);
             */
        }
        
    }
    while (![scanner isAtEnd]);
    
finish:
    return result;
}

- (NSString *)stringByConvertingHTMLToPlainText {
	
	// Pool
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Character sets
	NSCharacterSet *stopCharacters = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@"< \t\n\r%C%C%C%C", (unichar)0x0085, (unichar)0x000C, (unichar)0x2028, (unichar)0x2029]];
	NSCharacterSet *newLineAndWhitespaceCharacters = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@" \t\n\r%C%C%C%C", (unichar)0x0085, (unichar)0x000C, (unichar)0x2028, (unichar)0x2029]];
	NSCharacterSet *tagNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
	
	// Scan and find all tags
	NSMutableString *result = [[NSMutableString alloc] initWithCapacity:self.length];
    if (!self) {
        NSLog(@"nil NSScanner");
        return self;
    }
	NSScanner *scanner = [[NSScanner alloc] initWithString:self];
	[scanner setCharactersToBeSkipped:nil];
	[scanner setCaseSensitive:YES];
	NSString *str = nil, *tagName = nil;
	BOOL dontReplaceTagWithSpace = NO;
	do {
		
		// Scan up to the start of a tag or whitespace
		if ([scanner scanUpToCharactersFromSet:stopCharacters intoString:&str]) {
			[result appendString:str];
			str = nil; // reset
		}
		
		// Check if we've stopped at a tag/comment or whitespace
		if ([scanner scanString:@"<" intoString:NULL]) {
			
			// Stopped at a comment or tag
			if ([scanner scanString:@"!--" intoString:NULL]) {
				
				// Comment
				[scanner scanUpToString:@"-->" intoString:NULL];
				[scanner scanString:@"-->" intoString:NULL];
				
			} else {
				
				// Tag - remove and replace with space unless it's
				// a closing inline tag then dont replace with a space
				if ([scanner scanString:@"/" intoString:NULL]) {
					
					// Closing tag - replace with space unless it's inline
					tagName = nil; dontReplaceTagWithSpace = NO;
					if ([scanner scanCharactersFromSet:tagNameCharacters intoString:&tagName]) {
						tagName = [tagName lowercaseString];
						dontReplaceTagWithSpace = ([tagName isEqualToString:@"a"] ||
												   [tagName isEqualToString:@"b"] ||
												   [tagName isEqualToString:@"i"] ||
												   [tagName isEqualToString:@"q"] ||
												   [tagName isEqualToString:@"span"] ||
												   [tagName isEqualToString:@"em"] ||
												   [tagName isEqualToString:@"strong"] ||
												   [tagName isEqualToString:@"cite"] ||
												   [tagName isEqualToString:@"abbr"] ||
												   [tagName isEqualToString:@"acronym"] ||
												   [tagName isEqualToString:@"label"]);
					}
					
					// Replace tag with string unless it was an inline
					if (!dontReplaceTagWithSpace && result.length > 0 && ![scanner isAtEnd]) [result appendString:@" "];
					
				}
				
				// Scan past tag
				[scanner scanUpToString:@">" intoString:NULL];
				[scanner scanString:@">" intoString:NULL];
				
			}
			
		} else {
			
			// Stopped at whitespace - replace all whitespace and newlines with a space
			if ([scanner scanCharactersFromSet:newLineAndWhitespaceCharacters intoString:NULL]) {
				if (result.length > 0 && ![scanner isAtEnd]) [result appendString:@" "]; // Dont append space to beginning or end of result
			}
			
		}
		
	} while (![scanner isAtEnd]);
	
	// Cleanup
	[scanner release];
	
	// Decode HTML entities and return
	NSString *retString = [[result stringByDecodingHTMLEntities] retain];
	[result release];
	
	// Drain
	[pool drain];
	
	// Return
	return [retString autorelease];
	
}

- (NSString *)stringByDecodingHTMLEntities {
    // Can return self so create new string if we're a mutable string
    return [NSString stringWithString:[self gtm_stringByUnescapingFromHTML]];
}


- (NSString *)stringByEncodingHTMLEntities {
    // Can return self so create new string if we're a mutable string
    return [NSString stringWithString:[self gtm_stringByEscapingForAsciiHTML]];
}

- (NSString *)stringByEncodingHTMLEntities:(BOOL)isUnicode {
    // Can return self so create new string if we're a mutable string
    return [NSString stringWithString:(isUnicode ? [self gtm_stringByEscapingForHTML] : [self gtm_stringByEscapingForAsciiHTML])];
}

- (NSString *)stringWithNewLinesAsBRs {
	
	// Pool
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Strange New lines:
	//	Next Line, U+0085
	//	Form Feed, U+000C
	//	Line Separator, U+2028
	//	Paragraph Separator, U+2029
	
	// Scanner
    if (!self) {
        NSLog(@"nil NSScanner");
        return self;
    }
	NSScanner *scanner = [[NSScanner alloc] initWithString:self];
	[scanner setCharactersToBeSkipped:nil];
	NSMutableString *result = [[NSMutableString alloc] init];
	NSString *temp;
	NSCharacterSet *newLineCharacters = [NSCharacterSet characterSetWithCharactersInString:
										 [NSString stringWithFormat:@"\n\r%C%C%C%C", (unichar)0x0085, (unichar)0x000C, (unichar)0x2028, (unichar)0x2029]];
	// Scan
	do {
		
		// Get non new line characters
		temp = nil;
		[scanner scanUpToCharactersFromSet:newLineCharacters intoString:&temp];
		if (temp) [result appendString:temp];
		temp = nil;
		
		// Add <br /> s
		if ([scanner scanString:@"\r\n" intoString:nil]) {
			
			// Combine \r\n into just 1 <br />
			[result appendString:@"<br />"];
			
		} else if ([scanner scanCharactersFromSet:newLineCharacters intoString:&temp]) {
			
			// Scan other new line characters and add <br /> s
			if (temp) {
				for (NSUInteger i = 0; i < temp.length; i++) {
					[result appendString:@"<br />"];
				}
			}
			
		}
		
	} while (![scanner isAtEnd]);
	
	// Cleanup & return
	[scanner release];
	NSString *retString = [[NSString stringWithString:result] retain];
	[result release];
	
	// Drain
	[pool drain];
	
	// Return
	return [retString autorelease];
	
}

- (NSString *)stringByRemovingNewLinesAndWhitespace {
	
	// Pool
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Strange New lines:
	//	Next Line, U+0085
	//	Form Feed, U+000C
	//	Line Separator, U+2028
	//	Paragraph Separator, U+2029
	
	// Scanner
    if (!self) {
        NSLog(@"nil NSScanner");
        return self;
    }
	NSScanner *scanner = [[NSScanner alloc] initWithString:self];
	[scanner setCharactersToBeSkipped:nil];
	NSMutableString *result = [[NSMutableString alloc] init];
	NSString *temp;
	NSCharacterSet *newLineAndWhitespaceCharacters = [NSCharacterSet characterSetWithCharactersInString:
													  [NSString stringWithFormat:@" \t\n\r%C%C%C%C", (unichar)0x0085, (unichar)0x000C, (unichar)0x2028, (unichar)0x2029]];
	// Scan
	while (![scanner isAtEnd]) {
		
		// Get non new line or whitespace characters
		temp = nil;
		[scanner scanUpToCharactersFromSet:newLineAndWhitespaceCharacters intoString:&temp];
		if (temp) [result appendString:temp];
		
		// Replace with a space
		if ([scanner scanCharactersFromSet:newLineAndWhitespaceCharacters intoString:NULL]) {
			if (result.length > 0 && ![scanner isAtEnd]) // Dont append space to beginning or end of result
				[result appendString:@" "];
		}
		
	}
	
	// Cleanup
	[scanner release];
	
	// Return
	NSString *retString = [[NSString stringWithString:result] retain];
	[result release];
	
	// Drain
	[pool drain];
	
	// Return
	return [retString autorelease];
	
}

- (NSString *)stringByLinkifyingURLs {
    if (!NSClassFromString(@"NSRegularExpression")) return self;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *pattern = @"(?<!=\")\\b((http|https):\\/\\/[\\w\\-_]+(\\.[\\w\\-_]+)+([\\w\\-\\.,@?^=%%&amp;:/~\\+#]*[\\w\\-\\@?^=%%&amp;/~\\+#])?)";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSString *modifiedString = [[regex stringByReplacingMatchesInString:self options:0 range:NSMakeRange(0, [self length])
                                                           withTemplate:@"<a href=\"$1\" class=\"linkified\">$1</a>"] retain];
    [pool drain];
    return [modifiedString autorelease];
}

- (NSString *)stringByStrippingTags {
	
	// Pool
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Find first & and short-cut if we can
	NSUInteger ampIndex = [self rangeOfString:@"<" options:NSLiteralSearch].location;
	if (ampIndex == NSNotFound) {
		return [NSString stringWithString:self]; // return copy of string as no tags found
	}
    if (!self) {
        NSLog(@"nil NSScanner");
        return self;
    }

	// Scan and find all tags
	NSScanner *scanner = [NSScanner scannerWithString:self];
	[scanner setCharactersToBeSkipped:nil];
	NSMutableSet *tags = [[NSMutableSet alloc] init];
	NSString *tag;
	do {
		
		// Scan up to <
		tag = nil;
		[scanner scanUpToString:@"<" intoString:NULL];
		[scanner scanUpToString:@">" intoString:&tag];
		
		// Add to set
		if (tag) {
			NSString *t = [[NSString alloc] initWithFormat:@"%@>", tag];
			[tags addObject:t];
			[t release];
		}
		
	} while (![scanner isAtEnd]);
	
	// Strings
    if (!self) {
        NSLog(@"nil NSScanner");
        return self;
    }
	NSMutableString *result = [[NSMutableString alloc] initWithString:self];
	NSString *finalString;
	
	// Replace tags
	NSString *replacement;
	for (NSString *t in tags) {
		
		// Replace tag with space unless it's an inline element
		replacement = @" ";
		if ([t isEqualToString:@"<a>"] ||
			[t isEqualToString:@"</a>"] ||
			[t isEqualToString:@"<span>"] ||
			[t isEqualToString:@"</span>"] ||
			[t isEqualToString:@"<strong>"] ||
			[t isEqualToString:@"</strong>"] ||
			[t isEqualToString:@"<em>"] ||
			[t isEqualToString:@"</em>"]) {
			replacement = @"";
		}
		
		// Replace
		[result replaceOccurrencesOfString:t
								withString:replacement
								   options:NSLiteralSearch
									 range:NSMakeRange(0, result.length)];
	}
	
	// Remove multi-spaces and line breaks
	finalString = [[result stringByRemovingNewLinesAndWhitespace] retain];
	
	// Cleanup
	[result release];
	[tags release];
	
	// Drain
	[pool drain];
	
	// Return
    return [finalString autorelease];
	
}

@end
