//
//  SHKFormController.m
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

#import "SHK.h"
#import "SHKConfiguration.h"
#import "SHKCustomFormController.h"
#import "SHKCustomFormFieldCell.h"


@implementation SHKFormController

@synthesize delegate, validateSelector, saveSelector, cancelSelector; 
@synthesize sections, values;
@synthesize labelWidth;
@synthesize activeField;
@synthesize autoSelect;


- (void)dealloc 
{
	delegate = nil;
	[sections release];
	[values release];
	[activeField release];
	
    [super dealloc];
}


#pragma mark -
#pragma mark Initialization

- (id)initWithStyle:(UITableViewStyle)style title:(NSString *)barTitle rightButtonTitle:(NSString *)rightButtonTitle
{
	if (self = [super initWithStyle:style])
	{
		self.title = barTitle;
		
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
																							  target:self
																							  action:@selector(cancel)] autorelease];
		
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:rightButtonTitle
																				  style:UIBarButtonItemStyleDone
																				 target:self
																				 action:@selector(validateForm)] autorelease];
		
		self.values = [NSMutableDictionary dictionaryWithCapacity:0];
	}
	return self;
}

- (void)addSection:(NSArray *)fields header:(NSString *)header footer:(NSString *)footer
{
	if (sections == nil)
		self.sections = [NSMutableArray arrayWithCapacity:0];
	
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:0];
	[dict setObject:fields forKey:@"rows"];
	
	if (header)
		[dict setObject:header forKey:@"header"];
		
	if (footer)
		[dict setObject:footer forKey:@"footer"];
	
	
	[sections addObject:dict];
	
	if (!SHKCONFIG(usePlaceholders)) {
		// Find the max length of the labels so we can use this value to align the left side of all form fields
		// TODO - should probably save this per section for flexibility
		if (sections.count == 1)
		{
			CGFloat newWidth = 0;
			CGSize size;
			
			for (SHKFormFieldSettings *field in fields)
			{
				// only use text field rows
				if (field.type != SHKFormFieldTypeText && 
					field.type != SHKFormFieldTypeTextNoCorrect &&
					field.type != SHKFormFieldTypePassword)
					continue;
				
				size = [field.label sizeWithFont:[UIFont boldSystemFontOfSize:17]];
				if (size.width > newWidth)
					newWidth = size.width;
			}
			
			self.labelWidth = newWidth;
		}
	}
}

#pragma mark -

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	if (autoSelect)
		[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	// Remove the SHK view wrapper from the window
	[[SHK currentHelper] viewWasDismissed];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	if ([SHKCONFIG(formBgColorRed) intValue] != -1)
		self.tableView.backgroundColor = [UIColor colorWithRed:[SHKCONFIG(formBgColorRed) intValue]/255 green:[SHKCONFIG(formBgColorGreen) intValue]/255 blue:[SHKCONFIG(formBgColorBlue) intValue]/255 alpha:1];
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return [[[sections objectAtIndex:section] objectForKey:@"rows"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    static NSString *CellIdentifier = @"Cell";
    
    SHKCustomFormFieldCell *cell = (SHKCustomFormFieldCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
	{
        cell = [[[SHKCustomFormFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		cell.form = self;
		
		if ([SHKCONFIG(formFontColorRed) intValue] != -1)
			cell.textLabel.textColor = [UIColor colorWithRed:[SHKCONFIG(formFontColorRed) intValue]/255 green:[SHKCONFIG(formFontColorGreen) intValue]/255 blue:[SHKCONFIG(formFontColorBlue) intValue]/255 alpha:1];
	}
	
	// Since we are reusing table cells, make sure to save any existing values before overwriting
	if (cell.settings.key != nil && [cell getValue])
		[values setObject:[cell getValue] forKey:cell.settings.key];
    
	cell.settings = [self rowSettingsForIndexPath:indexPath];
	if(SHKCONFIG(usePlaceholders))
	{
		cell.textField.placeholder = cell.settings.label;
		if(cell.settings.type != SHKFormFieldTypeText &&
		   cell.settings.type != SHKFormFieldTypePassword &&
		   cell.settings.type != SHKFormFieldTypeTextNoCorrect)
		{
			cell.textLabel.text = cell.settings.label;
		}
	}else{
		cell.labelWidth = labelWidth;
		cell.textLabel.text = cell.settings.label;
	}
	
	NSString *value = [values objectForKey:cell.settings.key];
	if (value == nil && cell.settings.start != nil)
		value = cell.settings.start;
	
	[cell setValue:value];
	
    return cell;
}

- (SHKFormFieldSettings *)rowSettingsForIndexPath:(NSIndexPath *)indexPath
{
	return [[[sections objectAtIndex:indexPath.section] objectForKey:@"rows"] objectAtIndex:indexPath.row];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [[sections objectAtIndex:section] objectForKey:@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return [[sections objectAtIndex:section] objectForKey:@"footer"];
}


#pragma mark -

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    return YES;
}


#pragma mark -
#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self validateForm];	
	return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	self.activeField = textField;
}


#pragma mark -
#pragma mark Completion

- (void)close
{
	[[SHK currentHelper] hideCurrentViewControllerAnimated:YES];
}

- (void)cancel
{
	[self close];
	[delegate performSelector:cancelSelector withObject:self];
}

- (void)validateForm
{
	[activeField resignFirstResponder];
	[delegate performSelector:validateSelector withObject:self];
}

- (void)saveForm
{
	[delegate performSelector:saveSelector withObject:self];
	[self close];
}

#pragma mark -

- (NSMutableDictionary *)formValues
{
	return [self formValuesForSection:0];
}
			
- (NSMutableDictionary *)formValuesForSection:(int)section
{
	// go through all form fields and get values
	NSMutableDictionary *formValues = [NSMutableDictionary dictionaryWithCapacity:0];
	
	SHKCustomFormFieldCell *cell;
	int row = 0;
	NSArray *fields = [[sections objectAtIndex:section] objectForKey:@"rows"];
	
	for(SHKFormFieldSettings *field in fields)
	{		
		cell = (SHKCustomFormFieldCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
		
		// Use text field if visible first		
		if ([cell.settings.key isEqualToString:field.key] && [cell getValue] != nil)
			[formValues setObject:[cell getValue] forKey:field.key];
		
		// If field is not visible, use cached value
		else if ([values objectForKey:field.key] != nil)
			[formValues setObject:[values objectForKey:field.key] forKey:field.key];
			
		row++;
	}
	
	return formValues;	
}
		 
		 


@end

