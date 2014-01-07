//
//  OSKTextView.m
//  Based on JTSTextView by Jared Sinclair
//
//  Created by Jared Sinclair on 10/26/13.
//  Copyright (c) 2013 Nice Boy LLC. All rights reserved.
//

#import "OSKTextView.h"

#import "OSKLogger.h"
#import "OSKPresentationManager.h"
#import "OSKTwitterText.h"

static CGFloat OSKTextViewAttachmentViewWidth_Phone = 78.0f; // 2 points larger than visual appearance, due to anti-aliasing technique
static CGFloat OSKTextViewAttachmentViewWidth_Pad = 96.0f; // 2 points larger than visual appearance, due to anti-aliasing technique

// OSKTextViewAttachment ============================================================

@interface OSKTextViewAttachment ()

@property (strong, nonatomic, readwrite) UIImage *thumbnail; // displayed cropped to 1:1 square

@end

@implementation OSKTextViewAttachment

- (instancetype)initWithImage:(UIImage *)image {
    self = [super init];
    if (self) {
        CGFloat width;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            width = OSKTextViewAttachmentViewWidth_Phone;
        } else {
            width = OSKTextViewAttachmentViewWidth_Pad;
        }
        __weak OSKTextViewAttachment *weakSelf = self;
        [self scaleImage:image toThumbmailOfSize:CGSizeMake(width, width) completion:^(UIImage *thumbnail) {
            [weakSelf setThumbnail:thumbnail];
        }];
    }
    return self;
}

- (void)scaleImage:(UIImage *)image toThumbmailOfSize:(CGSize)size completion:(void(^)(UIImage *thumbnail))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIGraphicsBeginImageContextWithOptions(size, YES, 0);
        CGFloat nativeWidth = image.size.width;
        CGFloat nativeHeight = image.size.height;
        CGFloat targetWidth;
        CGFloat targetHeight;
        if (nativeHeight > nativeWidth) {
            targetWidth = size.width;
            targetHeight = (nativeHeight / nativeWidth) * targetWidth;
        } else {
            targetHeight = size.height;
            targetWidth = (nativeWidth / nativeHeight) * targetHeight;
        }
        CGFloat xOrigin = (size.width/2.0f) - (targetWidth/2.0f);
        CGFloat yOrigin = (size.height/2.0f) - (targetHeight/2.0f);
        CGRect rect = CGRectMake(xOrigin, yOrigin, targetWidth, targetHeight);
        [image drawInRect:rect];
        UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion){
                completion(thumbnail);
            }
        });
    });
}

@end

// OSKTextViewAttachmentView ============================================================

static void * OSKTextViewAttachmentViewContext = "OSKTextViewAttachmentViewContext";

@interface OSKTextViewAttachmentView : UIView

@property (strong, nonatomic) OSKTextViewAttachment *attachment;

@end

@implementation OSKTextViewAttachmentView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
        [self setContentMode:UIViewContentModeScaleAspectFill];
        [self setClipsToBounds:YES];
    }
    return self;
}

- (void)dealloc {
    [self removeObservationsFromAttachment:_attachment];
}

- (void)setAttachment:(OSKTextViewAttachment *)attachment {
    if (_attachment != attachment) {
        [self removeObservationsFromAttachment:_attachment];
        _attachment = attachment;
        [self addObservationsToAttachment:_attachment];
        [self updateInterface];
    }
}

- (void)updateInterface {
    if (self.attachment.thumbnail) {
        self.backgroundColor = [UIColor clearColor];
    }
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    [self.attachment.thumbnail drawInRect:CGRectInset(self.bounds, 1, 1)];
}

#pragma mark - KVO

- (void)addObservationsToAttachment:(OSKTextViewAttachment *)attachment {
    [attachment addObserver:self forKeyPath:@"thumbnail" options:NSKeyValueObservingOptionNew context:OSKTextViewAttachmentViewContext];
}

