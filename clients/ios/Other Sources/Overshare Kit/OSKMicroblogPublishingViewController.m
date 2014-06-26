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
#import "OSKMicrobloggingTextView.h"
#import "OSKManagedAccount.h"
#import "OSKAccountChooserViewController.h"
#import "UIImage+OSKUtilities.h"
#import "OSKLinkShorteningUtility.h"
#import "OSKTwitterText.h"

@interface OSKMicroblogPublishingViewController ()
<
    OSKUITextViewSubstituteDelegate,
    OSKMicrobloggingTextViewAttachmentsDelegate,
    OSKAccountChooserViewControllerDelegate
>

@property (weak, nonatomic) IBOutlet OSKMicrobloggingTextView *textView;

@property (strong, nonatomic) OSKActivity <OSKMicrobloggingActivity> *activity;
@property (strong, nonatomic) OSKMicroblogPostContentItem *contentItem;
@property (strong, nonatomic) UIView *keyboardToolbar;
@property (strong, nonatomic) UILabel *characterCountLabel;
@property (strong, nonatomic) UIColor *characterCount_redColor;
@property (strong, nonatomic) UIColor *characterCount_normalColor;
@property (strong, nonatomic) UIButton *accountButton; // Used on iPhone
@property (assign, nonatomic) BOOL shouldShowLinkShorteningButton;
@property (strong, nonatomic) NSMutableSet *shortenedLinks;
@property (strong, nonatomic) UIBarButtonItem *cancelItem;
@property (strong, nonatomic) UIBarButtonItem *doneItem;
@property (strong, nonatomic) UIBarButtonItem *characterCountItem; // iPad only
@property (strong, nonatomic) UIBarButtonItem *accountItem; // iPad only
@property (strong, nonatomic) UIBarButtonItem *leftSpaceItemA;
@property (strong, nonatomic) UIBarButtonItem *leftSpaceItemB; // iPad only
@property (strong, nonatomic) UIBarButtonItem *rightSpaceItemA;
@property (strong, nonatomic) UIBarButtonItem *rightSpaceItemB;
@property (strong, nonatomic) UIBarButtonItem *rightSpaceItemC;
@property (strong, nonatomic) UIBarButtonItem *linkShorteningItem;
@property (strong, nonatomic) UIButton *linkShorteningButton;
@property (strong, nonatomic) UIActivityIndicatorView *linkShorteningActivityIndicator;
@property (assign, nonatomic) NSInteger activeLinkShorteningCount;

@end

#define NUM_ROWS 1
#define ROW_TEXT_VIEW 0
#define ROW_ACTIVE_ACCOUNT 1
#define TOOLBAR_FONT_SIZE 17

#define CANCEL_ITEM_INDEX_IPAD 0
#define ACCOUNT_ITEM_INDEX_IPAD 2
#define DONE_ITEM_INDEX_IPAD 0
#define CHARACTER_COUNT_ITEM_INDEX_IPAD 2

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
    [self updateDoneButton];
}

- (void)setupTextView {
    [self.textView setOskDelegate:self];
    [self.textView setOskAttachmentsDelegate:self];
    [self.textView setSyntaxHighlighting:[self.activity syntaxHighlighting]];
    [self.textView setText:self.contentItem.text];
    
    [self updateRemainingCharacterCountLabel];
    [self updateDoneButton];
    [self updateLinkShorteningButton];
    
    NSUInteger numberOfImages = self.contentItem.images.count;
    if (numberOfImages > 0) {
        NSUInteger numberOfImagesToShow = MIN(MIN([self.activity maximumImageCount], 3), numberOfImages);
        NSArray *imagesToShow = [self.contentItem.images subarrayWithRange:NSMakeRange(0, numberOfImagesToShow)];
        OSKTextViewAttachment *attachment = [[OSKTextViewAttachment alloc] initWithImages:imagesToShow];
        [self.textView setOskAttachment:attachment];
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
    _cancelItem = [[UIBarButtonItem alloc] initWithTitle:cancelTitle style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed:)];
    self.navigationItem.leftBarButtonItems = @[_cancelItem];
    
    NSString *doneTitle = [[OSKPresentationManager sharedInstance] localizedText_ActionButtonTitleForPublishingActivity:[self.activity.class activityType]];
    _doneItem = [[UIBarButtonItem alloc] initWithTitle:doneTitle style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonPressed:)];
    self.navigationItem.rightBarButtonItems = @[_doneItem];
}

