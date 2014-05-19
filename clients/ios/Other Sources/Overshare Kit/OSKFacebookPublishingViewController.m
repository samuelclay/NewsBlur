//
//  OSKFacebookPublishingViewController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/16/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKFacebookPublishingViewController.h"

#import "OSKActivity.h"
#import "OSKActivity_SystemAccounts.h"
#import "OSKActionSheet.h"
#import "OSKAccountChooserViewController.h"
#import "OSKBorderedButton.h"
#import "OSKFacebookActivity.h"
#import "OSKFacebookAudienceChooserViewController.h"
#import "OSKFacebookSharing.h"
#import "OSKSystemAccountStore.h"
#import "OSKShareableContentItem.h"
#import "OSKPresentationManager.h"
#import "OSKMicrobloggingTextView.h"
#import "UIImage+OSKUtilities.h"
#import "UIColor+OSKUtility.h"

@interface OSKFacebookPublishingViewController ()
<
    OSKUITextViewSubstituteDelegate,
    OSKMicrobloggingTextViewAttachmentsDelegate,
    OSKAccountChooserViewControllerDelegate,
    OSKFacebookAudienceChooserDelegate,
    UIWebViewDelegate
>

@property (weak, nonatomic) IBOutlet OSKMicrobloggingTextView *textView;

@property (strong, nonatomic) OSKFacebookActivity *activity;
@property (strong, nonatomic) OSKFacebookContentItem *contentItem;
@property (strong, nonatomic) UIView *keyboardToolbar;
@property (strong, nonatomic) UIButton *accountButton; // Used on iPhone
@property (strong, nonatomic) UIButton *audienceButton; // Used on iPhone
@property (strong, nonatomic) UIWebView *snapshotWebView;
@property (assign, nonatomic) BOOL hasLoadedWebSnapshot;

@end

#define NUM_ROWS 1
#define ROW_TEXT_VIEW 0
#define ROW_ACTIVE_ACCOUNT 1

#define ACCOUNT_BUTTON_INDEX 2
#define AUDIENCE_BUTTON_INDEX 2

#define TOOLBAR_FONT_SIZE 17

@implementation OSKFacebookPublishingViewController

@synthesize oskPublishingDelegate = _oskPublishingDelegate;

#pragma mark - NSObject

- (void)dealloc {
    [_snapshotWebView stopLoading];
    [_snapshotWebView setDelegate:nil];
    _snapshotWebView = nil;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.edgesForExtendedLayout = UIRectEdgeAll;
        self.automaticallyAdjustsScrollViewInsets = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    OSKPresentationManager *presManager = [OSKPresentationManager sharedInstance];
    [self.view setBackgroundColor:presManager.color_opaqueBackground];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self setupKeyboardToolbar];
        [self setupNavigationItems_Phone];
    } else {
        [self setupNavigationItems_Pad];
    }
    
    [self setupTextView];
    [self.textView becomeFirstResponder];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.textView becomeFirstResponder];
}

- (void)setupTextView {
    [self.textView setOskDelegate:self];
    [self.textView setOskAttachmentsDelegate:self];
    [self.textView setSyntaxHighlighting:[self.activity syntaxHighlighting]];
    [self.textView setText:self.contentItem.text];
    
    [self updateDoneButton];
    
    if (self.contentItem.link) {
        UIImage *linkPlaceholderImage = nil;
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            linkPlaceholderImage = [UIImage imageNamed:@"osk_linkPlaceholder_pad.png"];
        } else {
            linkPlaceholderImage = [UIImage imageNamed:@"osk_linkPlaceholder_phone.png"];
        }
        UIColor *accentColor = [[OSKPresentationManager sharedInstance].color_textViewBackground osk_contrastingColor];
        linkPlaceholderImage = [UIImage osk_maskedImage:linkPlaceholderImage color:accentColor];
        OSKTextViewAttachment *attachment = [[OSKTextViewAttachment alloc] initWithImages:@[linkPlaceholderImage]];
        [self.textView setOskAttachment:attachment];
        
        [self generateWebPageSnapshotForLink:self.contentItem.link];
    } else {
        NSUInteger numberOfImages = self.contentItem.images.count;
        if (numberOfImages > 0) {
            NSUInteger numberOfImagesToShow = MIN(MIN([self.activity maximumImageCount], 3), numberOfImages);
            NSArray *imagesToShow = [self.contentItem.images subarrayWithRange:NSMakeRange(0, numberOfImagesToShow)];
            OSKTextViewAttachment *attachment = [[OSKTextViewAttachment alloc] initWithImages:imagesToShow];
            [self.textView setOskAttachment:attachment];
        }
    }
}