- (void)removeObservationsFromAttachment:(OSKTextViewAttachment *)attachment {
    [attachment removeObserver:self forKeyPath:@"thumbnail" context:OSKTextViewAttachmentViewContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == OSKTextViewAttachmentViewContext) {
        if (object == self.attachment) {
            if ([keyPath isEqualToString:@"thumbnail"]) {
                [self updateInterface];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


// OSKTextView ============================================================


@interface OSKTextView () <UITextViewDelegate, NSTextStorageDelegate>

@property (strong, nonatomic) NSDictionary *attributes_normal;
@property (strong, nonatomic) NSDictionary *attributes_mentions;
@property (strong, nonatomic) NSDictionary *attributes_hashtags;
@property (strong, nonatomic) NSDictionary *attributes_links;
@property (strong, nonatomic) NSMutableArray *attachmentViews;
@property (assign, nonatomic) CGRect currentKeyboardFrame;
@property (strong, nonatomic) UITextView *textView;
@property (assign, nonatomic) NSRange previousSelectedRange;
@property (assign, nonatomic) BOOL useLinearNextScrollAnimation;
@property (assign, nonatomic) BOOL ignoreNextTextSelectionAnimation;

@end

#define BOTTOM_PADDING 8.0f
#define SLOW_DURATION 0.4f
#define FAST_DURATION 0.2f

@implementation OSKTextView

- (void)dealloc {
    [self removeKeyboardNotifications];
}

- (id)initWithFrame:(CGRect)frame  {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self commonInit];
}

- (void)commonInit {
    [self setAttachmentViews:[NSMutableArray array]];
    [self setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [self setAlwaysBounceVertical:YES];
    [self setupSwipeGestureRecognizers];
    
    // Setup TextKit stack for the private text view.
    NSTextStorage* textStorage = [[NSTextStorage alloc] init];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [textStorage addLayoutManager:layoutManager];
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:CGSizeMake(self.frame.size.width, 100000)];
    [layoutManager addTextContainer:container];
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, 100000) textContainer:container];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addSubview:self.textView];
    self.textView.showsHorizontalScrollIndicator = NO;
    self.textView.showsVerticalScrollIndicator = NO;
    [self.textView setAlwaysBounceHorizontal:NO];
    [self.textView setAlwaysBounceVertical:NO];
    [self.textView setScrollsToTop:NO];
    [self.textView setDelegate:self];
    [self.textView.textStorage setDelegate:self];
    
    UIEdgeInsets insets = self.textView.textContainerInset;
    insets.left = 4.0f;
    insets.right = 4.0f;
    [self.textView setTextContainerInset:insets];
    
    [self setupAttributes];
    
    // Observes keyboard changes by default
    [self setAutomaticallyAdjustsContentInsetForKeyboard:YES];
    [self addKeyboardNotifications];
}

- (void)setupAttributes {
    OSKPresentationManager *manager = [OSKPresentationManager sharedInstance];
    
    CGFloat fontSize = [manager textViewFontSize];
    
    UIFont *normalFont = nil;
    UIFont *boldFont = nil;
    UIFontDescriptor *normalDescriptor = [manager normalFontDescriptor];
    UIFontDescriptor *boldDescriptor = [manager boldFontDescriptor];
    
    if (normalDescriptor) {
        normalFont = [UIFont fontWithDescriptor:normalDescriptor size:fontSize];
    } else {
        normalFont = [UIFont systemFontOfSize:fontSize];
    }
    
    if (boldDescriptor) {
        boldFont = [UIFont fontWithDescriptor:boldDescriptor size:fontSize];
    } else {
        boldFont = [UIFont systemFontOfSize:fontSize];
    }
    
    UIColor *normalColor = manager.color_text;
    UIColor *actionColor = manager.color_action;
    UIColor *hashtagColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineHeightMultiple:1.1];
    [paragraphStyle setBaseWritingDirection:NSWritingDirectionNatural];
    
    _attributes_normal = @{NSFontAttributeName:normalFont,
                           NSForegroundColorAttributeName:normalColor,
                           NSParagraphStyleAttributeName:paragraphStyle};
    
    _attributes_mentions = @{NSFontAttributeName:boldFont,
                             NSForegroundColorAttributeName:actionColor,
                             NSParagraphStyleAttributeName:paragraphStyle};
    
    _attributes_hashtags = @{NSFontAttributeName:normalFont,
                             NSForegroundColorAttributeName:hashtagColor,
                             NSParagraphStyleAttributeName:paragraphStyle};
    
    _attributes_links = @{NSFontAttributeName:normalFont,
                          NSForegroundColorAttributeName:actionColor,
                          NSParagraphStyleAttributeName:paragraphStyle};
    
    [self.textView setTypingAttributes:_attributes_normal];
    
    [self setTintColor:actionColor];
    [self.textView setTintColor:actionColor];
    [self setBackgroundColor:manager.color_opaqueBackground];
    [self.textView setBackgroundColor:manager.color_opaqueBackground];
    
    UIKeyboardAppearance keyboardAppearance;
    if (manager.sheetStyle == OSKActivitySheetViewControllerStyle_Dark) {
        keyboardAppearance = UIKeyboardAppearanceAlert;
    } else {
        keyboardAppearance = UIKeyboardAppearanceLight;
    }
    [self.textView setKeyboardAppearance:keyboardAppearance];
    [self.textView setKeyboardType:UIKeyboardTypeTwitter];
    
    [self.textView setAttributedText:[[NSAttributedString alloc] initWithString:@"" attributes:_attributes_normal]];
}

- (void)setSyntaxHighlighting:(OSKMicroblogSyntaxHighlightingStyle)syntaxHighlighting {
    if (_syntaxHighlighting != syntaxHighlighting) {
        _syntaxHighlighting = syntaxHighlighting;
        if (_syntaxHighlighting == OSKMicroblogSyntaxHighlightingStyle_Twitter) {
            [self.textView setKeyboardType:UIKeyboardTypeTwitter];
        } else {
            [self.textView setKeyboardType:UIKeyboardTypeDefault];
        }
    }
}

