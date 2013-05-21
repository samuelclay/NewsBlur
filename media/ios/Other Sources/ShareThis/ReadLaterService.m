/* Copyright 2012 IGN Entertainment, Inc. */

#import "ReadLaterService.h"

const int LOGIN_ALERT_TAG = 1001;
const int POST_ALERT_TAG = 1002;

@interface ReadLaterService ()
@property (strong, nonatomic) NSURLConnection *readLaterConnection;
@end

@implementation ReadLaterService

- (void)setParams:(NSDictionary *)params
{
    // Set the url and title from the passed in parameters
    if (params) {
        self.url = [[params objectForKey:@"url"] absoluteString];
        self.articleTitle = [[params objectForKey:@"title"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
}

#pragma mark AlertView methods
- (void)performAlertViewUsingKeychain:(KeychainItemWrapper *)keychain
{
    UIAlertView *alert;
    // Show either a logout/post screen if an account is in key chain or else show login message box
    if (![[keychain objectForKey:(__bridge id)kSecAttrAccount] isEqualToString:@""] && [keychain objectForKey:(__bridge id)kSecValueData]) {
        alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Logged in as %@", [keychain objectForKey:(__bridge id)kSecAttrAccount]]
                                           message:nil
                                          delegate:self
                                 cancelButtonTitle:@"Cancel"
                                 otherButtonTitles:@"Add to read later", @"Log Out", nil];
        
        alert.tag = POST_ALERT_TAG;
    } else {
        alert = [[UIAlertView alloc] initWithTitle:@"Login"
                                           message:nil
                                          delegate:self
                                 cancelButtonTitle:@"Cancel"
                                 otherButtonTitles:@"Login", nil];
        
        alert.tag = LOGIN_ALERT_TAG;
        alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
    }
    
    [alert show];
}

// Show the alert message with the given title and message
- (void)showAlertMessageWithTitle:(NSString *)alertTitle Message:(NSString *)message
{
    UIAlertView *alertView = alertView = [[UIAlertView alloc] initWithTitle:alertTitle
                                                                    message:message
                                                                   delegate:self
                                                          cancelButtonTitle:@"Okay"
                                                          otherButtonTitles:nil];
    [alertView show];
}

#pragma mark AlertView Delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{    
    switch (alertView.tag) {
        case LOGIN_ALERT_TAG:
            if (buttonIndex == 1) {
                [self loginWithUsername:[[alertView textFieldAtIndex:0] text] password:[[alertView textFieldAtIndex:1] text]];
            }
            break;
        case POST_ALERT_TAG:
            switch (buttonIndex) {
                case 0:
                    break;
                case 1:
                    [self postToService];
                    break;
                case 2:
                    [self logOutOfService];
                    break;
                default:
                    break;
            }
            break;
        default:
            break;
    }
}

#pragma mark NSURLConnection Delegates
// A status code response will be return which will then be use to check for validation
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    self.statusCode = [httpResponse statusCode];
    [self handleStatusCode];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    self.readLaterConnection = nil;
}

- (void)dealloc
{
    // Made sure there's no connections left open
    if (self.readLaterConnection) {
        [self.readLaterConnection cancel];
        self.readLaterConnection = nil;
    }
}

#pragma mark Misc methods
// Perform a connection to the provided url
- (void)performConnectionToUrl:(NSURL *)url
{
    NSURLRequest *referralRequest = [NSURLRequest requestWithURL:url];
    self.readLaterConnection = [[NSURLConnection alloc] initWithRequest:referralRequest delegate:self startImmediately:NO];
    [self.readLaterConnection start];
}

- (void)performConnectionWithRequest:(NSURLRequest *)request
{
    self.readLaterConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.readLaterConnection start];
}

@end