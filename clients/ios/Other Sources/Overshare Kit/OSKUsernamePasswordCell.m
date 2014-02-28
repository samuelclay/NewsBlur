//
//  OSKUsernamePasswordCell.m
//  Overshare
//
//  Created by Jared Sinclair on 10/19/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKUsernamePasswordCell.h"

#import "OSKPresentationManager.h"
#import "UIColor+OSKUtility.h"

NSString * const OSKUsernamePasswordCellIdentifier = @"OSKUsernamePasswordCellIdentifier";
CGFloat const OSKUsernamePasswordCellHeight = 44.0f;

@interface OSKUsernamePasswordCell () <UITextFieldDelegate>

@property (strong, nonatomic, readwrite) UITextField *textField;
@property (strong, nonatomic, readwrite) UITextField *textFieldForFakingPlaceholderText;

@end

@implementation OSKUsernamePasswordCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
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
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    CGRect textFrame = CGRectInset(self.contentView.bounds, 16.0f, 0);
    
    UITextField *fakeTextField = [[UITextField alloc] initWithFrame:textFrame];
    [fakeTextField setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [fakeTextField setBackgroundColor:[UIColor clearColor]];
    [fakeTextField setBorderStyle:UITextBorderStyleNone];
    [fakeTextField setTextAlignment:NSTextAlignmentNatural];
    [fakeTextField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [fakeTextField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [self.contentView addSubview:fakeTextField];
    [self setTextFieldForFakingPlaceholderText:fakeTextField];
    [fakeTextField setUserInteractionEnabled:NO];
    
    UITextField *textField = [[UITextField alloc] initWithFrame:textFrame];
    [textField setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [textField setBackgroundColor:[UIColor clearColor]];
    [textField setBorderStyle:UITextBorderStyleNone];
    [textField setTextAlignment:NSTextAlignmentNatural];
    [textField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [textField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [textField setEnablesReturnKeyAutomatically:YES];
    [textField setDelegate:self];
    [self.contentView addSubview:textField];
    [self setTextField:textField];
    
    [self addTextFieldObservations];
    
    UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
    if (descriptor) {
        [fakeTextField setFont:[UIFont fontWithDescriptor:descriptor size:17]];
        [textField setFont:[UIFont fontWithDescriptor:descriptor size:17]];
    }
    
    [self updateColors];
}

- (void)dealloc {
    [self removeTextFieldObservations];
}

- (void)updateColors {
    OSKPresentationManager *presManager = [OSKPresentationManager sharedInstance];
    
    if ([presManager sheetStyle] == OSKActivitySheetViewControllerStyle_Light) {
        [self.textField setKeyboardAppearance:UIKeyboardAppearanceLight];
    } else {
        [self.textField setKeyboardAppearance:UIKeyboardAppearanceDark];
    }
    
    UIColor *textColor = [presManager color_text];
    self.textField.textColor = textColor;
    
    self.backgroundColor = [presManager color_groupedTableViewCells];
    
    UIColor *placeholderColor = [textColor osk_colorByInterpolatingToColor:self.backgroundColor byFraction:0.75];
    self.textFieldForFakingPlaceholderText.textColor = placeholderColor;
    
    self.textField.tintColor = [presManager color_action];
}

- (void)addTextFieldObservations {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldDidChange:) name:UITextFieldTextDidChangeNotification object:_textField];
}

- (void)removeTextFieldObservations {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:_textField];
}

- (void)textFieldDidChange:(NSNotification *)notification {
    [self.delegate usernamePasswordCell:self didChangeText:self.textField.text];
    [self setPlaceholderTextHidden:(self.textField.text.length > 0)];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.delegate usernamePasswordCellDidTapReturn:self];
    return NO;
}

- (void)setPlaceholderTextHidden:(BOOL)hidden {
    [self.textFieldForFakingPlaceholderText setHidden:hidden];
}

- (void)setText:(NSString *)text {
    [self.textField setText:text];
    [self setPlaceholderTextHidden:(text.length > 0)];
}

- (void)setPlaceholder:(NSString *)placeholder {
    [self.textFieldForFakingPlaceholderText setText:placeholder];
}

- (void)setUseSecureInput:(BOOL)useSecureInput {
    [self.textField setSecureTextEntry:useSecureInput];
    if (useSecureInput) {
        [self.textField setReturnKeyType:UIReturnKeyDone];
    } else {
        [self.textField setReturnKeyType:UIReturnKeyNext];
    }
}

- (void)setKeyboardType:(UIKeyboardType)keyboardType {
    [self.textField setKeyboardType:keyboardType];
}

@end