#pragma mark - These Are Why This Works

// The various method & delegate method implementations in this pragma marked section
// are why OSKTextView works. Edit these with extreme care.

- (void)updateContentSize:(BOOL)scrollToVisible delay:(CGFloat)delay {
    CGRect boundingRect = [self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer];
    boundingRect.size.height = roundf(boundingRect.size.height+16.0f); // + 16.0 for content inset.
    boundingRect.size.width = self.frame.size.width;
    [self setContentSize:boundingRect.size];
    if (scrollToVisible) {
        if (delay) {
            __weak OSKTextView *weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf setUseLinearNextScrollAnimation:NO];
                [weakSelf simpleScrollToCaret];
            });
        } else {
            [self setUseLinearNextScrollAnimation:NO];
            [self simpleScrollToCaret];
        }
    }
}

- (void)setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    [super setContentOffset:self.contentOffset animated:NO]; // Fixes a bug that breaks scrolling to top via status bar taps.
    // setContentOffset:animated: is called by UIScrollView inside its implementation
    // of scrollRectToVisible:animated:. The super implementation of
    // setContentOffset:animated: is jaggy when it's called multiple times in row.
    // Fuck that noise.
    // The following animation can be called multiple times in a row smoothly, with
    // one minor exception: we flip a dirty bit for "useLinearNextScrollAnimation"
    // for the scroll animation used when mimicking the long-press-and-drag-to-the-top-
    // or-bottom-edge-of-the-view with a selection caret animation.
    contentOffset = CGPointMake(0, roundf(contentOffset.y));
    CGFloat duration;
    UIViewAnimationOptions options;
    if (self.useLinearNextScrollAnimation) {
        duration = (animated) ? SLOW_DURATION : 0;
        options = UIViewAnimationOptionCurveLinear
        | UIViewAnimationOptionBeginFromCurrentState
        | UIViewAnimationOptionOverrideInheritedDuration
        | UIViewAnimationOptionOverrideInheritedCurve;
    } else {
        duration = (animated) ? FAST_DURATION : 0;
        options = UIViewAnimationOptionCurveEaseInOut
        | UIViewAnimationOptionBeginFromCurrentState
        | UIViewAnimationOptionOverrideInheritedDuration
        | UIViewAnimationOptionOverrideInheritedCurve;
    }
    [self setUseLinearNextScrollAnimation:NO];
    [UIView animateWithDuration:duration delay:0 options:options animations:^{
        [super setContentOffset:contentOffset];
    } completion:nil];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    // Update the content size in setFrame: (rather than layoutSubviews)
    // because self is a UIScrollView and we don't need to update the
    // content size every time the scroll view calls layoutSubviews,
    // which is often.
    
    // Set delay to YES to boot the scroll animation to the next runloop,
    // or else the scrollRectToVisible: call will be
    // cancelled out by the animation context in which setFrame: is
    // usually called.
    
    [self updateContentSize:YES delay:YES];
    if (self.attachmentViews.count) {
        [self updateAttachmentViewFrames];
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    BOOL shouldChange = YES;
    if ([self.textViewDelegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]) {
        shouldChange = [self.textViewDelegate textView:self shouldChangeTextInRange:range replacementText:text];
    }
    if (shouldChange) {
        // Ignore the next animation that would otherwise be triggered by the cursor moving
        // to a new spot. We animate to chase after the cursor as you type via the updateContentSize:(BOOL)scrollToVisible
        // method. Most of the time, we want to also animate inside of textViewDidChangeSelection:, but only when
        // that change is a "true" text selection change, and not the implied change that occurs when a new character is
        // typed or deleted.
        [self setIgnoreNextTextSelectionAnimation:YES];
    }
    return shouldChange;
}

