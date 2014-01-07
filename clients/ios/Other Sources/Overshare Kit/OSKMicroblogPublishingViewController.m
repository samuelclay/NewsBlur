//
//  OSKMicroblogPublishingViewController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/16/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKMicroblogPublishingViewController.h"

#import "OSKActivity.h"
#import "OSKActivity_SystemAccounts.h"
#import "OSKActivity_ManagedAccounts.h"
#import "OSKActionSheet.h"
#import "OSKBorderedButton.h"
#import "OSKManagedAccountStore.h"
#import "OSKSystemAccountStore.h"
#import "OSKMicrobloggingActivity.h"
#import "OSKShareableContentItem.h"
#import "OSKPresentationManager.h"
#import "OSKTextView.h"
#import "OSKManagedAccount.h"
#import "OSKAccountChooserViewController.h"
#import "UIImage+OSKUtilities.h"
#import "OSKLinkShorteningUtility.h"
#import "OSKTwitterText.h"

@interface OSKMicroblogPublishingViewController () <OSKTextViewDelegate, OSKAccountChooserViewControllerDelegate>

@property (weak, nonatomic) IBOutlet OSKTextView *textView;

@property (strong, nonatomic) OSKActivity <OSKMicrobloggingActivity> *activity;
@property (strong, nonatomic) OSKMicroblogPostContentItem *contentItem;
@property (strong, nonatomic) UIView *keyboardToolbar;
@property (strong, nonatomic) UILabel *characterCountLabel;
@property (strong, nonatomic) UIColor *characterCount_redColor;
@property (strong, nonatomic) UIColor *characterCount_normalColor;
@property (strong, nonatomic) UIButton *accountButton; // Used on iPhone
@property (assign, nonatomic) BOOL hasAttemptedURLShortening;

@end

#define NUM_ROWS 1
#define ROW_TEXT_VIEW 0
#define ROW_ACTIVE_ACCOUNT 1
#define ACCOUNT_BUTTON_INDEX 2
#define TOOLBAR_FONT_SIZE 15

@implementation OSKMicroblogPublishingViewController

