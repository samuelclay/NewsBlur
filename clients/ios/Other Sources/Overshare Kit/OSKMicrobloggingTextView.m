//
//  OSKTextView.m
//  Based on JTSTextView by Jared Sinclair
//
//  Created by Jared Sinclair on 10/26/13.
//  Copyright (c) 2013 Nice Boy LLC. All rights reserved.
//

#import "OSKMicrobloggingTextView.h"

#import "OSKLogger.h"
#import "OSKPresentationManager.h"
#import "OSKTwitterText.h"
#import "OSKSmartPunctuation.h"
#import "OSKTextViewAttachment.h"
#import "OSKTextViewAttachmentView.h"
#import "OSKCursorMovement.h"
#import "UIColor+OSKUtility.h"

@interface OSKMicrobloggingTextView ()
<
    NSTextStorageDelegate,
    OSKTextViewAttachmentViewDelegate
>

@property (strong, nonatomic) NSDictionary *attributes_normal;
@property (strong, nonatomic) NSDictionary *attributes_mentions;
@property (strong, nonatomic) NSDictionary *attributes_hashtags;
@property (strong, nonatomic) NSDictionary *attributes_links;
@property (strong, nonatomic, readwrite) NSArray *detectedLinks;
@property (strong, nonatomic) OSKTextViewAttachmentView *attachmentView;
@property (strong, nonatomic) OSKCursorMovement *cursorMovement;

@end

@implementation OSKMicrobloggingTextView

#pragma mark - UIView

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    if (self.attachmentView) {
        [self updateAttachmentViewFrames];
    }
}

#pragma mark - OSKUITextViewSubtitute

- (void)commonInit {
    [super commonInit];
    [self.textView.textStorage setDelegate:self];
    self.cursorMovement = [[OSKCursorMovement alloc] initWithTextView:self.textView];
    [self setupAttributes];
}

#pragma mark - Text Storage Delegate

- (void)textStorage:(NSTextStorage *)textStorage
 willProcessEditing:(NSTextStorageEditActions)editedMask
              range:(NSRange)editedRange
     changeInLength:(NSInteger)delta {
    
    NSInteger lengthChange = [OSKSmartPunctuation fixDumbPunctuation:textStorage editedRange:editedRange textInputObject:self.textView];
    
    if (lengthChange != 0) {
        NSRange selectedRange = [self.textView selectedRange];
        selectedRange.location += lengthChange;
        [self.textView setSelectedRange:selectedRange];
    }
    
    [self updateSyntaxHighlighting:textStorage];
}

#pragma mark - Syntax Highlighting

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
        boldFont = [UIFont boldSystemFontOfSize:fontSize];
    }
    
    UIColor *normalColor = manager.color_text;
    UIColor *actionColor = manager.color_action;
    UIColor *hashtagColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    
    _attributes_normal = @{NSFontAttributeName:normalFont,
                           NSForegroundColorAttributeName:normalColor};
    
    _attributes_mentions = @{NSFontAttributeName:boldFont,
                             NSForegroundColorAttributeName:actionColor};
    
    _attributes_hashtags = @{NSFontAttributeName:normalFont,
                             NSForegroundColorAttributeName:hashtagColor};
    
    _attributes_links = @{NSFontAttributeName:normalFont,
                          NSForegroundColorAttributeName:actionColor};
    
    [self.textView setTypingAttributes:_attributes_normal];
    
    [self setTintColor:actionColor];
    [self.textView setTintColor:actionColor];
    [self setBackgroundColor:manager.color_textViewBackground];
    [self.textView setBackgroundColor:manager.color_textViewBackground];
    
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

- (void)updateSyntaxHighlighting:(NSTextStorage *)textStorage {
    
    // This method could have poor performance for very long runs of text.
    // Consider refactoring to only inspect the region around the edited range. ~ JTS March 21, 2014.
    
    // Apply default attributes to the entire string
    [textStorage addAttributes:self.attributes_normal range:NSMakeRange(0, textStorage.length)];
    
    if (self.syntaxHighlighting == OSKSyntaxHighlighting_None) {
        [self setDetectedLinks:nil];
    } else {
        BOOL useLinks = (self.syntaxHighlighting & OSKSyntaxHighlighting_Links);
        BOOL useUsernames = (self.syntaxHighlighting & OSKSyntaxHighlighting_Usernames);
        BOOL useHashtags = (self.syntaxHighlighting & OSKSyntaxHighlighting_Hashtags);
        NSArray *allEntities = [OSKTwitterText entitiesInText:textStorage.string];
        NSMutableArray *links = [[NSMutableArray alloc] init];
        for (OSKTwitterTextEntity *anEntity in allEntities) {
            switch (anEntity.type) {
                case OSKTwitterTextEntityHashtag: {
                    if (useHashtags) {
                        [textStorage addAttributes:self.attributes_hashtags range:anEntity.range];
                    }
                } break;
                case OSKTwitterTextEntityScreenName: {
                    if (useUsernames) {
                        NSString *lowercaseName = [textStorage.string substringWithRange:anEntity.range].lowercaseString;
                        [textStorage replaceCharactersInRange:anEntity.range withString:lowercaseName];
                        [textStorage addAttributes:self.attributes_mentions range:anEntity.range];
                    }
                } break;
                case OSKTwitterTextEntityURL: {
                    if (useLinks) {
                        [textStorage addAttributes:self.attributes_links range:anEntity.range];
                        [links addObject:anEntity];
                    }
                } break;
                default:
                    break;
            }
        }
        [self setDetectedLinks:links];
    }
}

#pragma mark - Text Attachments

- (void)setOskAttachment:(OSKTextViewAttachment *)attachment {
    if (self.attachmentView) {
        [self.attachmentView removeFromSuperview];
        [self setAttachmentView:nil];
    }
    _oskAttachment = attachment;
    if (_oskAttachment) {
        [self setupAttachmentView:attachment];
    }
}

