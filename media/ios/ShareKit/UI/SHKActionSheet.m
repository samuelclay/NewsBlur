//
//  SHKActionSheet.m
//  ShareKit
//
//  Created by Nathan Weiner on 6/10/10.

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

#import "SHKActionSheet.h"
#import "SHK.h"
#import "SHKSharer.h"
#import "SHKCustomShareMenu.h"
#import "SHKCustomActionSheet.h"
#import "SHKShareItemDelegate.h"

#import <Foundation/NSObjCRuntime.h>

@implementation SHKActionSheet

@synthesize item, sharers, shareDelegate;

- (void)dealloc
{
	[item release];
	[sharers release];
	[shareDelegate release];
	[super dealloc];
}

+ (SHKActionSheet *)actionSheetForType:(SHKShareType)type
{
	SHKCustomActionSheet *as = [[SHKCustomActionSheet alloc] initWithTitle:SHKLocalizedString(@"Share")
													  delegate:nil
											 cancelButtonTitle:nil
										destructiveButtonTitle:nil
											 otherButtonTitles:nil];
	as.delegate = as;
	as.item = [[[SHKItem alloc] init] autorelease];
	as.item.shareType = type;
	
	as.sharers = [NSMutableArray arrayWithCapacity:0];
	NSArray *favoriteSharers = [SHK favoriteSharersForType:type];
		
	// Add buttons for each favorite sharer
	id class;
	for(NSString *sharerId in favoriteSharers)
	{
		class = NSClassFromString(sharerId);
		if ([class canShare])
		{
			[as addButtonWithTitle: [class sharerTitle] ];
			[as.sharers addObject:sharerId];
		}
	}
	
	// Add More button
	[as addButtonWithTitle:SHKLocalizedString(@"More...")];
	
	// Add Cancel button
	[as addButtonWithTitle:SHKLocalizedString(@"Cancel")];
	as.cancelButtonIndex = as.numberOfButtons -1;
	
	return [as autorelease];
}

+ (SHKActionSheet *)actionSheetForItem:(SHKItem *)i
{
	SHKActionSheet *as = [self actionSheetForType:i.shareType];
	as.item = i;
	return as;
}

- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated
{
    NSInteger numberOfSharers = (NSInteger) [sharers count];

	// Sharers
	if (buttonIndex >= 0 && buttonIndex < numberOfSharers)
	{
		bool doShare = YES;
		SHKSharer* sharer = [[[NSClassFromString([sharers objectAtIndex:buttonIndex]) alloc] init] autorelease];
		[sharer loadItem:item];
		if (shareDelegate != nil && [shareDelegate respondsToSelector:@selector(aboutToShareItem:withSharer:)])
		{
			doShare = [shareDelegate aboutToShareItem:item withSharer:sharer];
		}
		if(doShare)
			[sharer share];
	}
	
	// More
	else if (buttonIndex == numberOfSharers)
	{
		SHKShareMenu *shareMenu = [[SHKCustomShareMenu alloc] initWithStyle:UITableViewStyleGrouped];
		shareMenu.shareDelegate = shareDelegate;
		shareMenu.item = item;
		[[SHK currentHelper] showViewController:shareMenu];
		[shareMenu release];
	}
	
	[super dismissWithClickedButtonIndex:buttonIndex animated:animated];
}

@end