- (void)textViewDidChange:(UITextView *)textView {
    [self updateContentSize:YES delay:NO];
    if ([self.textViewDelegate respondsToSelector:@selector(textViewDidChange:)]) {
        [self.textViewDelegate textViewDidChange:self];
    }
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
    NSRange selectedRange = textView.selectedRange;
    if (self.ignoreNextTextSelectionAnimation == YES) {
        [self setIgnoreNextTextSelectionAnimation:NO];
    } else if (selectedRange.length != textView.textStorage.length) {
        if (selectedRange.length == 0 || selectedRange.location < self.previousSelectedRange.location) {
            // Scroll to start caret
            CGRect caretRect = [self.textView caretRectForPosition:self.textView.selectedTextRange.start];
            CGRect targetRect = CGRectInset(caretRect, -1.0f, -8.0f);
            [self setUseLinearNextScrollAnimation:YES];
            [self scrollRectToVisible:targetRect animated:YES];
        }
        else if (selectedRange.location > self.previousSelectedRange.location) {
            CGRect firstRect = [textView firstRectForRange:textView.selectedTextRange];
            CGFloat bottomVisiblePointY = self.contentOffset.y + self.frame.size.height - self.contentInset.top - self.contentInset.bottom;
            if (firstRect.origin.y > bottomVisiblePointY - firstRect.size.height*1.1) {
                // Scroll to start caret
                CGRect caretRect = [self.textView caretRectForPosition:self.textView.selectedTextRange.start];
                CGRect targetRect = CGRectInset(caretRect, -1.0f, -8.0f);
                [self setUseLinearNextScrollAnimation:YES];
                [self scrollRectToVisible:targetRect animated:YES];
            }
        }
        else if (selectedRange.location == self.previousSelectedRange.location) {
            // Scroll to end caret
            CGRect caretRect = [self.textView caretRectForPosition:self.textView.selectedTextRange.end];
            CGRect targetRect = CGRectInset(caretRect, -1.0f, -8.0f);
            [self setUseLinearNextScrollAnimation:YES];
            [self scrollRectToVisible:targetRect animated:YES];
        }
    }
    [self setPreviousSelectedRange:selectedRange];
    if ([self.textViewDelegate respondsToSelector:@selector(textViewDidChangeSelection:)]) {
        [self.textViewDelegate textViewDidChangeSelection:self];
    }
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
    [self simpleScrollToCaret];
    if ([self.textViewDelegate respondsToSelector:@selector(textViewDidBeginEditing:)]) {
        [self.textViewDelegate textViewDidBeginEditing:self];
    }
}

#pragma mark - Text View Mimicry

- (BOOL)becomeFirstResponder {
    BOOL didBecome = [self.textView becomeFirstResponder];
    return didBecome;
}

- (BOOL)isFirstResponder {
    return [self.textView isFirstResponder];
}

- (BOOL)resignFirstResponder {
    return [self.textView resignFirstResponder];
}

- (NSString *)text {
    return self.textView.text;
}

- (void)setText:(NSString *)text {
    [self.textView setText:text];
    [self updateContentSize:YES delay:NO];
}

- (NSAttributedString *)attributedText {
    return self.textView.attributedText;
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    [self.textView setAttributedText:attributedText];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
    [self.textView setBackgroundColor:backgroundColor];
}

- (UIFont *)font {
    return self.textView.font;
}

- (void)setFont:(UIFont *)font {
    [self.textView setFont:font];
}

- (UIColor *)textColor {
    return self.textView.textColor;
}

- (void)setTextColor:(UIColor *)textColor {
    [self.textView setTextColor:textColor];
}

- (NSTextAlignment)textAlignment {
    return self.textView.textAlignment;
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
    [self.textView setTextAlignment:textAlignment];
}

- (NSRange)selectedRange {
    return self.textView.selectedRange;
}

- (void)setSelectedRange:(NSRange)selectedRange {
    [self.textView setSelectedRange:selectedRange];
}

- (BOOL)isEditable {
    return [self.textView isEditable];
}

- (void)setEditable:(BOOL)editable {
    [self.textView setEditable:editable];
}

- (BOOL)isSelectable {
    return [self.textView isSelectable];
}

- (void)setSelectable:(BOOL)selectable {
    [self.textView setSelectable:selectable];
}

- (UIDataDetectorTypes)dataDetectorTypes {
    return self.textView.dataDetectorTypes;
}

- (void)setDataDetectorTypes:(UIDataDetectorTypes)dataDetectorTypes {
    [self.textView setDataDetectorTypes:dataDetectorTypes];
}

- (BOOL)allowsEditingTextAttributes {
    return self.textView.allowsEditingTextAttributes;
}

- (void)setAllowsEditingTextAttributes:(BOOL)allowsEditingTextAttributes {
    [self.textView setAllowsEditingTextAttributes:allowsEditingTextAttributes];
}

- (NSDictionary *)typingAttributes {
    return self.textView.typingAttributes;
}

- (void)setTypingAttributes:(NSDictionary *)typingAttributes {
    [self.textView setTypingAttributes:typingAttributes];
}

- (UIView *)OSK_inputView {
    return self.textView.inputView;
}

- (void)setOSK_inputView:(UIView *)OSK_inputView {
    [self.textView setInputView:OSK_inputView];
}

- (UIView *)OSK_inputAccessoryView {
    return self.textView.inputAccessoryView;
}

- (void)setOSK_inputAccessoryView:(UIView *)OSK_inputAccessoryView {
    [self.textView setInputAccessoryView:OSK_inputAccessoryView];
}

- (BOOL)clearsOnInsertion {
    return self.textView.clearsOnInsertion;
}

- (void)setClearsOnInsertion:(BOOL)clearsOnInsertion {
    [self.textView setClearsOnInsertion:clearsOnInsertion];
}

- (NSTextContainer *)textContainer {
    return [self.textView textContainer];
}

