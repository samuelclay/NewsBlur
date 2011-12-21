//
//  SHKFacebookForm.m
//  ShareKit
//

#import "SHKFacebookForm.h"
#import "SHK.h"
#import "SHKFacebook.h"


@implementation SHKFacebookForm

@synthesize delegate;
@synthesize textView;

- (void)dealloc 
{
	[textView release];
    [super dealloc];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) 
	{		
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                               target:self
                                                                                               action:@selector(cancel)] autorelease];
		
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:SHKLocalizedString(@"Send to %@", [SHKFacebook sharerTitle]) 
                                                                                   style:UIBarButtonItemStyleDone
                                                                                  target:self
                                                                                  action:@selector(save)] autorelease];
    }
    return self;
}

- (void)loadView 
{
	[super loadView];
	
	self.view.backgroundColor = [UIColor whiteColor];
	
	self.textView = [[[UITextView alloc] initWithFrame:self.view.bounds] autorelease];
	textView.delegate = self;
	textView.font = [UIFont systemFontOfSize:15];
	textView.contentInset = UIEdgeInsetsMake(5,5,0,0);
	textView.backgroundColor = [UIColor whiteColor];	
	textView.autoresizesSubviews = YES;
	textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
	[self.view addSubview:textView];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];	
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(keyboardWillShow:) name: UIKeyboardWillShowNotification object:nil];
	
	[self.textView becomeFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];	
	
	// Remove observers
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self name: UIKeyboardWillShowNotification object:nil];
	
	// Remove the SHK view wrapper from the window
	[[SHK currentHelper] viewWasDismissed];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    return YES;
}

//#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (void)keyboardWillShow:(NSNotification *)notification
{	
	CGRect keyboardFrame;
	CGFloat keyboardHeight;
	
	// 3.2 and above
	/*if (UIKeyboardFrameEndUserInfoKey)
	 {		
	 [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardFrame];		
	 if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationPortrait || [[UIDevice currentDevice] orientation] == UIDeviceOrientationPortraitUpsideDown) 
	 keyboardHeight = keyboardFrame.size.height;
	 else
	 keyboardHeight = keyboardFrame.size.width;
	 }
	 
	 // < 3.2
	 else 
	 {*/

	[[notification.userInfo valueForKey:UIKeyboardBoundsUserInfoKey] getValue:&keyboardFrame];
	keyboardHeight = keyboardFrame.size.height;
	//}
	
	// Find the bottom of the screen (accounting for keyboard overlay)
	// This is pretty much only for pagesheet's on the iPad
	UIInterfaceOrientation orient = [[UIApplication sharedApplication] statusBarOrientation];
	BOOL inLandscape = orient == UIInterfaceOrientationLandscapeLeft || orient == UIInterfaceOrientationLandscapeRight;
	BOOL upsideDown = orient == UIInterfaceOrientationPortraitUpsideDown || orient == UIInterfaceOrientationLandscapeRight;
	
	CGPoint topOfViewPoint = [self.view convertPoint:CGPointZero toView:nil];
	CGFloat topOfView = inLandscape ? topOfViewPoint.x : topOfViewPoint.y;
	
	CGFloat screenHeight = inLandscape ? [[UIScreen mainScreen] applicationFrame].size.width : [[UIScreen mainScreen] applicationFrame].size.height;
	
	CGFloat distFromBottom = screenHeight - ((upsideDown ? screenHeight - topOfView : topOfView ) + self.view.bounds.size.height) + ([UIApplication sharedApplication].statusBarHidden || upsideDown ? 0 : 20);							
	CGFloat maxViewHeight = self.view.bounds.size.height - keyboardHeight + distFromBottom;
	
	textView.frame = CGRectMake(0,0,self.view.bounds.size.width,maxViewHeight);
}
//#pragma GCC diagnostic pop  

#pragma mark -

- (void)cancel
{	
	[[SHK currentHelper] hideCurrentViewControllerAnimated:YES];
	[(SHKFacebook *)delegate sendDidCancel];
}

- (void)save
{	
    if (textView.text.length == 0)
	{
		[[[[UIAlertView alloc] initWithTitle:SHKLocalizedString(@"Message is empty")
									 message:SHKLocalizedString(@"You must enter a message in order to post.")
									delegate:nil
						   cancelButtonTitle:SHKLocalizedString(@"Close")
						   otherButtonTitles:nil] autorelease] show];
		return;
	}
	
	[(SHKFacebook *)delegate sendForm:self];
	
	[[SHK currentHelper] hideCurrentViewControllerAnimated:YES];
}

@end
