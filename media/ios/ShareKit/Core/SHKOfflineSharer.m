//
//  SHKOfflineSharer.m
//  ShareKit
//
//  Created by Nathan Weiner on 6/22/10.

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

#import "SHKOfflineSharer.h"
#import "SHKSharer.h"

@implementation SHKOfflineSharer

@synthesize item, sharerId, uid;
@synthesize readyToFinish;
@synthesize runLoopThread;
@synthesize sharer;

- (void)dealloc
{
	[item release];
	[sharerId release];
	[uid release];
	[runLoopThread release];
	[sharer release];
	[super dealloc];
}

- (id)initWithItem:(SHKItem *)i forSharer:(NSString *)s uid:(NSString *)u
{
	if (self = [super init])
	{
		self.item = i;
		self.sharerId = s;
		self.uid = u;
	}
	return self;
}

- (void)main
{
	// Make sure it hasn't been cancelled
	if (![self shouldRun])
		return;	
	
	// Save the thread so we can spin up the run loop later
	self.runLoopThread = [NSThread currentThread];
	
	// Run actual sharing on the main thread to avoid thread issues
	[self performSelectorOnMainThread:@selector(share) withObject:nil waitUntilDone:YES];
	
	// Keep the operation alive while we perform the send async
	// This way only one will run at a time
	while([self shouldRun]) 
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
}

- (void)share
{	
	// create sharer
	SHKSharer *aSharer = [[NSClassFromString(sharerId) alloc] init];
    self.sharer = aSharer;
    [aSharer release];
	sharer.item = item;
	sharer.quiet = YES;
	sharer.shareDelegate = self;
	
	if (![sharer isAuthorized])		
	{
		[self finish];
		return;
	}
	
	// reload image from disk and remove the file
	NSString *path;
	if (item.shareType == SHKShareTypeImage)
	{
		path = [[SHK offlineQueuePath] stringByAppendingPathComponent:uid];
		sharer.item.image = [UIImage imageWithContentsOfFile:path];
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		
	}
	
	// reload file from disk and remove the file
	else if (item.shareType == SHKShareTypeFile)						
	{
		path = [[SHK offlineQueueListPath] stringByAppendingPathComponent:uid];
		sharer.item.data = [NSData dataWithContentsOfFile:[[SHK offlineQueuePath] stringByAppendingPathComponent:uid]];
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil]; 

	}
	
	[sharer tryToSend];	
}

- (BOOL)shouldRun
{
	return ![self isCancelled] && ![self isFinished] && !readyToFinish;
}

- (void)finish
{	
	self.readyToFinish = YES;
	[self performSelector:@selector(lastSpin) onThread:runLoopThread withObject:nil waitUntilDone:NO];
}

- (void)lastSpin
{
	// Just used to make the run loop spin
}

#pragma mark -
#pragma mark SHKSharerDelegate

- (void)sharerStartedSending:(SHKSharer *)aSharer
{
	
}

- (void)sharerFinishedSending:(SHKSharer *)aSharer
{	
	sharer.shareDelegate = nil;
	[self finish];
}

- (void)sharer:(SHKSharer *)aSharer failedWithError:(NSError *)error shouldRelogin:(BOOL)shouldRelogin
{
	sharer.shareDelegate = nil;
	[self finish];
}

- (void)sharerCancelledSending:(SHKSharer *)aSharer
{
	sharer.shareDelegate = nil;
	[self finish];
}

- (void)sharerAuthDidFinish:(SHKSharer *)sharer success:(BOOL)success
{

}

@end
