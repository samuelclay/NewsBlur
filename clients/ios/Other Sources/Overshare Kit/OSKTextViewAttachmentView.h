//
//  OSKTextViewAttachmentView.h
//  Overshare
//
//  Created by Jared on 3/20/14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "OSKTextViewAttachment.h"

@class OSKTextViewAttachmentView;

@protocol OSKTextViewAttachmentViewDelegate <NSObject>

- (void)attachmentViewDidTapRemove:(OSKTextViewAttachmentView *)view;
- (BOOL)attachmentViewShouldReportHasText:(OSKTextViewAttachmentView *)view;
- (void)attachmentView:(OSKTextViewAttachmentView *)view didInsertText:(NSString *)text;
- (void)attachmentViewDidDeleteBackward:(OSKTextViewAttachmentView *)view;
- (UIKeyboardAppearance)attachmentViewKeyboardAppearance:(OSKTextViewAttachmentView *)view;
- (UIKeyboardType)attachmentViewKeyboardType:(OSKTextViewAttachmentView *)view;
- (UIReturnKeyType)attachmentViewReturnKeyType:(OSKTextViewAttachmentView *)view;

@end

@interface OSKTextViewAttachmentView : UIButton <UIKeyInput>

@property (strong, nonatomic) OSKTextViewAttachment *attachment;
@property (weak, nonatomic) id <OSKTextViewAttachmentViewDelegate> delegate;

@end