@synthesize oskPublishingDelegate = _oskPublishingDelegate;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.edgesForExtendedLayout = UIRectEdgeAll;
        self.automaticallyAdjustsScrollViewInsets = NO;
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
    
    [self updateRemainingCharacterCountLabel];
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

    // TOOLBAR
    self.keyboardToolbar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44.0f)];
    self.keyboardToolbar.backgroundColor = presManager.color_toolbarBackground;
    self.keyboardToolbar.clipsToBounds = YES;
    [self.textView setOSK_inputAccessoryView:self.keyboardToolbar];
    
    // BORDER VIEW
    CGRect borderedViewFrame = CGRectInset(self.keyboardToolbar.bounds,-1,0);
    borderedViewFrame.origin.y = 0;
    UIView *borderedView = [[UIView alloc] initWithFrame:borderedViewFrame];
    borderedView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    borderedView.backgroundColor = [UIColor clearColor];
    borderedView.layer.borderColor = presManager.color_toolbarBorders.CGColor;
    borderedView.layer.borderWidth = ([[UIScreen mainScreen] scale] > 1) ? 0.5f : 1.0f;
    [self.keyboardToolbar addSubview:borderedView];
    
    // CHARACTER COUNT LABEL
    CGRect countLabelFrame = CGRectMake(0, 0, 64.0f, 44.0f);
    countLabelFrame.origin.x = self.keyboardToolbar.bounds.size.width - 74.0f;
    UILabel *countLabel = [[UILabel alloc] initWithFrame:countLabelFrame];
    countLabel.backgroundColor = [UIColor clearColor];
    countLabel.clipsToBounds = NO;
    countLabel.textAlignment = NSTextAlignmentRight;
    countLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin  | UIViewAutoresizingFlexibleHeight;
    countLabel.textColor = presManager.color_characterCounter_normal;
    [self.keyboardToolbar addSubview:countLabel];
    [self setCharacterCountLabel:countLabel];
    [self updateRemainingCharacterCountLabel];
    
    // ACCOUNT BUTTON
    UIButton *accountButton = nil;
    
    if ([presManager toolbarsUseUnjustifiablyBorderlessButtons] == NO) {
        accountButton = [OSKBorderedButton buttonWithType:UIButtonTypeCustom];
        accountButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
        accountButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        accountButton.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 13);
    } else {
        accountButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [accountButton setTitleColor:presManager.color_action forState:UIControlStateNormal];
        accountButton.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
    }
    
    accountButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
    accountButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    accountButton.frame = CGRectMake(-1, -1, 161, 46);
    [accountButton addTarget:self action:@selector(accountButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.keyboardToolbar addSubview:accountButton];
    [self setAccountButton:accountButton];
    
    UIFontDescriptor *descriptor = [presManager normalFontDescriptor];
    if (descriptor) {
        countLabel.font = [UIFont fontWithDescriptor:descriptor size:TOOLBAR_FONT_SIZE];
        [accountButton.titleLabel setFont:[UIFont fontWithDescriptor:descriptor size:TOOLBAR_FONT_SIZE]];
    } else {
        countLabel.font = [UIFont systemFontOfSize:TOOLBAR_FONT_SIZE];
        [accountButton.titleLabel setFont:[UIFont systemFontOfSize:TOOLBAR_FONT_SIZE]];
    }
    
    [self updateAccountButton];
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
    
    // CHARACTER COUNT LABEL
    CGRect countLabelFrame = CGRectMake(0, 0, 72.0f, 44.0f);
    UILabel *countLabel = [[UILabel alloc] initWithFrame:countLabelFrame];
    countLabel.backgroundColor = [UIColor clearColor];
    countLabel.clipsToBounds = NO;
    countLabel.textAlignment = NSTextAlignmentCenter;
    countLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin  | UIViewAutoresizingFlexibleHeight;
    UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
    if (descriptor) {
        countLabel.font = [UIFont fontWithDescriptor:descriptor size:17];
    } else {
        countLabel.font = [UIFont systemFontOfSize:17];
    }
    countLabel.textColor = [OSKPresentationManager sharedInstance].color_characterCounter_normal;
    [self setCharacterCountLabel:countLabel];
    [self updateRemainingCharacterCountLabel];
    UIBarButtonItem *countLabelItem = [[UIBarButtonItem alloc] initWithCustomView:countLabel];
    
    UIBarButtonItem *accountButton = [[UIBarButtonItem alloc] initWithTitle:@"account" style:UIBarButtonItemStylePlain target:self action:@selector(accountButtonPressed:)];
    
    UIBarButtonItem *space_1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *space_2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *space_3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *space_4 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [self.navigationItem setLeftBarButtonItems:@[cancelButton, space_1, accountButton, space_2]];
    [self.navigationItem setRightBarButtonItems:@[doneButton, space_3, countLabelItem, space_4]];
    
    [self updateAccountButton];
}

#pragma mark - OSKTextView Delegate

