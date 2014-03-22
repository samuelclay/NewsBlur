//
//  GPPSignIn.h
//  Google+ iOS SDK
//
//  Copyright 2012 Google Inc.
//
//  Use of this SDK is subject to the Google+ Platform Terms of Service:
//  https://developers.google.com/+/terms
//

#import <Foundation/Foundation.h>

@class GTLPlusPerson;
@class GTLServicePlus;
@class GTMOAuth2Authentication;

// A protocol implemented by the client of |GPPSignIn| to receive a refresh
// token or an error.
@protocol GPPSignInDelegate

// The authorization has finished and is successful if |error| is |nil|.
- (void)finishedWithAuth:(GTMOAuth2Authentication *)auth
                   error:(NSError *)error;

// Finished disconnecting user from the app.
// The operation was successful if |error| is |nil|.
@optional
- (void)didDisconnectWithError:(NSError *)error;

@end

// This class signs the user in with Google. It provides single sign-on
// via the Google+ app (if installed), Chrome for iOS (if installed), or Mobile
// Safari.
//
// For reference, please see "Google+ Sign-In for iOS" at
// https://developers.google.com/+/mobile/ios/sign-in .
// Here is sample code to use |GPPSignIn|:
//   1) Get a reference to the |GPPSignIn| shared instance:
//      GPPSignIn *signIn = [GPPSignIn sharedInstance];
//   2) Set the OAuth 2.0 scopes you want to request:
//      [signIn setScopes:[NSArray arrayWithObject:
//          @"https://www.googleapis.com/auth/plus.login"]];
//   2) Call [signIn setDelegate:self];
//   3) Set up delegate method |finishedWithAuth:error:|.
//   4) Call |handleURL| on the shared instance from |application:openUrl:...|
//      in your app delegate.
//   5) Call [signIn authenticate];
@interface GPPSignIn : NSObject

// The authentication object for the current user, or |nil| if there is
// currently no logged in user.
@property(nonatomic, strong, readonly) GTMOAuth2Authentication *authentication;

// A JSON Web Token identifying the user. Send this token to your server to
// authenticate the user on the server. For more information on JWTs, see
// http://tools.ietf.org/html/draft-ietf-oauth-json-web-token-05
@property(nonatomic, strong, readonly) NSString *idToken;

// The Google user ID. It is only available if |shouldFetchGoogleUserID| is set
// and either |trySilentAuthentication| or |authenticate| has been completed
// successfully.
@property(nonatomic, strong, readonly) NSString *userID;

// The Google user's email. It is only available if |shouldFetchGoogleUserEmail|
// is set and either |trySilentAuthentication| or |authenticate| has been
// completed successfully.
@property(nonatomic, strong, readonly) NSString *userEmail;

// The Google+ user profile. It is only available if |shouldFetchGooglePlusUser|
// is set and either |trySilentAuthentication| or |authenticate| has been
// completed successfully.
@property(nonatomic, strong, readonly) GTLPlusPerson *googlePlusUser;

// The object to be notified when authentication is finished.
@property(nonatomic, weak) id<GPPSignInDelegate> delegate;

// All properties below are optional parameters. If they need to be set, set
// before calling |authenticate|.

// The client ID of the app from the Google APIs console.
// Must set for sign-in to work.
@property(nonatomic, copy) NSString *clientID;

// The client ID of the home web server.  This will be returned as the
// |audience| property of the JWT ID token.  For more info on the ID token:
// https://developers.google.com/accounts/docs/OAuth2Login#obtainuserinfo
@property(nonatomic, copy) NSString *homeServerClientID;

// The OpenID2 realm of the home web server. This allows Google to include
// the user's OpenID Identifier in the JWT ID token.
@property(nonatomic, copy) NSString *openIDRealm;

// The API scopes requested by the app in an array of |NSString|s.
// The default value is |@[@"https://www.googleapis.com/auth/plus.login"]|.
@property(nonatomic, copy) NSArray *scopes;

