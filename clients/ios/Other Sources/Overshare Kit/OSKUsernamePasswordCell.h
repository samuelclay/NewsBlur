//
//  OSKUsernamePasswordCell.h
//  Overshare
//
//  Created by Jared Sinclair on 10/19/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

extern NSString * const OSKUsernamePasswordCellIdentifier;
extern CGFloat const OSKUsernamePasswordCellHeight;

@class OSKUsernamePasswordCell;

@protocol OSKUsernamePasswordCellDelegate <NSObject>

- (void)usernamePasswordCell:(OSKUsernamePasswordCell *)cell didChangeText:(NSString *)text;
- (void)usernamePasswordCellDidTapReturn:(OSKUsernamePasswordCell *)cell;

@end

@interface OSKUsernamePasswordCell : UITableViewCell

@property (weak, nonatomic, readwrite) id <OSKUsernamePasswordCellDelegate> delegate;
@property (strong, nonatomic, readonly) UITextField *textField;
@property (strong, nonatomic, readonly) UITextField *textFieldForFakingPlaceholderText;

- (void)setText:(NSString *)text;
- (void)setPlaceholder:(NSString *)placeholder;
- (void)setUseSecureInput:(BOOL)useSecureInput;
- (void)setKeyboardType:(UIKeyboardType)keyboardType;

@end