- (UIEdgeInsets)textContainerInset {
    return [self.textView textContainerInset];
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset {
    [self.textView setTextContainerInset:textContainerInset];
}

- (NSLayoutManager *)layoutManager {
    return self.textView.layoutManager;
}

- (NSTextStorage *)textStorage {
    return [self.textView textStorage];
}

- (NSDictionary *)linkTextAttributes {
    return [self.textView linkTextAttributes];
}

- (void)setLinkTextAttributes:(NSDictionary *)linkTextAttributes {
    [self.textView setLinkTextAttributes:linkTextAttributes];
}

- (UITextAutocapitalizationType)autocapitalizationType {
    return self.textView.autocapitalizationType;
}

- (void)setAutocapitalizationType:(UITextAutocapitalizationType)autocapitalizationType {
    [self.textView setAutocapitalizationType:autocapitalizationType];
}

- (UITextAutocorrectionType)autocorrectionType {
    return self.textView.autocorrectionType;
}

- (UITextSpellCheckingType)spellCheckingType {
    return self.textView.spellCheckingType;
}

- (void)setSpellCheckingType:(UITextSpellCheckingType)spellCheckingType {
    [self.textView setSpellCheckingType:spellCheckingType];
}

- (UIKeyboardType)keyboardType {
    return self.textView.keyboardType;
}

- (void)setKeyboardType:(UIKeyboardType)keyboardType {
    [self.textView setKeyboardType:keyboardType];
}

- (UIKeyboardAppearance)keyboardAppearance {
    return self.keyboardAppearance;
}

- (void)setKeyboardAppearance:(UIKeyboardAppearance)keyboardAppearance {
    [self.textView setKeyboardAppearance:keyboardAppearance];
}

- (UIReturnKeyType)returnKeyType {
    return self.textView.returnKeyType;
}

- (void)setReturnKeyType:(UIReturnKeyType)returnKeyType {
    [self.textView setReturnKeyType:returnKeyType];
}

- (BOOL)enablesReturnKeyAutomatically {
    return self.textView.enablesReturnKeyAutomatically;
}

- (void)setEnablesReturnKeyAutomatically:(BOOL)enablesReturnKeyAutomatically {
    [self.textView setEnablesReturnKeyAutomatically:enablesReturnKeyAutomatically];
}

- (BOOL)isSecureTextEntry {
    return [self.textView isSecureTextEntry];
}

- (void)setSecureTextEntry:(BOOL)secureTextEntry {
    [self.textView setSecureTextEntry:secureTextEntry];
}

- (void)scrollRangeToVisible:(NSRange)range {
    [self.textView scrollRangeToVisible:range];
}

- (void)insertText:(NSString *)text {
    [self.textView insertText:text];
}

#pragma mark - Text View Delegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
    BOOL shouldBegin = YES;
    if ([self.textViewDelegate respondsToSelector:@selector(textViewShouldBeginEditing:)]) {
        shouldBegin = [self.textViewDelegate textViewShouldBeginEditing:self];
    }
    return shouldBegin;
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
    BOOL shouldEnd = YES;
    if ([self.textViewDelegate respondsToSelector:@selector(textViewShouldEndEditing:)]) {
        shouldEnd = [self.textViewDelegate textViewShouldEndEditing:self];
    }
    return shouldEnd;
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    if ([self.textViewDelegate respondsToSelector:@selector(textViewDidEndEditing:)]) {
        [self.textViewDelegate textViewDidEndEditing:self];
    }
}

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange {
    BOOL shouldInteract = NO;
    if ([self.textViewDelegate respondsToSelector:@selector(textView:shouldInteractWithURL:inRange:)]) {
        shouldInteract = [self.textViewDelegate textView:self shouldInteractWithURL:URL inRange:characterRange];
    }
    return shouldInteract;
}

- (BOOL)textView:(UITextView *)textView shouldInteractWithTextAttachment:(NSTextAttachment *)textAttachment inRange:(NSRange)characterRange {
    BOOL shouldInteract = NO;
    if ([self.textViewDelegate respondsToSelector:@selector(textView:shouldInteractWithTextAttachment:inRange:)]) {
        shouldInteract = [self.textViewDelegate textView:self shouldInteractWithTextAttachment:textAttachment inRange:characterRange];
    }
    return shouldInteract;
}

#pragma mark - Keyboard Changes

- (void)simpleScrollToCaret {
    CGRect caretRect = [self.textView caretRectForPosition:self.textView.selectedTextRange.end];
    [self scrollRectToVisible:CGRectInset(caretRect, -1.0f, -8.0f) animated:YES];
}

