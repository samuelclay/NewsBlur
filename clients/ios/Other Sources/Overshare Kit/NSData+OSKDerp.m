//
//  NSData+OSKDerp.m
//  DerpKit
//
//  Created by Steve Streza on 7/15/12.
//  Copyright (c) 2012 Steve Streza
//  
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

#import "NSData+OSKDerp.h"

NSUInteger OSKDerpKitBase64encode_len(NSUInteger len);
int OSKDerpKitBase64encode(char * coded_dst, const char *plain_src, NSUInteger len_plain_src);

NSUInteger OSKDerpKitBase64decode_len(const char * coded_src);
int OSKDerpKitBase64decode(char * plain_dst, const char *coded_src);

static const char OSKDerpKitBase64EncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

@implementation NSData (OSKDerp)

-(NSString *)osk_derp_stringByBase64EncodingData{
	if ([self length] == 0)
		return @"";
	
    char *characters = malloc((([self length] + 2) / 3) * 4);
	if (characters == NULL)
		return nil;
	NSUInteger length = 0;
	
	NSUInteger i = 0;
	while (i < [self length])
	{
		char buffer[3] = {0,0,0};
		short bufferLength = 0;
		while (bufferLength < 3 && i < [self length])
			buffer[bufferLength++] = ((char *)[self bytes])[i++];
		
		//  Encode the bytes in the buffer to four characters, including padding "=" characters if necessary.
		characters[length++] = OSKDerpKitBase64EncodingTable[(buffer[0] & 0xFC) >> 2];
		characters[length++] = OSKDerpKitBase64EncodingTable[((buffer[0] & 0x03) << 4) | ((buffer[1] & 0xF0) >> 4)];
		if (bufferLength > 1)
			characters[length++] = OSKDerpKitBase64EncodingTable[((buffer[1] & 0x0F) << 2) | ((buffer[2] & 0xC0) >> 6)];
		else characters[length++] = '=';
		if (bufferLength > 2)
			characters[length++] = OSKDerpKitBase64EncodingTable[buffer[2] & 0x3F];
		else characters[length++] = '=';
	}
	
	return [[NSString alloc] initWithBytesNoCopy:characters length:length encoding:NSASCIIStringEncoding freeWhenDone:YES];
}

-(NSString *)osk_derp_stringByBase64DecodingData{
	const void *inBytes = [self bytes];
	
	int outLength = (int)(OSKDerpKitBase64decode_len(inBytes));
	void *outBytes = malloc(outLength);
	OSKDerpKitBase64decode(outBytes, inBytes);
	
	NSData *outData = [NSData dataWithBytesNoCopy:outBytes length:outLength freeWhenDone:YES];
	return [[NSString alloc] initWithData:outData encoding:NSASCIIStringEncoding];
}

-(NSString *)osk_derp_UTF8String{
	return [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
}

@end

#include <string.h>

static const unsigned char OSKDerpKitBase64_pr2six[256] =
{
    /* ASCII table */
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 62, 64, 64, 64, 63,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 64, 64, 64, 64, 64, 64,
    64,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 64, 64, 64, 64, 64,
    64, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64
};

NSUInteger OSKDerpKitBase64decode_len(const char *bufcoded)
{
    int nbytesdecoded;
    register const unsigned char *bufin;
    register int nprbytes;
	
    bufin = (const unsigned char *) bufcoded;
    while (OSKDerpKitBase64_pr2six[*(bufin++)] <= 63);
	
    nprbytes = (int)((bufin - (const unsigned char *) bufcoded) - 1);
    nbytesdecoded = ((nprbytes + 3) / 4) * 3;
	
    return nbytesdecoded + 1;
}

int OSKDerpKitBase64decode(char *bufplain, const char *bufcoded)
{
    int nbytesdecoded;
    register const unsigned char *bufin;
    register unsigned char *bufout;
    register int nprbytes;
	
    bufin = (const unsigned char *) bufcoded;
    while (OSKDerpKitBase64_pr2six[*(bufin++)] <= 63);
    nprbytes = (int)((bufin - (const unsigned char *) bufcoded) - 1);
    nbytesdecoded = ((nprbytes + 3) / 4) * 3;
	
    bufout = (unsigned char *) bufplain;
    bufin = (const unsigned char *) bufcoded;
	
    while (nprbytes > 4) {
		*(bufout++) =
        (unsigned char) (OSKDerpKitBase64_pr2six[*bufin] << 2 | OSKDerpKitBase64_pr2six[bufin[1]] >> 4);
		*(bufout++) =
        (unsigned char) (OSKDerpKitBase64_pr2six[bufin[1]] << 4 | OSKDerpKitBase64_pr2six[bufin[2]] >> 2);
		*(bufout++) =
        (unsigned char) (OSKDerpKitBase64_pr2six[bufin[2]] << 6 | OSKDerpKitBase64_pr2six[bufin[3]]);
		bufin += 4;
		nprbytes -= 4;
    }
	
    /* Note: (nprbytes == 1) would be an error, so just ingore that case */
    if (nprbytes > 1) {
		*(bufout++) =
        (unsigned char) (OSKDerpKitBase64_pr2six[*bufin] << 2 | OSKDerpKitBase64_pr2six[bufin[1]] >> 4);
    }
    if (nprbytes > 2) {
		*(bufout++) =
        (unsigned char) (OSKDerpKitBase64_pr2six[bufin[1]] << 4 | OSKDerpKitBase64_pr2six[bufin[2]] >> 2);
    }
    if (nprbytes > 3) {
		*(bufout++) =
        (unsigned char) (OSKDerpKitBase64_pr2six[bufin[2]] << 6 | OSKDerpKitBase64_pr2six[bufin[3]]);
    }
	
    *(bufout++) = '\0';
    nbytesdecoded -= (4 - nprbytes) & 3;
    return nbytesdecoded;
}

static const char OSKDerpKitBase64_basis64[] =
"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

NSUInteger OSKDerpKitBase64encode_len(NSUInteger len)
{
    return ((len + 2) / 3 * 4) + 1;
}

int OSKDerpKitBase64encode(char *encoded, const char *string, NSUInteger len)
{
    int i;
    char *p;
	
    p = encoded;
    for (i = 0; i < len - 2; i += 3) {
		*p++ = OSKDerpKitBase64_basis64[(string[i] >> 2) & 0x3F];
		*p++ = OSKDerpKitBase64_basis64[((string[i] & 0x3) << 4) |
									 ((int) (string[i + 1] & 0xF0) >> 4)];
		*p++ = OSKDerpKitBase64_basis64[((string[i + 1] & 0xF) << 2) |
									 ((int) (string[i + 2] & 0xC0) >> 6)];
		*p++ = OSKDerpKitBase64_basis64[string[i + 2] & 0x3F];
    }
    if (i < len) {
		*p++ = OSKDerpKitBase64_basis64[(string[i] >> 2) & 0x3F];
		if (i == (len - 1)) {
			*p++ = OSKDerpKitBase64_basis64[((string[i] & 0x3) << 4)];
			*p++ = '=';
		}
		else {
			*p++ = OSKDerpKitBase64_basis64[((string[i] & 0x3) << 4) |
										 ((int) (string[i + 1] & 0xF0) >> 4)];
			*p++ = OSKDerpKitBase64_basis64[((string[i + 1] & 0xF) << 2)];
		}
		*p++ = '=';
    }
	
    *p++ = '\0';
    return (int)(p - encoded);
}