- (void)setupNavigationItems_Pad {
    NSString *cancelTitle = [[OSKPresentationManager sharedInstance] localizedText_Cancel];
    _cancelItem = [[UIBarButtonItem alloc] initWithTitle:cancelTitle style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed:)];
    
    NSString *doneTitle = [[OSKPresentationManager sharedInstance] localizedText_ActionButtonTitleForPublishingActivity:[self.activity.class activityType]];
    _doneItem = [[UIBarButtonItem alloc] initWithTitle:doneTitle style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonPressed:)];
    
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
    _characterCountItem = [[UIBarButtonItem alloc] initWithCustomView:countLabel];
    
    _accountItem = [[UIBarButtonItem alloc] initWithTitle:@"account" style:UIBarButtonItemStylePlain target:self action:@selector(accountButtonPressed:)];
    
    _leftSpaceItemA = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    _leftSpaceItemB = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    _rightSpaceItemA = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    _rightSpaceItemB = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    [self.navigationItem setLeftBarButtonItems:@[_cancelItem, _leftSpaceItemA, _accountItem, _leftSpaceItemB]];
    [self.navigationItem setRightBarButtonItems:@[_doneItem, _rightSpaceItemA, _characterCountItem, _rightSpaceItemB]];
    
    [self updateAccountButton];
}

#pragma mark - OSKUITextViewSubstituteDelegate

- (void)textViewDidChange:(OSKUITextViewSubstitute *)textView {
    [self.contentItem setText:textView.attributedText.string];
    [self updateRemainingCharacterCountLabel];
    [self updateDoneButton];
    [self updateLinkShorteningButton];
}

#pragma mark - OSKTextViewAttachmentsDelegate

- (BOOL)textView:(OSKMicrobloggingTextView *)textView shouldAllowAttachmentsToBeEdited:(OSKTextViewAttachment *)attachment {
    return YES;
}

- (void)textViewDidTapRemoveAttachment:(OSKMicrobloggingTextView *)textView {
    [textView removeAttachment];
    [self.contentItem setImages:nil];
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
    
    UIEdgeInsets indicatorInsets = self.textView.scrollIndicatorInsets;
    indicatorInsets.top = [self.topLayoutGuide length];
    [self.textView setScrollIndicatorInsets:indicatorInsets];
}

#pragma mark - Done Button

- (void)updateDoneButton {
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        [self.navigationItem.rightBarButtonItems[DONE_ITEM_INDEX_IPAD] setEnabled:[self.activity isReadyToPerform]];
    } else {
        [self.navigationItem.rightBarButtonItem setEnabled:[self.activity isReadyToPerform]];
    }
}

- (void)doneButtonPressed:(id)sender {
    if ([self.activity isReadyToPerform]) {
        [self.oskPublishingDelegate publishingViewController:self didTapPublishActivity:self.activity];
    }
}

#pragma mark - Link Shortening Button

- (void)updateLinkShorteningButton {
    BOOL presManagerAllows = [OSKPresentationManager sharedInstance].allowLinkShorteningButton;
    BOOL activityAllows = YES;
    if ([self.activity respondsToSelector:@selector(allowLinkShortening)]) {
        activityAllows = [self.activity allowLinkShortening];
    }
    if (presManagerAllows && activityAllows) {
        NSArray *links = _textView.detectedLinks;
        BOOL shouldShow = NO;
        for (OSKTwitterTextEntity *link in links) {
            NSString *urlString = [self.contentItem.text substringWithRange:link.range];
            if ([OSKLinkShorteningUtility shorteningRecommended:urlString]) {
                shouldShow = YES;
                break;
            }
        }
        [self setShouldShowLinkShorteningButton:shouldShow];
    } else {
        [self setShouldShowLinkShorteningButton:NO];
    }
}