- (void)addKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)removeKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    if (self.automaticallyAdjustsContentInsetForKeyboard) {
        NSValue *frameValue = [notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
        CGRect targetKeyboardFrame = CGRectZero;
        [frameValue getValue:&targetKeyboardFrame];
        
        // Convert from window coordinates to my coordinates
        targetKeyboardFrame = [self.superview convertRect:targetKeyboardFrame fromView:nil];
        
        [self setCurrentKeyboardFrame:targetKeyboardFrame];
        [self updateBottomContentInset:targetKeyboardFrame];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (self.automaticallyAdjustsContentInsetForKeyboard) {
        [self setCurrentKeyboardFrame:CGRectZero];
        [self updateBottomContentInset:CGRectZero];
    }
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    if (self.automaticallyAdjustsContentInsetForKeyboard) {
        NSValue *frameValue = [notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
        CGRect targetKeyboardFrame = CGRectZero;
        [frameValue getValue:&targetKeyboardFrame];
        
        // Convert from window coordinates to my coordinates
        targetKeyboardFrame = [self.superview convertRect:targetKeyboardFrame fromView:nil];
        
        [self setCurrentKeyboardFrame:targetKeyboardFrame];
        [self updateBottomContentInset:targetKeyboardFrame];
    }
}

- (void)updateBottomContentInset:(CGRect)keyboardFrame {
    CGRect intersection = CGRectIntersection(self.frame, keyboardFrame);
    UIEdgeInsets insets = self.contentInset;
    insets.bottom = intersection.size.height;
    [self setContentInset:insets];
}

- (void)setAutomaticallyAdjustsContentInsetForKeyboard:(BOOL)automaticallyAdjustsContentInsetForKeyboard {
    if (_automaticallyAdjustsContentInsetForKeyboard != automaticallyAdjustsContentInsetForKeyboard) {
        _automaticallyAdjustsContentInsetForKeyboard = automaticallyAdjustsContentInsetForKeyboard;
        if (_automaticallyAdjustsContentInsetForKeyboard == NO) {
            [self setCurrentKeyboardFrame:CGRectZero];
            [self updateBottomContentInset:CGRectZero];
        }
    }
}

#pragma mark - Text Storage Delegate

- (void)textStorage:(NSTextStorage *)textStorage willProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta {
    [self fixDumbQuotes:textStorage];
    [self updateSyntaxHighlighting:textStorage];
}

- (void)updateSyntaxHighlighting:(NSTextStorage *)textStorage {
    
    // Apply default attributes to the entire string
    [textStorage addAttributes:self.attributes_normal range:NSMakeRange(0, textStorage.length)];
    
    if (self.syntaxHighlighting == OSKMicroblogSyntaxHighlightingStyle_Twitter) {
        // Apply syntax highlighting for entities
        NSArray *allEntities = [OSKTwitterText entitiesInText:textStorage.string];
        for (OSKTwitterTextEntity *anEntity in allEntities) {
            switch (anEntity.type) {
                case OSKTwitterTextEntityHashtag: {
                    [textStorage addAttributes:self.attributes_hashtags range:anEntity.range];
                } break;
                    
                case OSKTwitterTextEntityScreenName: {
                    NSString *lowercaseName = [textStorage.string substringWithRange:anEntity.range].lowercaseString;
                    [textStorage replaceCharactersInRange:anEntity.range withString:lowercaseName];
                    [textStorage addAttributes:self.attributes_mentions range:anEntity.range];
                } break;
                    
                case OSKTwitterTextEntityURL: {
                    [textStorage addAttributes:self.attributes_links range:anEntity.range];
                } break;
                default:
                    break;
            }
        }
    }
    else if (self.syntaxHighlighting == OSKMicroblogSyntaxHighlightingStyle_LinksOnly) {
        NSArray *allURLEntities = [OSKTwitterText URLsInText:textStorage.string];
        for (OSKTwitterTextEntity *urlEntitiy in allURLEntities) {
            [textStorage addAttributes:self.attributes_links range:urlEntitiy.range];
        }
    }
}

#pragma mark - Swipe Left Or Right To Advance Cursor

- (void)setupSwipeGestureRecognizers {
    // Swipe to Advance Cursor
    UISwipeGestureRecognizer *leftSwipeRecog = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedToTheLeft:)];
    UISwipeGestureRecognizer *rightSwipeRecog = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipedToTheRight:)];
    UISwipeGestureRecognizer *leftSwipeRecog_twoFingers = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(twoFingerSwipedToTheLeft:)];
    UISwipeGestureRecognizer *rightSwipeRecog_twoFingers = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(twoFingerSwipedToTheRight:)];
    UISwipeGestureRecognizer *leftSwipeRecog_threeFingers = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(threeFingerSwipedToTheLeft:)];
    UISwipeGestureRecognizer *rightSwipeRecog_threeFingers = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(threeFingerSwipedToTheRight:)];
    leftSwipeRecog.direction = UISwipeGestureRecognizerDirectionLeft;
    rightSwipeRecog.direction = UISwipeGestureRecognizerDirectionRight;
    leftSwipeRecog_twoFingers.direction = UISwipeGestureRecognizerDirectionLeft;
    rightSwipeRecog_twoFingers.direction = UISwipeGestureRecognizerDirectionRight;
    leftSwipeRecog_threeFingers.direction = UISwipeGestureRecognizerDirectionLeft;
    rightSwipeRecog_threeFingers.direction = UISwipeGestureRecognizerDirectionRight;
    leftSwipeRecog_twoFingers.numberOfTouchesRequired = 2;
    rightSwipeRecog_twoFingers.numberOfTouchesRequired = 2;
    leftSwipeRecog_threeFingers.numberOfTouchesRequired = 3;
    rightSwipeRecog_threeFingers.numberOfTouchesRequired = 3;
    [self addGestureRecognizer:leftSwipeRecog];
    [self addGestureRecognizer:rightSwipeRecog];
    [self addGestureRecognizer:leftSwipeRecog_twoFingers];
    [self addGestureRecognizer:rightSwipeRecog_twoFingers];
    [self addGestureRecognizer:leftSwipeRecog_threeFingers];
    [self addGestureRecognizer:rightSwipeRecog_threeFingers];
}