- (void)textViewDidChange:(OSKTextView *)textView {
    [self.contentItem setText:textView.attributedText.string];
    [self updateRemainingCharacterCountLabel];
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
    else if ([self.activity respondsToSelector:@selector(activeManagedAccount)]) {
        OSKManagedAccount *managedAccount = [(OSKActivity <OSKActivity_ManagedAccounts> *)self.activity activeManagedAccount];
        accountName = [managedAccount nonNilDisplayName];
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
    if ([self.activity conformsToProtocol:@protocol(OSKActivity_ManagedAccounts)]) {
        [self showManagedAccountChooser];
    }
    else if ([self.activity conformsToProtocol:@protocol(OSKActivity_SystemAccounts)]) {
        [self showSystemAccountChooser];
    }
}

- (void)showManagedAccountChooser {
    OSKActivity <OSKActivity_ManagedAccounts> *activity = (OSKActivity <OSKActivity_ManagedAccounts> *)self.activity;
    OSKManagedAccount *activeAccount = activity.activeManagedAccount;
    OSKAccountChooserViewController *chooser = [[OSKAccountChooserViewController alloc] initWithManagedAccountActivity:activity activeAccount:activeAccount delegate:self];
    [self.navigationController pushViewController:chooser animated:YES];
}

- (void)showSystemAccountChooser {
    OSKSystemAccountStore *store = [OSKSystemAccountStore sharedInstance];
    OSKActivity <OSKActivity_SystemAccounts> *activity = (OSKActivity <OSKActivity_SystemAccounts> *)self.activity;
    NSArray *accounts = [store accountsForAccountTypeIdentifier:[activity.class systemAccountTypeIdentifier]];
    ACAccount *activeAccount = activity.activeSystemAccount;
    OSKAccountChooserViewController *chooser = [[OSKAccountChooserViewController alloc] initWithSystemAccounts:accounts activeAccount:activeAccount delegate:self];
    [self.navigationController pushViewController:chooser animated:YES];
}

#pragma mark - Character Count

- (void)updateRemainingCharacterCountLabel {
    NSInteger countAdjustingForEmoji = [self.textView.attributedText.string lengthOfBytesUsingEncoding:NSUTF32StringEncoding]/4;
    NSInteger remaining = [self.activity maximumCharacterCount] - countAdjustingForEmoji;
    self.characterCountLabel.text = @(remaining).stringValue;
    if (_characterCount_normalColor == nil) {
        OSKPresentationManager *presManager = [OSKPresentationManager sharedInstance];
        _characterCount_normalColor = presManager.color_characterCounter_normal;
        _characterCount_redColor = presManager.color_characterCounter_warning;
    }
    if (remaining < 0) {
        self.characterCountLabel.textColor = _characterCount_redColor;
    } else {
        self.characterCountLabel.textColor = _characterCount_normalColor;
    }
}

#pragma mark - Button Actions

- (void)cancelButtonPressed:(id)sender {
    [self.oskPublishingDelegate publishingViewControllerDidCancel:self withActivity:self.activity];
}

#pragma mark - Publishing View Controller

- (void)preparePublishingViewForActivity:(OSKActivity *)activity delegate:(id <OSKPublishingViewControllerDelegate>)oskPublishingDelegate {
    [self setActivity:(OSKActivity <OSKMicrobloggingActivity> *)activity];
    [self setContentItem:(OSKMicroblogPostContentItem *)self.activity.contentItem];
    [self setOskPublishingDelegate:oskPublishingDelegate];
    self.title = [self.activity.class activityName];
    [self shortenLinksIfPossible:self.contentItem];
}

#pragma mark - Account Chooser Delegate

- (void)accountChooserDidSelectManagedAccount:(OSKManagedAccount *)managedAccount {
    OSKActivity <OSKActivity_ManagedAccounts> *activity = (OSKActivity <OSKActivity_ManagedAccounts> *)self.activity;
    [activity setActiveManagedAccount:managedAccount];
    [self updateAccountButton];
}

- (void)accountChooserDidSelectSystemAccount:(ACAccount *)systemAccount {
    OSKActivity <OSKActivity_SystemAccounts> *activity = (OSKActivity <OSKActivity_SystemAccounts> *)self.activity;
    [activity setActiveSystemAccount:systemAccount];
    [self updateAccountButton];
}

#pragma mark - Link Shortening

- (void)shortenLinksIfPossible:(OSKMicroblogPostContentItem *)item {
    NSAssert(self.hasAttemptedURLShortening == NO, @"shortenLinksIfPossible: cannot be called more than once per editing session.");
    BOOL isAllowed = [[OSKPresentationManager sharedInstance] automaticallyShortenURLsWhenRecommended];
    if (self.contentItem.text.length > 0 && isAllowed) {
        [self setHasAttemptedURLShortening:YES];
        NSArray *urls = [OSKTwitterText URLsInText:item.text];
        if (urls.count) {
            __weak OSKMicroblogPublishingViewController *weakSelf = self;
            for (OSKTwitterTextEntity *URLEntity in urls) {
                NSString *longURL = [item.text substringWithRange:URLEntity.range];
                if ([OSKLinkShorteningUtility shorteningRecommended:longURL]) {
                    [OSKLinkShorteningUtility shortenURL:longURL completion:^(NSString *shortURL) {
                        if (item == weakSelf.contentItem && shortURL.length) {
                            NSMutableString *textViewText = weakSelf.contentItem.text.mutableCopy;
                            NSRange rangeOfLongURL = [textViewText rangeOfString:longURL];
                            if (rangeOfLongURL.length) {
                                [textViewText replaceCharactersInRange:rangeOfLongURL withString:shortURL];
                                [weakSelf.textView setText:textViewText];
                                [weakSelf.contentItem setText:textViewText];
                                [weakSelf updateRemainingCharacterCountLabel];
                                [weakSelf updateDoneButton];
                            }
                        }
                    }];
                }
            }
        }
    }
}

@end