- (void)setShouldShowLinkShorteningButton:(BOOL)shouldShowLinkShorteningButton {
    if (_shouldShowLinkShorteningButton != shouldShowLinkShorteningButton) {
        _shouldShowLinkShorteningButton = shouldShowLinkShorteningButton;
        [self setupLinkShorteningBarButtonItemSpaces];
        if (_shouldShowLinkShorteningButton) {
            [self setupLinkShorteningBarButtonItem];
            if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
                [self.navigationItem setRightBarButtonItems:@[_doneItem, _rightSpaceItemA, _characterCountItem,
                                                              _rightSpaceItemB, _linkShorteningItem, _rightSpaceItemC]];
            } else {
                [self.navigationItem setRightBarButtonItems:@[_doneItem, _rightSpaceItemB, _linkShorteningItem, _rightSpaceItemC]];
                [self.navigationItem setLeftBarButtonItems:@[_cancelItem, _leftSpaceItemA]];
            }
        }
        else {
            if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
                [self.navigationItem setRightBarButtonItems:@[_doneItem, _rightSpaceItemA, _characterCountItem, _rightSpaceItemB]];
            } else {
                [self.navigationItem setRightBarButtonItems:@[_doneItem]];
                [self.navigationItem setLeftBarButtonItems:@[_cancelItem]];
            }
        }
    }
}

- (void)setupLinkShorteningBarButtonItem {
    if (_linkShorteningItem == nil) {
        UIImage *linkButtonImage = [[UIImage imageNamed:@"link-button.png"]
                                    imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _linkShorteningButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_linkShorteningButton setAccessibilityLabel:[OSKPresentationManager sharedInstance].localizedText_ShortenLinks];
        [_linkShorteningButton setFrame:CGRectMake(0, 0, 44.0f, 30.0f)];
        [_linkShorteningButton setImage:linkButtonImage forState:UIControlStateNormal];
        [_linkShorteningButton addTarget:self
                                  action:@selector(shortenLinkButtonTapped:)
                        forControlEvents:UIControlEventTouchUpInside];
        
        UIView *buttonContainerView = [[UIView alloc] initWithFrame:_linkShorteningButton.bounds];
        [buttonContainerView addSubview:_linkShorteningButton];
        
        UIActivityIndicatorViewStyle style = (self.navigationController.navigationBar.barStyle == UIBarStyleBlack)
        ? UIActivityIndicatorViewStyleWhite
        : UIActivityIndicatorViewStyleGray;
        _linkShorteningActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:style];
        _linkShorteningActivityIndicator.hidesWhenStopped = YES;
        _linkShorteningActivityIndicator.center = _linkShorteningButton.center;
        [buttonContainerView addSubview:_linkShorteningActivityIndicator];
        
        _linkShorteningItem = [[UIBarButtonItem alloc]
                               initWithCustomView:buttonContainerView];
    }
}

- (void)setupLinkShorteningBarButtonItemSpaces {
    if (_rightSpaceItemC == nil) {
        _rightSpaceItemC = [[UIBarButtonItem alloc]
                            initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                            target:nil
                            action:nil];
    }
    if (_rightSpaceItemB == nil) {
        _rightSpaceItemB = [[UIBarButtonItem alloc]
                            initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                            target:nil
                            action:nil];
    }
    if (_leftSpaceItemA == nil) {
        _leftSpaceItemA = [[UIBarButtonItem alloc]
                            initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                            target:nil
                            action:nil];
    }
}

