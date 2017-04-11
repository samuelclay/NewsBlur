//
//  IASKTextViewCell.m
//  http://www.inappsettingskit.com
//
//  Copyright (c) 2009-2015:
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

#import "IASKTextViewCell.h"
#import "IASKSettingsReader.h"

@implementation IASKTextViewCell


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		self.accessoryType = UITableViewCellAccessoryNone;

		IASKTextView *textView = [[IASKTextView alloc] initWithFrame:CGRectZero];
		textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		textView.scrollEnabled = NO;
		textView.font = [UIFont systemFontOfSize:17.0];
		textView.backgroundColor = [UIColor whiteColor];
		[self.contentView addSubview:textView];

		self.textView = textView;
    }
    return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	
	UIEdgeInsets padding = (UIEdgeInsets) { 0, kIASKPaddingLeft, 0, kIASKPaddingRight };
	if ([self respondsToSelector:@selector(layoutMargins)]) {
		padding = self.layoutMargins;
		padding.left -= 5;
		padding.right -= 5;
		padding.top -= 5;
		padding.bottom -= 5;
	}
	
	self.textView.frame = UIEdgeInsetsInsetRect(self.bounds, padding);
}

@end