- (void)setupAttachmentView:(OSKTextViewAttachment *)newAttachment {
    CGFloat width;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        width = OSKTextViewAttachmentViewWidth_Phone;
    } else {
        width = OSKTextViewAttachmentViewWidth_Pad;
    }
    
    CGSize thumbSize = CGSizeMake(width, width);
    CGSize sizeNeeded = [OSKTextViewAttachment sizeNeededForThumbs:newAttachment.images.count ofIndividualSize:thumbSize];
    CGRect startFrame = CGRectMake(0, 0, sizeNeeded.width, sizeNeeded.height);
    
    OSKTextViewAttachmentView *attachmentView = [OSKTextViewAttachmentView buttonWithType:UIButtonTypeCustom];
    [attachmentView setFrame:startFrame];
    [attachmentView setAttachment:newAttachment];
    [attachmentView setDelegate:self];
    attachmentView.autoresizingMask = UIViewAutoresizingNone;
    attachmentView.backgroundColor = [UIColor clearColor];
    [self.textView addSubview:attachmentView];
    [self setAttachmentView:attachmentView];
    
    if ([self.oskAttachmentsDelegate respondsToSelector:@selector(textViewShouldUseBorderedAttachmentView:)]) {
        BOOL useBorders = [self.oskAttachmentsDelegate textViewShouldUseBorderedAttachmentView:self];
        if (useBorders) {
            OSKActivitySheetViewControllerStyle sheetStyle = [OSKPresentationManager sharedInstance].sheetStyle;
            UIColor *contrastingColor = (sheetStyle == OSKActivitySheetViewControllerStyle_Dark)
                                        ? [UIColor colorWithWhite:1 alpha:0.2]
                                        : [UIColor colorWithWhite:0 alpha:0.2];
            CGFloat borderWidth = ([UIScreen mainScreen].scale > 1) ? 0.5f : 1.0f;
            self.attachmentView.layer.borderWidth = borderWidth;
            self.attachmentView.layer.borderColor = contrastingColor.CGColor;
        }
    }
    
    if ([self.oskAttachmentsDelegate textView:self shouldAllowAttachmentsToBeEdited:newAttachment]) {
        [self.attachmentView setUserInteractionEnabled:YES];
    } else {
        [self.attachmentView setUserInteractionEnabled:NO];
    }
    
    [self updateAttachmentViewFrames];
}

- (void)updateAttachmentViewFrames {
    CGFloat width;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        width = OSKTextViewAttachmentViewWidth_Phone;
    } else {
        width = OSKTextViewAttachmentViewWidth_Pad;
    }
    NSUInteger numberOfImages = self.attachmentView.attachment.images.count;
    CGFloat myWidth = self.textView.frame.size.width;
    CGFloat padding = (numberOfImages > 1) ? 14.0f : 8.0f;
    CGFloat viewWidth = width;
    CGFloat viewHeight = viewWidth;
    CGFloat xOrigin = myWidth - padding - viewWidth;
    CGFloat yOrigin = (numberOfImages > 1) ? 14.0f : 10.0f;
    CGFloat centerY = yOrigin + viewHeight/2.0f;
    CGFloat centerX = xOrigin + viewWidth/2.0f;
    CGPoint center = CGPointMake(centerX, centerY);
    
    [_attachmentView setCenter:center];
    
    CGRect frame = CGRectMake(xOrigin, yOrigin, viewWidth, viewHeight);
    UIBezierPath *path = [self exclusionPathForRect:frame desiredInnerPadding:padding];
    [self.textView.textContainer setExclusionPaths:@[path]];
}

- (UIBezierPath *)exclusionPathForRect:(CGRect)rect
                   desiredInnerPadding:(CGFloat)padding {
    CGRect adjustedRect = rect;
    adjustedRect.origin.x -= padding;
    adjustedRect.origin.y = 0.0;
    adjustedRect.size.height = rect.origin.y + rect.size.height;
    adjustedRect.size.width = self.textView.frame.size.width - adjustedRect.origin.x;
    return [UIBezierPath bezierPathWithRect:adjustedRect];
}

- (void)removeAttachment {
    [self.attachmentView removeFromSuperview];
    [self setAttachmentView:nil];
    [self setOskAttachment:nil];
    [self.textView.textContainer setExclusionPaths:nil];
}

#pragma mark - OSKTextViewAttachmentViewDelegate

- (void)attachmentViewDidTapRemove:(OSKTextViewAttachmentView *)view {
    [view resignFirstResponder];
    [self becomeFirstResponder];
    [self.oskAttachmentsDelegate textViewDidTapRemoveAttachment:self];
}

- (BOOL)attachmentViewShouldReportHasText:(OSKTextViewAttachmentView *)view {
    return [self.textView hasText];
}

- (void)attachmentView:(OSKTextViewAttachmentView *)view
         didInsertText:(NSString *)text {
    [view resignFirstResponder];
    [self becomeFirstResponder];
    [self insertText:text];
}

- (void)attachmentViewDidDeleteBackward:(OSKTextViewAttachmentView *)view {
    [view resignFirstResponder];
    [self becomeFirstResponder];
    [self.textView deleteBackward];
}

- (UIKeyboardAppearance)attachmentViewKeyboardAppearance:(OSKTextViewAttachmentView *)view {
    return self.textView.keyboardAppearance;
}

- (UIKeyboardType)attachmentViewKeyboardType:(OSKTextViewAttachmentView *)view {
    return self.textView.keyboardType;
}

- (UIReturnKeyType)attachmentViewReturnKeyType:(OSKTextViewAttachmentView *)view {
    return self.textView.returnKeyType;
}

@end



