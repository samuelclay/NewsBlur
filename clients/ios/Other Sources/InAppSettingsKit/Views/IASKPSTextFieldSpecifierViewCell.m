//
//  IASKPSTextFieldSpecifierViewCell.m
//  http://www.inappsettingskit.com
//
//  Copyright (c) 2009-2010:
//  Luc Vandal, Edovia Inc., http://www.edovia.com
//  Ortwin Gentz, FutureTap GmbH, http://www.futuretap.com
//  All rights reserved.
// 
//  It is appreciated but not required that you give credit to Luc Vandal and Ortwin Gentz, 
//  as the original authors of this code. You can give credit in a blog post, a tweet or on 
//  a info page of your app. Also, the original authors appreciate letting them know if you use this code.
//
//  This code is licensed under the BSD license that is available at: http://www.opensource.org/licenses/bsd-license.php
//

#import "IASKPSTextFieldSpecifierViewCell.h"
#import "IASKTextField.h"
#import "IASKSettingsReader.h"

@implementation IASKPSTextFieldSpecifierViewCell
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
		self.textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin;

        // TextField
        _textField = [[IASKTextField alloc] initWithFrame:CGRectMake(0, 0, 200, self.frame.size.height)];
        _textField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin;
        _textField.font = [UIFont systemFontOfSize:kIASKLabelFontSize];
        _textField.minimumFontSize = kIASKMinimumFontSize;
        IASK_IF_PRE_IOS7(_textField.textColor = [UIColor colorWithRed:0.275f green:0.376f blue:0.522f alpha:1.000f];);
        [self.contentView addSubview:_textField];
        
        self.selectionStyle = UITableViewCellSelectionStyleNone; 
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    UIEdgeInsets padding = (UIEdgeInsets) { 0, kIASKPaddingLeft, 0, kIASKPaddingRight };
    if ([self respondsToSelector:@selector(layoutMargins)]) {
        padding = [self layoutMargins];
    }
    
    // Label
	CGFloat imageOffset = self.imageView.image ? self.imageView.bounds.size.width + padding.left : 0;
    CGSize labelSize = [self.textLabel sizeThatFits:CGSizeZero];
	labelSize.width = MAX(labelSize.width, kIASKMinLabelWidth - imageOffset);
    self.textLabel.frame = (CGRect){self.textLabel.frame.origin, {MIN(kIASKMaxLabelWidth, labelSize.width), self.textLabel.frame.size.height}} ;

    // TextField
    _textField.center = CGPointMake(_textField.center.x, self.contentView.center.y);
	CGRect textFieldFrame = _textField.frame;
	textFieldFrame.origin.x = self.textLabel.frame.origin.x + MAX(kIASKMinLabelWidth - imageOffset, self.textLabel.frame.size.width) + kIASKSpacing;
	textFieldFrame.size.width = _textField.superview.frame.size.width - textFieldFrame.origin.x - padding.right;
	
	if (!self.textLabel.text.length) {
		textFieldFrame.origin.x = padding.left + imageOffset;
		textFieldFrame.size.width = self.contentView.bounds.size.width - padding.left - padding.right - imageOffset;
	} else if (_textField.textAlignment == NSTextAlignmentRight) {
		textFieldFrame.origin.x = self.textLabel.frame.origin.x + labelSize.width + kIASKSpacing;
		textFieldFrame.size.width = _textField.superview.frame.size.width - textFieldFrame.origin.x - padding.right;
	}
	_textField.frame = textFieldFrame;
}

@end