- (void)setupKeyboardToolbar {
    OSKPresentationManager *presManager = [OSKPresentationManager sharedInstance];
    
    self.keyboardToolbar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44.0f)];
    self.keyboardToolbar.backgroundColor = presManager.color_toolbarBackground;
    self.keyboardToolbar.clipsToBounds = YES;
    [self.textView setOSK_inputAccessoryView:self.keyboardToolbar];
    CGRect borderedViewFrame = CGRectInset(self.keyboardToolbar.bounds,-1,0);
    borderedViewFrame.origin.y = 0;
    UIView *borderedView = [[UIView alloc] initWithFrame:borderedViewFrame];
    borderedView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    borderedView.backgroundColor = [UIColor clearColor];
    borderedView.layer.borderColor = presManager.color_toolbarBorders.CGColor;
    borderedView.layer.borderWidth = ([[UIScreen mainScreen] scale] > 1) ? 0.5f : 1.0f;
    [self.keyboardToolbar addSubview:borderedView];
    
    [self setupAccountButton];
    [self setupAudienceButton];
}

- (void)setupAccountButton {
    UIButton *accountButton = nil;
    OSKPresentationManager *presManager = [OSKPresentationManager sharedInstance];
    
    if ([presManager toolbarsUseUnjustifiablyBorderlessButtons] == NO) {
        accountButton = [OSKBorderedButton buttonWithType:UIButtonTypeCustom];
        accountButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        accountButton.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 13);
    } else {
        accountButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [accountButton setTitleColor:presManager.color_action forState:UIControlStateNormal];
        accountButton.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
    }
    
    UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
    if (descriptor) {
        [accountButton.titleLabel setFont:[UIFont fontWithDescriptor:descriptor size:TOOLBAR_FONT_SIZE]];
    } else {
        [accountButton.titleLabel setFont:[UIFont systemFontOfSize:TOOLBAR_FONT_SIZE]];
    }
    
    accountButton.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    accountButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    accountButton.frame = CGRectMake(-1, -1, 161, 46);
    [accountButton addTarget:self action:@selector(accountButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.keyboardToolbar addSubview:accountButton];
    [self setAccountButton:accountButton];
    [self updateAccountButton];
}

- (void)setupAudienceButton {
    UIButton *audienceButton = nil;
    OSKPresentationManager *presManager = [OSKPresentationManager sharedInstance];
    
    if ([presManager toolbarsUseUnjustifiablyBorderlessButtons] == NO) {
        audienceButton = [OSKBorderedButton buttonWithType:UIButtonTypeCustom];
        audienceButton.contentEdgeInsets = UIEdgeInsetsMake(0, 13, 0, 12);
    } else {
        audienceButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [audienceButton setTitleColor:presManager.color_action forState:UIControlStateNormal];
        audienceButton.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
    }
    
    UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
    if (descriptor) {
        [audienceButton.titleLabel setFont:[UIFont fontWithDescriptor:descriptor size:TOOLBAR_FONT_SIZE]];
    } else {
        [audienceButton.titleLabel setFont:[UIFont systemFontOfSize:TOOLBAR_FONT_SIZE]];
    }
    
    audienceButton.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    audienceButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    audienceButton.frame = CGRectMake(self.view.frame.size.width - 160, -1, 161, 46);
    [audienceButton addTarget:self action:@selector(audienceButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.keyboardToolbar addSubview:audienceButton];
    [self setAudienceButton:audienceButton];
    [self updateAudienceButton];
}

- (void)setupNavigationItems_Phone {
    NSString *cancelTitle = [[OSKPresentationManager sharedInstance] localizedText_Cancel];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:cancelTitle style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed:)];
    
    NSString *doneTitle = [[OSKPresentationManager sharedInstance] localizedText_ActionButtonTitleForPublishingActivity:[self.activity.class activityType]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:doneTitle style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonPressed:)];
}

- (void)setupNavigationItems_Pad {
    NSString *cancelTitle = [[OSKPresentationManager sharedInstance] localizedText_Cancel];
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:cancelTitle style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed:)];
    
    NSString *doneTitle = [[OSKPresentationManager sharedInstance] localizedText_ActionButtonTitleForPublishingActivity:[self.activity.class activityType]];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneTitle style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonPressed:)];
    
    UIBarButtonItem *accountButton = [[UIBarButtonItem alloc] initWithTitle:@"account" style:UIBarButtonItemStylePlain target:self action:@selector(accountButtonPressed:)];
    UIBarButtonItem *audienceButton = [[UIBarButtonItem alloc] initWithTitle:@"Everyone" style:UIBarButtonItemStylePlain target:self action:@selector(audienceButtonPressed:)];
    
    UIBarButtonItem *space_1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *space_2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *space_3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *space_4 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [self.navigationItem setLeftBarButtonItems:@[cancelButton, space_1, accountButton, space_2]];
    [self.navigationItem setRightBarButtonItems:@[doneButton, space_3, audienceButton, space_4]];
    
    [self updateAccountButton];
    [self updateAudienceButton];
}