- (void)swipedToTheRight:(id)sender {
    NSRange selectedRange = self.textView.selectedRange;
    if (selectedRange.location < self.textView.attributedText.string.length) {
        self.textView.selectedRange = NSMakeRange(selectedRange.location+1, 0);
    }
}

- (void)swipedToTheLeft:(id)sender {
    NSRange selectedRange = self.textView.selectedRange;
    if (selectedRange.location > 0) {
        self.textView.selectedRange = NSMakeRange(selectedRange.location-1, 0);
    }
}

- (void)twoFingerSwipedToTheRight:(id)sender {
    NSInteger targetIndex = [self indexOfFirstSubsequentSpace];
    self.textView.selectedRange = NSMakeRange(targetIndex, 0);
}

- (void)twoFingerSwipedToTheLeft:(id)sender {
    NSInteger targetIndex = [self indexOfFirstPreviousSpace];
    self.textView.selectedRange = NSMakeRange(targetIndex, 0);
}

- (void)threeFingerSwipedToTheRight:(id)sender {
    NSInteger targetIndex = [self indexOfFirstSubsequentLine];
    self.textView.selectedRange = NSMakeRange(targetIndex, 0);
}

- (void)threeFingerSwipedToTheLeft:(id)sender {
    NSInteger targetIndex = [self indexOfFirstPreviousLine];
    self.textView.selectedRange = NSMakeRange(targetIndex, 0);
}

- (NSInteger)indexOfFirstPreviousSpace {
    __block NSInteger indexOfSpace = 0;
    [self.textView.attributedText.string enumerateSubstringsInRange:NSMakeRange(0, self.textView.selectedRange.location)
                                                            options:NSStringEnumerationByWords | NSStringEnumerationReverse | NSStringEnumerationByComposedCharacterSequences
                                                         usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                                             indexOfSpace = substringRange.location;
                                                             *stop = YES;
                                                         }];
    return indexOfSpace;
}

- (NSInteger)indexOfFirstSubsequentSpace {
    __block BOOL firstWordFound = NO;
    __block BOOL indexChanged = NO;
    __block NSInteger indexOfSpace = self.textView.selectedRange.location;
    [self.textView.attributedText.string enumerateSubstringsInRange:NSMakeRange(self.textView.selectedRange.location, self.textView.attributedText.string.length - self.textView.selectedRange.location)
                                                            options:NSStringEnumerationByWords
                                                         usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                                             if (firstWordFound == YES) {
                                                                 indexChanged = YES;
                                                                 indexOfSpace = substringRange.location;
                                                                 *stop = YES;
                                                             }
                                                             firstWordFound = YES;
                                                         }];
    if (indexChanged == NO) {
        indexOfSpace = self.textView.attributedText.string.length;
    }
    return indexOfSpace;
}

- (NSInteger)indexOfFirstPreviousLine {
    __block NSInteger indexOfSpace = 0;
    [self.textView.attributedText.string enumerateSubstringsInRange:NSMakeRange(0, self.textView.selectedRange.location)
                                                            options:NSStringEnumerationByLines | NSStringEnumerationReverse
                                                         usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                                             indexOfSpace = substringRange.location;
                                                             *stop = YES;
                                                         }];
    return indexOfSpace;
}

- (NSInteger)indexOfFirstSubsequentLine {
    __block BOOL firstWordFound = NO;
    __block BOOL indexChanged = NO;
    __block NSInteger indexOfSpace = self.textView.selectedRange.location;
    [self.textView.attributedText.string enumerateSubstringsInRange:NSMakeRange(self.textView.selectedRange.location, self.textView.attributedText.string.length - self.textView.selectedRange.location)
                                                            options:NSStringEnumerationByLines
                                                         usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                                             if (firstWordFound == YES) {
                                                                 indexChanged = YES;
                                                                 indexOfSpace = substringRange.location;
                                                                 *stop = YES;
                                                             }
                                                             firstWordFound = YES;
                                                         }];
    if (indexChanged == NO) {
        indexOfSpace = self.textView.attributedText.string.length;
    }
    return indexOfSpace;
}

#pragma mark - Text Attachments

- (void)setOskAttachments:(NSArray *)attachments {
    if (_oskAttachments == nil) {
        _oskAttachments = attachments;
        [self setupAttachmentViews:attachments];
    } else {
        OSKLog(@"OSKTextView does not support replacing existing attachments at this time.");
    }
}