- (void)shortenLinkButtonTapped:(id)sender {
    
    if (_textView.detectedLinks.count) {
        
        for (OSKTwitterTextEntity *URLEntity in _textView.detectedLinks) {
            
            NSString *longURL = [self.contentItem.text substringWithRange:URLEntity.range];
            
            if ([OSKLinkShorteningUtility shorteningRecommended:longURL] && [self.shortenedLinks containsObject:longURL] == NO) {
                
                __weak OSKMicroblogPostContentItem *item = self.contentItem;
                __weak OSKMicroblogPublishingViewController *weakSelf = self;

                [self pushLinkShorteningActivity];
                [OSKLinkShorteningUtility shortenURL:longURL completion:^(NSString *shortURL) {
                    [weakSelf popLinkShorteningActivity];
                    if (item == weakSelf.contentItem && shortURL.length) {
                        NSMutableString *textViewText = weakSelf.contentItem.text.mutableCopy;
                        NSRange rangeOfLongURL = [textViewText rangeOfString:longURL];
                        if (rangeOfLongURL.length) {
                            [textViewText replaceCharactersInRange:rangeOfLongURL withString:shortURL];
                            if (weakSelf.shortenedLinks == nil) {
                                weakSelf.shortenedLinks = [NSMutableSet set];
                            }
                            [weakSelf.shortenedLinks addObject:shortURL];
                            [weakSelf.textView setText:textViewText];
                            [weakSelf.contentItem setText:textViewText];
                            [weakSelf updateRemainingCharacterCountLabel];
                            [weakSelf updateDoneButton];
                            [weakSelf updateLinkShorteningButton];
                        }
                    }
                }];
            }
        }
    }
}

- (void)pushLinkShorteningActivity {
    _activeLinkShorteningCount++;
    if (_activeLinkShorteningCount > 0) {
        [_linkShorteningActivityIndicator startAnimating];
        __weak OSKMicroblogPublishingViewController *weakSelf = self;
        [UIView animateWithDuration:0.12f delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            [weakSelf.linkShorteningButton setAlpha:0];
        } completion:nil];
    }
}

- (void)popLinkShorteningActivity {
    if (_activeLinkShorteningCount > 0) {
        _activeLinkShorteningCount--;
        if (_activeLinkShorteningCount <= 0) {
            [_linkShorteningActivityIndicator stopAnimating];
            __weak OSKMicroblogPublishingViewController *weakSelf = self;
            [UIView animateWithDuration:0.12f delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                [weakSelf.linkShorteningButton setAlpha:1];
                UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, [OSKPresentationManager sharedInstance].localizedText_LinksShortened);
            } completion:nil];
        }
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
    
    if (accountName == nil) {
        accountName = @"– – –";
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self updateAccountButton_Phone:accountName];
    } else {
        [self updateAccountButton_Pad:accountName];
    }
}

- (void)updateAccountButton_Phone:(NSString *)accountName {
    [self.accountButton setTitle:accountName forState:UIControlStateNormal];
    CGSize newSize = [self.accountButton sizeThatFits:self.keyboardToolbar.bounds.size];
    CGRect buttonFrame = self.accountButton.frame;
    buttonFrame.size.width = newSize.width;
    [self.accountButton setFrame:buttonFrame];
}

- (void)updateAccountButton_Pad:(NSString *)accountName {
    UIBarButtonItem *item = self.navigationItem.leftBarButtonItems[ACCOUNT_ITEM_INDEX_IPAD];
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

#pragma mark - Character Count

- (void)updateRemainingCharacterCountLabel {
    
    NSInteger remaining = [self.activity updateRemainingCharacterCount:self.contentItem urlEntities:self.textView.detectedLinks];;
    
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
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        CGSize size = [self.characterCountLabel sizeThatFits:CGSizeMake(160.0f, 44.0)];
        CGRect characterCountRect = self.characterCountLabel.frame;
        characterCountRect.size.width = size.width;
        self.characterCountLabel.frame = characterCountRect;
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

@end




