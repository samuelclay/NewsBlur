//
//  SHKRequest.h
//  ShareKit
//
//  Created by Nathan Weiner on 6/9/10.

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

#import <Foundation/Foundation.h>


@interface SHKRequest : NSObject 
{
	NSURL *url;
	NSString *params;
	NSString *method;
	NSDictionary *headerFields;
	
	id delegate;
	SEL isFinishedSelector;
	
	NSURLConnection *connection;
	
	NSHTTPURLResponse *response;
	NSDictionary *headers;
	
	NSMutableData *data;
	NSString *result;
	BOOL success;
}

@property (retain) NSURL *url;
@property (retain) NSString *params;
@property (retain) NSString *method;
@property (retain) NSDictionary *headerFields;

@property (assign) id delegate;
@property (assign) SEL isFinishedSelector;

@property (retain) NSURLConnection *connection;

@property (retain) NSHTTPURLResponse *response;
@property (retain) NSDictionary *headers;

@property (retain) NSMutableData *data;
@property (nonatomic, retain, getter=getResult) NSString *result;
@property (nonatomic) BOOL success;

- (id)initWithURL:(NSURL *)u params:(NSString *)p delegate:(id)d isFinishedSelector:(SEL)s method:(NSString *)m autostart:(BOOL)autostart;

- (void)start;
- (void)finish;


@end
