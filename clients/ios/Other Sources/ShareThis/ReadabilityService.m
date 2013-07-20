/* Copyright 2012 IGN Entertainment, Inc. */

#import "ReadabilityService.h"
#import "GCOAuth.h"
#import "ShareThis.h"
#import "NewsBlurAppDelegate.h"
#import "StoryPageControl.h"

const int LOGIN_SUCCESS = 200;
const int BOOKMARK_SUCCESS = 202;
const int DUPLICATE_BOOKMARK = 409;
const int AUTHORIZATION_REQUIRED = 401;
const int BAD_REQUEST = 400;

NSString *const ReadabilityIdentifier =
@"ReadabilityAccess";
NSString *const ReadabilityActivity =
@"ReadabilityActivity";

static ReadabilityService *_manager;

#define readabilityAccessTokenUrl @"/api/rest/v1/oauth/access_token/"
#define readabilityBookmarkUrl @"/api/rest/v1/bookmarks"

@interface ReadabilityService()
@property (strong, nonatomic) NSString *username;
@property (strong, nonatomic) NSMutableData *receivedData;
@property (nonatomic) BOOL loggingIn;
@end

@implementation ReadabilityService

+ (ReadabilityService *)sharedManager
{
    if (!_manager) {
        _manager = [[ReadabilityService alloc] init];
    }
    return _manager;
}

+ (void)shareWithParams:(NSDictionary *)params onViewController:(UIViewController *)viewController
{
    [[ReadabilityService sharedManager] performReadLaterServiceWithParams:params];
}

- (void)setParams:(NSDictionary *)params
{
    // Set the url and title from the passed in parameters
    if (params) {
        self.url = [[params objectForKey:@"url"] absoluteString];
        self.articleTitle = [[params objectForKey:@"title"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
}

- (void)performReadLaterServiceWithParams:(NSDictionary *)params
{
    self.receivedData = [NSMutableData data];
    self.params = params;
    self.loggingIn = NO;
    KeychainItemWrapper *keychain =
        [[KeychainItemWrapper alloc] initWithIdentifier:ReadabilityIdentifier accessGroup:nil];
    
    [self performAlertViewUsingKeychain:keychain];
}

#pragma mark Login Service
// Perform login action for the given service
- (void)loginWithUsername:(NSString *)username password:(NSString *)password
{
    self.username = username;
    NSURLRequest *xauth = [GCOAuth URLRequestForPath:readabilityAccessTokenUrl
                                      POSTParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      username, @"x_auth_username",
                                                      password, @"x_auth_password",
                                                      @"client_auth", @"x_auth_mode", nil]
                                                host:@"www.readability.com"
                                         consumerKey:[[ShareThis sharedManager] readabilityKey]
                                      consumerSecret:[[ShareThis sharedManager] readabilitySecret]
                                         accessToken:nil
                                         tokenSecret:nil];
    
    [self performConnectionWithRequest:xauth];
}

#pragma mark Log out service
// Log out by deleting the keychain item in the keychain
- (void)logOutOfService
{
    KeychainItemWrapper *keychain =
        [[KeychainItemWrapper alloc] initWithIdentifier:ReadabilityIdentifier accessGroup:nil];
    
    [keychain resetKeychainItem];
}

#pragma mark Post to service
// Post the url and title to the given service using the login credentials
- (void)postToService
{
   
    KeychainItemWrapper *keychain =
        [[KeychainItemWrapper alloc] initWithIdentifier:ReadabilityIdentifier accessGroup:nil];
    
    NSURLRequest *xauth = [GCOAuth URLRequestForPath:readabilityBookmarkUrl
                                      POSTParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      @"application/x-www-form-urlencoded", @"Content-Type",
                                                      self.url, @"url",
                                                      nil]
                                                host:@"www.readability.com"
                                         consumerKey:@"mobileignqa"
                                      consumerSecret:@"kPUFsLMEvj2etXhnMUkRPBPyy4G4bG4g"
                                         accessToken:[keychain objectForKey:(__bridge id)kSecAttrService]
                                         tokenSecret:[keychain objectForKey:(__bridge id)kSecValueData]];
    
    [self performConnectionWithRequest:xauth];

}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (!self.receivedData) {
        self.receivedData = [NSMutableData data];
    }
    
    [self.receivedData appendData:data];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // Only time it needs to set the keychain is after receiving the data from logging in
    if (self.receivedData && self.loggingIn) {
        self.loggingIn = NO;
        NSString *jsonString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];

        KeychainItemWrapper *keychain =
            [[KeychainItemWrapper alloc] initWithIdentifier:ReadabilityIdentifier accessGroup:nil];
        
        NSArray *tokens = [jsonString componentsSeparatedByString: @"&"];
        for (NSString *string in tokens) {
            if ([string rangeOfString:@"oauth_token_secret=" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                
                NSString *token_secret = [string substringFromIndex:[@"oauth_token_secret=" length]];
                NSLog(@"token_secret = %@", token_secret);
                [keychain setObject:token_secret forKey:(__bridge id)kSecValueData];
                
            } else if ([string rangeOfString:@"oauth_token=" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                
                NSString *token = [string substringFromIndex:[@"oauth_token=" length]];
                NSLog(@"token = %@", token);

                [keychain setObject:token forKey:(__bridge id)kSecAttrService];
                
            }
        }
        
        [keychain setObject:self.username forKey:(__bridge id)kSecAttrAccount];

        [self postToService];
    }
}

// Handle the status code given from the response in a nsurlconnection
- (void)handleStatusCode
{
//    KeychainItemWrapper *keychain =
//        [[KeychainItemWrapper alloc] initWithIdentifier:ReadabilityIdentifier accessGroup:nil];

    switch (self.statusCode) {
        case LOGIN_SUCCESS:
            self.loggingIn = YES;
            break;
        case BOOKMARK_SUCCESS:
            [self showPostConfirmation];
            break;
        case DUPLICATE_BOOKMARK:
            [self showAlertMessageWithTitle:@"Error" Message:@"Bookmark already exists!"];
            break;
        case AUTHORIZATION_REQUIRED:
            [self showAlertMessageWithTitle:@"Error" Message:@"Invalid Username or Password"];
            break;
        case BAD_REQUEST:
            [self showAlertMessageWithTitle:@"Error" Message:@"Service encountered an error. Please try again later."];
            break;
        default:
            break;
    }
}

@end
