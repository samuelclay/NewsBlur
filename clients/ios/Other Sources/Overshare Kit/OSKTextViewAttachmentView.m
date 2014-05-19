//
//  OSKTextViewAttachmentView.m
//  Overshare
//
//  Created by Jared on 3/20/14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

#import "OSKTextViewAttachmentView.h"

#import "OSKPresentationManager.h"

static void * OSKTextViewAttachmentViewContext = "OSKTextViewAttachmentViewContext";

@implementation OSKTextViewAttachmentView

- (void)dealloc {
    [self removeObservationsFromAttachment:_attachment];
}

- (void)setAttachment:(OSKTextViewAttachment *)attachment {
    if (_attachment == nil) {
        [self addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        [self removeObservationsFromAttachment:_attachment];
        _attachment = attachment;
        [self addObservationsToAttachment:_attachment];
        [self updateInterface];
    }
}

- (void)updateInterface {
    [self setBackgroundImage:self.attachment.thumbnail forState:UIControlStateNormal];
}

#pragma mark - UIMenuItem Stuff

-(void)tapped:(id)sender {
    [self becomeFirstResponder];
    
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    NSString *itemTitle = [OSKPresentationManager sharedInstance].localizedText_Remove;
    UIMenuItem *removeAttachmentItem = [[UIMenuItem alloc] initWithTitle:itemTitle action:@selector(removeAttachmentItemTapped:)];
    
    NSAssert([self becomeFirstResponder], @"Sorry, UIMenuController will not work with %@ since it cannot become first responder", self);
    [menuController setMenuItems:[NSArray arrayWithObject:removeAttachmentItem]];
    [menuController setTargetRect:self.frame inView:self.superview];
    [menuController setMenuVisible:YES animated:YES];
}

- (void)removeAttachmentItemTapped:(id) sender {
    [self.delegate attachmentViewDidTapRemove:self];
}

- (BOOL)canPerformAction:(SEL)selector withSender:(id) sender {
    BOOL canPerform = NO;
    if (selector == @selector(removeAttachmentItemTapped:)) {
        canPerform = YES;
    }
    return canPerform;
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark - Keep Keyboard Visible While Menu View Controller Popover is Out

// See Ole Begemann's answer here: http://stackoverflow.com/a/4284675/1078579

- (BOOL)hasText {
    return [self.delegate attachmentViewShouldReportHasText:self];
}

- (void)insertText:(NSString *)text {
    [self.delegate attachmentView:self didInsertText:text];
}

- (void)deleteBackward {
    [self.delegate attachmentViewDidDeleteBackward:self];
}

- (UIKeyboardAppearance)keyboardAppearance {
    return [self.delegate attachmentViewKeyboardAppearance:self];
}

- (UIKeyboardType)keyboardType {
    return [self.delegate attachmentViewKeyboardType:self];
}

- (UIReturnKeyType)returnKeyType {
    return [self.delegate attachmentViewReturnKeyType:self];
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
