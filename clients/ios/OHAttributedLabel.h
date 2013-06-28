/***********************************************************************************
 *
 * Copyright (c) 2010 Olivier Halligon
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 * 
 ***********************************************************************************
 *
 * Created by Olivier Halligon  (AliSoftware) on 20 Jul. 2010.
 *
 * Any comment or suggestion welcome. Please contact me before using this class in
 * your projects. Referencing this project in your AboutBox/Credits is appreciated.
 *
 ***********************************************************************************/


#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>



/////////////////////////////////////////////////////////////////////////////
// MARK: -
// MARK: Utility Functions
/////////////////////////////////////////////////////////////////////////////

CTTextAlignment CTTextAlignmentFromUITextAlignment(UITextAlignment alignment);
CTLineBreakMode CTLineBreakModeFromUILineBreakMode(UILineBreakMode lineBreakMode);

/////////////////////////////////////////////////////////////////////////////

@class OHAttributedLabel;
@protocol OHAttributedLabelDelegate <NSObject>
@optional
-(BOOL)attributedLabel:(OHAttributedLabel*)attributedLabel shouldFollowLink:(NSTextCheckingResult*)linkInfo;
-(UIColor*)colorForLink:(NSTextCheckingResult*)linkInfo underlineStyle:(int32_t*)underlineStyle; //!< Combination of CTUnderlineStyle and CTUnderlineStyleModifiers
@end

#define UITextAlignmentJustify ((UITextAlignment)kCTJustifiedTextAlignment)

/////////////////////////////////////////////////////////////////////////////

@interface OHAttributedLabel : UILabel {
	NSMutableAttributedString* _attributedText; //!< Internally mutable, but externally immutable copy access only
	CTFrameRef textFrame;
	CGRect drawingRect;
	NSMutableArray* customLinks;
	NSTextCheckingResult* activeLink;
	CGPoint touchStartPoint;
}

/* Attributed String accessors */
@property(nonatomic, copy) NSAttributedString* attributedText; //!< Use this instead of the "text" property inherited from UILabel to set and get text
-(void)resetAttributedText; //!< rebuild the attributedString based on UILabel's text/font/color/alignment/... properties

/* Links configuration */
@property(nonatomic, assign) NSTextCheckingTypes automaticallyAddLinksForType; //!< Defaults to NSTextCheckingTypeLink, + NSTextCheckingTypePhoneNumber if "tel:" scheme supported
@property(nonatomic, retain) UIColor* linkColor; //!< Defaults to [UIColor blueColor]. See also OHAttributedLabelDelegate
@property(nonatomic, retain) UIColor* highlightedLinkColor; //[UIColor colorWithWhite:0.2 alpha:0.5]
@property(nonatomic, assign) BOOL underlineLinks; //!< Defaults to YES. See also OHAttributedLabelDelegate
-(void)addCustomLink:(NSURL*)linkUrl inRange:(NSRange)range;
-(void)removeAllCustomLinks;

@property(nonatomic, assign) BOOL onlyCatchTouchesOnLinks; //!< If YES, pointInside will only return YES if the touch is on a link. If NO, pointInside will always return YES (Defaults to NO)
@property(nonatomic, assign) IBOutlet id<OHAttributedLabelDelegate> delegate;

@property(nonatomic, assign) BOOL centerVertically;
@property(nonatomic, assign) BOOL extendBottomToFit; //!< Allows to draw text past the bottom of the view if need. May help in rare cases (like using Emoji)
@end