#pragma mark - OSKUITextViewSubstituteDelegate

- (void)textViewDidChange:(OSKUITextViewSubstitute *)textView {
    [self.contentItem setText:textView.attributedText.string];
    [self updateDoneButton];
}

#pragma mark - OSKTextViewAttachmentsDelegate

- (BOOL)textView:(OSKMicrobloggingTextView *)textView shouldAllowAttachmentsToBeEdited:(OSKTextViewAttachment *)attachment {
    BOOL isALinkPost = (self.contentItem.link != nil);
    return (isALinkPost == NO);
}

- (BOOL)textViewShouldUseBorderedAttachmentView:(OSKMicrobloggingTextView *)textView {
    return (self.hasLoadedWebSnapshot);
}

- (void)textViewDidTapRemoveAttachment:(OSKMicrobloggingTextView *)textView {
    [textView removeAttachment];
    [self.contentItem setImages:nil];
    [self updateDoneButton];
}

#pragma mark - Autorotation

- (void)viewDidLayoutSubviews {
    CGRect toolbarBounds = self.keyboardToolbar.bounds;
    CGFloat targetHeight;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        targetHeight = UIInterfaceOrientationIsLandscape(self.interfaceOrientation) ? 32.0f : 44.0f;
    } else {
        targetHeight = 44.0f;
    }
    toolbarBounds.size.height = targetHeight;
    [self.keyboardToolbar setBounds:toolbarBounds];
    [self updateAccountButton];
    [self updateAudienceButton];
    [self adjustTextViewTopInset];
}

- (void)adjustTextViewTopInset {
    UIEdgeInsets insets = self.textView.contentInset;
    insets.top = [self.topLayoutGuide length];
    self.textView.contentInset = insets;
    
    UIEdgeInsets indicatorInsets = self.textView.scrollIndicatorInsets;
    indicatorInsets.top = [self.topLayoutGuide length];
    [self.textView setScrollIndicatorInsets:indicatorInsets];
}

#pragma mark - Done Button

- (void)updateDoneButton {
    [self.navigationItem.rightBarButtonItem setEnabled:[self.activity isReadyToPerform]];
}

- (void)doneButtonPressed:(id)sender {
    if ([self.activity isReadyToPerform]) {
        [self.oskPublishingDelegate publishingViewController:self didTapPublishActivity:self.activity];
    }
}

#pragma mark - Account Button Changes

- (void)updateAccountButton {
    NSString *accountName = nil;
    if ([self.activity respondsToSelector:@selector(activeSystemAccount)]) {
        ACAccount *systemAccount = [(OSKActivity <OSKActivity_SystemAccounts> *)self.activity activeSystemAccount];
        if (systemAccount.username.length) {
            accountName = systemAccount.username;
        } else if (systemAccount.userFullName.length) {
            accountName = systemAccount.userFullName;
        } else {
            accountName = self.title;
        }
    }
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self updateAccountButton_Phone:accountName];
    } else {
        [self updateAccountButton_Pad:accountName];
    }
}

- (void)updateAccountButton_Phone:(NSString *)accountName {
    [self.accountButton setTitle:[NSString stringWithFormat:@"%@", accountName] forState:UIControlStateNormal];
    CGSize newSize = [self.accountButton sizeThatFits:self.keyboardToolbar.bounds.size];
    CGRect buttonFrame = self.accountButton.frame;
    buttonFrame.size.width = newSize.width;
    [self.accountButton setFrame:buttonFrame];
}

- (void)updateAccountButton_Pad:(NSString *)accountName {
    UIBarButtonItem *item = self.navigationItem.leftBarButtonItems[ACCOUNT_BUTTON_INDEX];
    [item setTitle:accountName];
}

- (void)accountButtonPressed:(id)sender {
    [self showSystemAccountChooser];
}

- (void)showSystemAccountChooser {
    OSKSystemAccountStore *store = [OSKSystemAccountStore sharedInstance];
    OSKActivity <OSKActivity_SystemAccounts> *activity = (OSKActivity <OSKActivity_SystemAccounts> *)self.activity;
    NSString *systemAccountTypeIdentifier = [activity.class systemAccountTypeIdentifier];
    NSArray *accounts = [store accountsForAccountTypeIdentifier:systemAccountTypeIdentifier];
    ACAccount *activeAccount = activity.activeSystemAccount;
    OSKAccountChooserViewController *chooser = [[OSKAccountChooserViewController alloc]
                                                initWithSystemAccounts:accounts
                                                activeAccount:activeAccount
                                                accountTypeIdentifier:systemAccountTypeIdentifier
                                                delegate:self];
    [self.navigationController pushViewController:chooser animated:YES];
}

