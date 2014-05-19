//
//  OSKQuoteSmartener.h
//  Overshare
//
//  Created by Jared on 1/25/14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

@import UIKit;

@interface OSKSmartPunctuation : NSObject

/**
 Changes dumb quotes to smart quotes, dashes to en- and em- dashes, and dots to elipses.
 
 @param textStorage The NSTextStorage of the UIKit text editing view (likely a UITextView).
 
 @param editedRange The editedRange from the NSTextStorageDelegate method listed above.
 
 @param textInputObject An object conforming to the UITextInput protocol. This is ususally
 to your UITextView. This object is used to obtain writing direction.
 
 @return Returns the change in length after the edits. OSK uses this to correct the
 cursor position after, for example, three dots are replaced with an elipsis.
 
 @discussion This method is designed to be used inside the NSTextStorageDelegate method
 `textStorage:willProcessEditing:editedRange:changeInLength:`.
 
 This method is safe to use with strings containing composed characters (emoji, etc.).
 It also respects writing direction.
 
 Two dashes followed by anything except a dash will be replaced with an en-dash.
 
 Three consecutive dashes will be replaced with an em-dash.
 
 Three consecutive dots will be replaced with an elipsis.
 */
+ (NSInteger)fixDumbPunctuation:(NSTextStorage *)textStorage
                    editedRange:(NSRange)editedRange
                textInputObject:(id <UITextInput>)textInputObject;

@end
