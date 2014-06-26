//
//  OSKUITextViewSubstitute.h
//  Overshare
//
//  Created by Jared on 3/20/14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

#import <UIKit/UIKit.h>

/// ------------------------------------------------------------
/// OSKUITextViewSubstituteDelegate
/// ------------------------------------------------------------

@class OSKUITextViewSubstitute;

@protocol OSKUITextViewSubstituteDelegate <NSObject>
@optional

- (BOOL)textViewShouldBeginEditing:(OSKUITextViewSubstitute *)textView;
- (BOOL)textViewShouldEndEditing:(OSKUITextViewSubstitute *)textView;
- (void)textViewDidBeginEditing:(OSKUITextViewSubstitute *)textView;
- (void)textViewDidEndEditing:(OSKUITextViewSubstitute *)textView;
- (BOOL)textView:(OSKUITextViewSubstitute *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
- (void)textViewDidChange:(OSKUITextViewSubstitute *)textView;
- (void)textViewDidChangeSelection:(OSKUITextViewSubstitute *)textView;
- (BOOL)textView:(OSKUITextViewSubstitute *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange NS_AVAILABLE_IOS(7_0);
- (BOOL)textView:(OSKUITextViewSubstitute *)textView shouldInteractWithTextAttachment:(NSTextAttachment *)textAttachment inRange:(NSRange)characterRange NS_AVAILABLE_IOS(7_0);

@end

/// ------------------------------------------------------------
/// OSKUITextViewSubstitute
/// ------------------------------------------------------------

@interface OSKUITextViewSubstitute : UIScrollView

@property (weak, nonatomic) id <OSKUITextViewSubstituteDelegate> oskDelegate;
@property (assign, nonatomic) BOOL automaticallyAdjustsContentInsetForKeyboard; // Defaults to YES

- (void)commonInit;

@end

@interface OSKUITextViewSubstitute (OSKExposedInternalUITextViewMethods)

@property (copy, nonatomic) NSAttributedString *attributedText;
@property (copy, nonatomic) NSString *text;
@property(nonatomic,retain) UIFont *font;
@property(nonatomic,retain) UIColor *textColor;
@property(nonatomic) NSTextAlignment textAlignment; // default is NSLeftTextAlignment
@property(nonatomic) NSRange selectedRange;
@property(nonatomic,getter=isEditable) BOOL editable;
@property(nonatomic,getter=isSelectable) BOOL selectable NS_AVAILABLE_IOS(7_0);
@property(nonatomic) UIDataDetectorTypes dataDetectorTypes NS_AVAILABLE_IOS(3_0);
@property(nonatomic) BOOL allowsEditingTextAttributes NS_AVAILABLE_IOS(6_0); // defaults to NO
@property(nonatomic,copy) NSDictionary *typingAttributes NS_AVAILABLE_IOS(6_0); // automatically resets when the selection changes
@property(nonatomic, strong) UIView *OSK_inputView;
@property(nonatomic, strong) UIView *OSK_inputAccessoryView;
@property(nonatomic) BOOL clearsOnInsertion NS_AVAILABLE_IOS(6_0);
@property(nonatomic,readonly) NSTextContainer *textContainer NS_AVAILABLE_IOS(7_0);
@property(nonatomic, assign) UIEdgeInsets textContainerInset NS_AVAILABLE_IOS(7_0);
@property(nonatomic,readonly) NSLayoutManager *layoutManager NS_AVAILABLE_IOS(7_0);
@property(nonatomic,readonly,retain) NSTextStorage *textStorage NS_AVAILABLE_IOS(7_0);
@property(nonatomic, copy) NSDictionary *linkTextAttributes NS_AVAILABLE_IOS(7_0);
@property(nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property(nonatomic) UITextAutocorrectionType autocorrectionType;
@property(nonatomic) UITextSpellCheckingType spellCheckingType NS_AVAILABLE_IOS(5_0);
@property(nonatomic) UIKeyboardType keyboardType;
@property(nonatomic) UIKeyboardAppearance keyboardAppearance;
@property(nonatomic) UIReturnKeyType returnKeyType;
@property(nonatomic) BOOL enablesReturnKeyAutomatically;
@property(nonatomic,getter=isSecureTextEntry) BOOL secureTextEntry;

- (void)scrollRangeToVisible:(NSRange)range;
- (void)insertText:(NSString *)text;

@end

@interface OSKUITextViewSubstitute (Protected)

@property (strong, nonatomic, readonly) UITextView *textView;

@end
