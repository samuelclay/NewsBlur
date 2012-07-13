//
//  SHKFormController.h
//  ShareKit
//
//  Created by Nathan Weiner on 6/17/10.

//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//

#import <UIKit/UIKit.h>
#import "SHKFormFieldSettings.h"
#import "SHKCustomFormFieldCell.h"

@interface SHKFormController : UITableViewController <UITextFieldDelegate>
{
	id delegate;
	SEL validateSelector;
	SEL saveSelector;	
	SEL cancelSelector;	
	
	NSMutableArray *sections;
	NSMutableDictionary *values;
	
	CGFloat labelWidth;
	
	UITextField *activeField;
	
	BOOL autoSelect;
}

@property (assign) id delegate;
@property SEL validateSelector;
@property SEL saveSelector;
@property SEL cancelSelector;

@property (retain) NSMutableArray *sections;
@property (retain) NSMutableDictionary *values;

@property CGFloat labelWidth;

@property (nonatomic, retain) UITextField *activeField;

@property BOOL autoSelect;


- (id)initWithStyle:(UITableViewStyle)style title:(NSString *)barTitle rightButtonTitle:(NSString *)rightButtonTitle;
- (void)addSection:(NSArray *)fields header:(NSString *)header footer:(NSString *)footer;

#pragma mark -

- (SHKFormFieldSettings *)rowSettingsForIndexPath:(NSIndexPath *)indexPath;

#pragma mark -
#pragma mark Completion

- (void)close;
- (void)cancel;
- (void)validateForm;
- (void)saveForm;

#pragma mark -

- (NSMutableDictionary *)formValues;
- (NSMutableDictionary *)formValuesForSection:(int)section;

@end