- (void)setupAttachmentViews:(NSArray *)newAttachments {
    CGFloat width;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        width = OSKTextViewAttachmentViewWidth_Phone;
    } else {
        width = OSKTextViewAttachmentViewWidth_Pad;
    }
    CGRect startFrame = CGRectMake(0, 0, width, width);
    for (OSKTextViewAttachment *attachment in newAttachments) {
        OSKTextViewAttachmentView *view = [[OSKTextViewAttachmentView alloc] initWithFrame:startFrame];
        [view setAttachment:attachment];
        view.autoresizingMask = UIViewAutoresizingNone;
        [self.attachmentViews addObject:view];
        [self.textView addSubview:view];
    }
    
    [self updateAttachmentViewFrames];
    
    for (NSInteger index = 0; index < self.attachmentViews.count; index++) {
        OSKTextViewAttachmentView *view = self.attachmentViews[index];
        CGAffineTransform rotation = [self attachmentRotationForPosition:index totalCount:self.attachmentViews.count];
        [view setTransform:rotation];
    }
}

- (void)updateAttachmentViewFrames {
    CGFloat width;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        width = OSKTextViewAttachmentViewWidth_Phone;
    } else {
        width = OSKTextViewAttachmentViewWidth_Pad;
    }
    CGFloat myWidth = self.textView.frame.size.width;
    CGFloat rightPadding = (self.attachmentViews.count > 1) ? 10.0f : 6.0f;
    CGFloat viewWidth = width;
    CGFloat viewHeight = viewWidth;
    CGFloat xOrigin = myWidth - rightPadding - viewWidth;
    CGFloat yOrigin = (self.attachmentViews.count > 1) ? 14.0f : 10.0f;
    CGFloat centerY = yOrigin + viewHeight/2.0f;
    CGFloat centerX = xOrigin + viewWidth/2.0f;
    CGPoint center = CGPointMake(centerX, centerY);
    
    for (NSInteger index = 0; index < self.attachmentViews.count; index++) {
        OSKTextViewAttachmentView *view = self.attachmentViews[index];
        [view setCenter:center];
    }
    
    CGRect frame = CGRectMake(xOrigin, yOrigin, viewWidth, viewHeight);
    UIBezierPath *path = [self exclusionPathForRect:frame];
    [self.textView.textContainer setExclusionPaths:@[path]];
}

- (CGAffineTransform)attachmentRotationForPosition:(NSInteger)position totalCount:(NSInteger)count {
    CGAffineTransform rotation;
    if (position > 2 || position == count-1) {
        rotation = CGAffineTransformIdentity;
    } else {
        CGFloat oneDegreeInRadians = M_PI / 180.0f;
        CGFloat degrees = (3.0f - position) * 4.0f;
        degrees = (position % 2 == 0) ? degrees : degrees*-1.0;
        rotation = CGAffineTransformMakeRotation(degrees * oneDegreeInRadians);
    }
    return rotation;
}

- (UIBezierPath *)exclusionPathForRect:(CGRect)rect {
    CGRect adjustedRect = rect;
    adjustedRect.origin.x -= 6.0f;
    adjustedRect.origin.y = 0.0;
    adjustedRect.size.height = rect.origin.y + rect.size.height;
    adjustedRect.size.width = self.textView.frame.size.width - adjustedRect.origin.x;
    return [UIBezierPath bezierPathWithRect:adjustedRect];
}

#pragma mark - Smart Quotes

- (void)fixDumbQuotes:(NSTextStorage *)mutableString {
    [mutableString.string enumerateSubstringsInRange:NSMakeRange(0, [mutableString length]) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        if ([substring isEqualToString:@"\""]) {
            if (substringRange.location > 0) {
                NSString *previousCharacter = [mutableString.string substringWithRange:NSMakeRange(substringRange.location - 1, 1)];
                if ([previousCharacter isEqualToString:@" "] || [previousCharacter isEqualToString:@"\n"]) {
                    [mutableString replaceCharactersInRange:substringRange withString:@"“"];
                }
                else {
                    [mutableString replaceCharactersInRange:substringRange withString:@"”"];
                }
            }
            else {
                [mutableString replaceCharactersInRange:substringRange withString:@"“"];
            }
        }
        else if ([substring isEqualToString:@"'"]) {
            if (substringRange.location > 0) {
                NSString *previousCharacter = [mutableString.string substringWithRange:NSMakeRange(substringRange.location - 1, 1)];
                if ([previousCharacter isEqualToString:@" "] || [previousCharacter isEqualToString:@"\n"]) {
                    [mutableString replaceCharactersInRange:substringRange withString:@"‘"];
                }
                else {
                    [mutableString replaceCharactersInRange:substringRange withString:@"’"];
                }
            }
            else {
                [mutableString replaceCharactersInRange:substringRange withString:@"‘"];
            }
        }
    }];
}

@end








