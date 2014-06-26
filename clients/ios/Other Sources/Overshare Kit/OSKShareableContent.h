//
//  OSKShareableContent.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@class OSKFacebookContentItem;
@class OSKMicroblogPostContentItem;
@class OSKBlogPostContentItem;
@class OSKEmailContentItem;
@class OSKSMSContentItem;
@class OSKPhotoSharingContentItem;
@class OSKCopyToPasteboardContentItem;
@class OSKReadLaterContentItem;
@class OSKLinkBookmarkContentItem;
@class OSKWebBrowserContentItem;
@class OSKToDoListEntryContentItem;
@class OSKPasswordManagementAppSearchContentItem;
@class OSKAirDropContentItem;
@class OSKTextEditingContentItem;

/**
 `OSKShareableContent` is the highest-level Overshare Kit model object for
 passing around shareable user content (duh).

 @discussion `OSKShareableContent's` sole purpose is to bristle with subclasses of `OSKShareableContentItem`.

 `OSKShareableContent` represents the user's data in a structured,
 readable, portable way. Because each kind of OSKActivity requires different
 bits of data and metadata, there is an `OSKShareableContentItem`
 for each conceivable type of activity.
 
 Think of `OSKShareableContentItem` like UINavigationItems or UITabBarItems.
 Navigation controllers and tab bar controllers use those items to keep title
 and toolbar item changes in sync with child view controller changes. It’s a
 convenient paradigm that is useful for our purposes, too.
 
 All of these `OSKShareableContentItem` properties are nil by default. For each kind of
 content you wish to support, alloc/init an item of the corresponding class,
 populate it’s unique properties, and set it as the appropriate
 item listed below. You can also use one of the convenience class constructors.
 
 Remember that `OSKShareableContentItem` represents *content*, not activities or services.
 Thus, you will only need one `microblogPostItem`, for example, since all the
 microblogging activities (`OSKTwitterActivity`, `OSKFacebookActivity`, `OSKAppDotNetActivity`,
 etc.) are designed to handle the same `<OSKMicroblogPostContentItem>`.

 If you need multiple instances of the same kind of content, you can alloc/init additional
 `OSKShareableContentItems` and set them as the `additionalItems` array. This is helpful for
 for cases such as showing a "Copy Text" and "Copy URL" in the same activity sheet.

 @see OSKShareableContentItem.h
 */
@interface OSKShareableContent : NSObject

/**
 Content patterned after Facebook posts.
 */
@property (strong, nonatomic) OSKFacebookContentItem *facebookItem;

/**
 Content patterned after microblog posts like Twitter or App.net updates.
*/
@property (strong, nonatomic) OSKMicroblogPostContentItem *microblogPostItem;

/**
 Content patterned after long-form blog posts like Tumblr or WordPress posts.
*/
@property (strong, nonatomic) OSKBlogPostContentItem *blogPostItem;

/**
 Content patterned after email messages.
 */
@property (strong, nonatomic) OSKEmailContentItem *emailItem;

/**
 Content patterned after SMS / iMessage updates.
 */
@property (strong, nonatomic) OSKSMSContentItem *smsItem;

/**
 Content patterned after photosharing services like Instagram or 500PX.
 */
@property (strong, nonatomic) OSKPhotoSharingContentItem *photoSharingItem;

/**
 Content for pasteboard clippings.
 */
@property (strong, nonatomic) OSKCopyToPasteboardContentItem *pasteboardItem;

/**
 Content for sending to read-later services like Instapaper or Pocket.
 */
@property (strong, nonatomic) OSKReadLaterContentItem *readLaterItem;

/**
 Content for sending to link-bookmarking services like Pinboard.
 */
@property (strong, nonatomic) OSKLinkBookmarkContentItem *linkBookmarkItem;

/**
 Content for creating to-do-list entries in other apps like OmniFocus or Things.
 */
@property (strong, nonatomic) OSKToDoListEntryContentItem *toDoListItem;

/**
 Content for opening a link in another app's web browser, like Safari or Chrome.
 */
@property (strong, nonatomic) OSKWebBrowserContentItem *webBrowserItem;

/**
 Content for searching a password storage app, like 1Password.
 */
@property (strong, nonatomic) OSKPasswordManagementAppSearchContentItem *passwordSearchItem;

/**
 Content shareable via AirDrop.
 */
@property (strong, nonatomic) OSKAirDropContentItem *airDropItem;

/**
 Content for text editing apps and services, like Drafts or Evernote.
 */
@property (strong, nonatomic) OSKTextEditingContentItem *textEditingItem;

/**
These can be custom items, or additional instances of the official items above.
*/
@property (strong, nonatomic) NSArray * additionalItems;

/**
 This title is used by Overshare Kit as the title for the activity sheet.
*/
@property (copy, nonatomic) NSString *title;

@end

/// -----------------------------------------
/// @name Convenient Constructors
/// -----------------------------------------

@interface OSKShareableContent (Convenience)

/**
 Convenient constructor for plain-text content.
*/
+ (instancetype)contentFromText:(NSString *)text;

/**
 Convenient constructor for sharing a link.
 */
+ (instancetype)contentFromURL:(NSURL *)url;

/**
 Convenient constructor for content drawn from microblog posts (like Twitter or App.net).
 */
+ (instancetype)contentFromMicroblogPost:(NSString *)text
                              authorName:(NSString *)authorName
                            canonicalURL:(NSString *)canonicalURL
                                  images:(NSArray *)images;

/**
 Convenient constructor for sharing one or more images with a common caption.
 */
+ (instancetype)contentFromImages:(NSArray *)images
                          caption:(NSString *)caption;

@end