// Whether or not to attempt Single-Sign-On when signing in.
// If |attemptSSO| is true, the sign-in button tries to authenticate with the
// Google+ application if it is installed. If false, it always uses Google+ via
// Chrome for iOS, if installed, or Mobile Safari for authentication.
// The default value is |YES|.
@property(nonatomic, assign) BOOL attemptSSO;

// The language for sign-in, in the form of ISO 639-1 language code
// optionally followed by a dash and ISO 3166-1 alpha-2 region code,
// such as |@"it"| or |@"pt-PT"|.
// Only set if different from system default.
@property(nonatomic, copy) NSString *language;

// Name of the keychain to save the sign-in state.
// Only set if a custom name needs to be used.
@property(nonatomic, copy) NSString *keychainName;

// An |NSString| array of moment types used by your app. Use values from the
// full list at
// https://developers.google.com/+/api/moment-types .
// such as "http://schemas.google.com/AddActivity".
// This property is required only for writing moments, with
// "https://www.googleapis.com/auth/plus.login" as a scope.
@property(nonatomic, copy) NSArray *actions;

// Whether or not to fetch user email after signing in. The email is saved in
// the |GTMOAuth2Authentication| object. Note that using this flag automatically
// adds "https://www.googleapis.com/auth/userinfo.email" scope to the request.
@property(nonatomic, assign) BOOL shouldFetchGoogleUserEmail;

// Whether or not to fetch user ID after signing in. The ID can be retrieved
// by |googleUserID| after user has been authenticated. Note that using this
// flag automatically adds "https://www.googleapis.com/auth/userinfo.profile"
// scope to the request if a scope that provides user ID is not already present.
@property(nonatomic, assign) BOOL shouldFetchGoogleUserID;

// Whether or not to fetch Google+ user profile after signing in. The user
// profile object can be retrieved by |googlePlusUser| after user has been
// authenticated. Note that using this flag automatically adds
// "https://www.googleapis.com/auth/plus.me" scope to the request if needed.
@property(nonatomic, assign) BOOL shouldFetchGooglePlusUser;

// Returns a shared |GPPSignIn| instance.
+ (GPPSignIn *)sharedInstance;

// Checks whether the user has either currently signed in or has previous
// authentication saved in keychain.
- (BOOL)hasAuthInKeychain;

// Attempts to authenticate silently without user interaction.
// Returns |YES| and calls the delegate if the user has either currently signed
// in or has previous authentication saved in keychain.
// Note that if the previous authentication was revoked by the user, this method
// still returns |YES| but |finishedWithAuth:error:| callback will indicate
// that authentication has failed.
- (BOOL)trySilentAuthentication;

// Starts the authentication process. Set |attemptSSO| to try single sign-on.
// If |attemptSSO| is true, try to authenticate with the Google+ app, if
// installed. If false, always use Google+ via Chrome or Mobile Safari for
// authentication. The delegate will be called at the end of this process.
// Note that this method should not be called when the app is starting up,
// (e.g in application:didFinishLaunchingWithOptions:). Instead use the
// |trySilentAuthentication| method.
- (void)authenticate;

// This method should be called from your |UIApplicationDelegate|'s
// |application:openURL:sourceApplication:annotation|. Returns |YES| if
// |GPPSignIn| handled this URL.
// Also see |handleURL:sourceApplication:annotation:| in |GPPURLHandler|.
- (BOOL)handleURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
           annotation:(id)annotation;

// Removes the OAuth 2.0 token from the keychain.
- (void)signOut;

// Disconnects the user from the app and revokes previous authentication.
// If the operation succeeds, the OAuth 2.0 token is also removed from keychain.
// The token is needed to disconnect so do not call |signOut| if |disconnect| is
// to be called.
- (void)disconnect;

// Gets a service object authenticated as the current user. The service object
// can execute queries, for example, to get list of people that is visible to
// this app. The user must be signed in for this method to work.
- (GTLServicePlus *)plusService;

@end
