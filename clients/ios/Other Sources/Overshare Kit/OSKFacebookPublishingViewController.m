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
#import "OSKMicrobloggingActivity.h"
#import "OSKSystemAccountStore.h"
#import "OSKShareableContentItem.h"
#import "OSKPresentationManager.h"
#import "OSKTextView.h"
#import "UIImage+OSKUtilities.h"

@interface OSKFacebookPublishingViewController () <OSKTextViewDelegate, OSKAccountChooserViewControllerDelegate, OSKFacebookAudienceChooserDelegate>

@property (weak, nonatomic) IBOutlet OSKTextView *textView;

@property (strong, nonatomic) OSKFacebookActivity *activity;
@property (strong, nonatomic) OSKMicroblogPostContentItem *contentItem;
@property (strong, nonatomic) UIView *keyboardToolbar;
@property (strong, nonatomic) UIButton *accountButton; // Used on iPhone
@property (strong, nonatomic) UIButton *audienceButton; // Used on iPhone

@end

#define NUM_ROWS 1
#define ROW_TEXT_VIEW 0
#define ROW_ACTIVE_ACCOUNT 1

#define ACCOUNT_BUTTON_INDEX 2
#define AUDIENCE_BUTTON_INDEX 2

#define TOOLBAR_FONT_SIZE 15

@implementation OSKFacebookPublishingViewController

@synthesize oskPublishingDelegate = _oskPublishingDelegate;

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
    [self.textView setTextViewDelegate:self];
    [self.textView setSyntaxHighlighting:[self.activity syntaxHighlightingStyle]];
    [self.textView setText:self.contentItem.text];
    
    [self updateDoneButton];
    
    if (self.contentItem.images.count) {
        NSMutableArray *attachments = [[NSMutableArray alloc] init];
        for (UIImage *image in self.contentItem.images) {
            OSKTextViewAttachment *attachment = [[OSKTextViewAttachment alloc] initWithImage:image];
            [attachments addObject:attachment];
            if (attachments.count == [self.activity maximumImageCount] || attachments.count == 3) {
                break;
            }
        }
        [self.textView setOskAttachments:attachments];
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

#pragma mark - OSKTextView Delegate

- (void)textViewDidChange:(OSKTextView *)textView {
    [self.contentItem setText:textView.attributedText.string];
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
    NSArray *accounts = [store accountsForAccountTypeIdentifier:[activity.class systemAccountTypeIdentifier]];
    ACAccount *activeAccount = activity.activeSystemAccount;
    OSKAccountChooserViewController *chooser = [[OSKAccountChooserViewController alloc] initWithSystemAccounts:accounts activeAccount:activeAccount delegate:self];
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
    [self setContentItem:(OSKMicroblogPostContentItem *)self.activity.contentItem];
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

@end