#pragma mark - Audience Changes

- (void)updateAudienceButton {
    NSString *audienceName = nil;
    NSString *audienceKey = [self.activity currentAudience];
    if ([audienceKey isEqualToString:ACFacebookAudienceEveryone]) {
        audienceName = @"Public";
    }
    else if ([audienceKey isEqualToString:ACFacebookAudienceFriends]) {
        audienceName = @"Friends";
    }
    else if ([audienceKey isEqualToString:ACFacebookAudienceOnlyMe]) {
        audienceName = @"Only Me";
    }
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self updateAudienceButton_Phone:audienceName];
    } else {
        [self updateAudienceButton_Pad:audienceName];
    }
}

- (void)updateAudienceButton_Phone:(NSString *)audienceName {
    [self.audienceButton setTitle:[NSString stringWithFormat:@"%@", audienceName] forState:UIControlStateNormal];
    CGSize newSize = [self.audienceButton sizeThatFits:self.keyboardToolbar.bounds.size];
    CGRect buttonFrame = self.audienceButton.frame;
    buttonFrame.size.width = newSize.width;
    buttonFrame.origin.x = self.view.frame.size.width - newSize.width + 1.0f;
    [self.audienceButton setFrame:buttonFrame];
}

- (void)updateAudienceButton_Pad:(NSString *)audienceName {
    UIBarButtonItem *item = self.navigationItem.rightBarButtonItems[AUDIENCE_BUTTON_INDEX];
    [item setTitle:audienceName];
}

- (void)audienceButtonPressed:(id)sender {
    [self showAudienceChooser];
}

- (void)showAudienceChooser {
    OSKFacebookAudienceChooserViewController *chooser = [[OSKFacebookAudienceChooserViewController alloc]
                                                         initWithSelectedAudience:self.activity.currentAudience
                                                         delegate:self];
    [self.navigationController pushViewController:chooser animated:YES];
}

- (void)setNewCurrentAudience:(NSString *)audience {
    [self.activity setCurrentAudience:audience];
    [self updateAudienceButton];
}

#pragma mark - Button Actions

- (void)cancelButtonPressed:(id)sender {
    [self.oskPublishingDelegate publishingViewControllerDidCancel:self withActivity:self.activity];
}

#pragma mark - Publishing View Controller

- (void)preparePublishingViewForActivity:(OSKActivity *)activity delegate:(id <OSKPublishingViewControllerDelegate>)oskPublishingDelegate {
    [self setActivity:(OSKFacebookActivity *)activity];
    [self setContentItem:(OSKFacebookContentItem *)self.activity.contentItem];
    [self setOskPublishingDelegate:oskPublishingDelegate];
    self.title = [self.activity.class activityName];
}

#pragma mark - Account Chooser Delegate

- (void)accountChooserDidSelectSystemAccount:(ACAccount *)systemAccount {
    [self.activity setActiveSystemAccount:systemAccount];
    [self updateAccountButton];
}

#pragma mark - Audience Chooser Delegate

- (void)audienceChooser:(OSKFacebookAudienceChooserViewController *)chooser didChooseNewAudience:(NSString *)audience {
    [self setNewCurrentAudience:audience];
}

#pragma mark - Web Page Snapshot

- (void)generateWebPageSnapshotForLink:(NSURL *)link {
    if (self.snapshotWebView == nil) {
        self.snapshotWebView = [[UIWebView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.snapshotWebView.delegate = self;
        self.snapshotWebView.suppressesIncrementalRendering = NO;
        self.snapshotWebView.scalesPageToFit = YES;
        [self.snapshotWebView loadRequest:[NSURLRequest requestWithURL:link]];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (self.hasLoadedWebSnapshot == NO) {
        [self setHasLoadedWebSnapshot:YES];
        // Wait a second or two for page load animations to finish,
        // especially for sites like Twitter or an Apple product announcement.
        __weak OSKFacebookPublishingViewController *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [weakSelf grabSnapShotFromLoadedWebView:webView];
        });
    }
}

- (void)grabSnapShotFromLoadedWebView:(UIWebView *)webView {
    
    CGFloat snapshotWidth = webView.frame.size.width;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(snapshotWidth, snapshotWidth), YES, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [webView.layer renderInContext:context];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    OSKTextViewAttachment *attachment = [[OSKTextViewAttachment alloc] initWithImages:@[image]];
    [self.textView setOskAttachment:attachment];
    
    [self.snapshotWebView setDelegate:nil];
    [self.snapshotWebView stopLoading];
    [self setSnapshotWebView:nil];
}

@end








