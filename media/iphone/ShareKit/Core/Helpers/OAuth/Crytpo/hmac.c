//
//  hmac.c
//  OAuthConsumer
//
//  Created by Jonathan Wight on 4/8/8.
//  Copyright 2008 Jonathan Wight. All rights reserved.
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

/*
 * Implementation of HMAC-SHA1. Adapted from example at http://tools.ietf.org/html/rfc2104
 
 */

#include "sha1.h"
#include "hmac.h"

#include <stdlib.h>
#include <string.h>

void hmac_sha1(const unsigned char *inText, int inTextLength, unsigned char* inKey, const unsigned int inKeyLengthConst, unsigned char *outDigest)
{
const unsigned int B = 64;
const size_t L = 20;

SHA1_CTX theSHA1Context;
unsigned char k_ipad[B + 1]; /* inner padding - key XORd with ipad */
unsigned char k_opad[B + 1]; /* outer padding - key XORd with opad */

/* if key is longer than 64 bytes reset it to key=SHA1 (key) */
unsigned int inKeyLength = inKeyLengthConst;
if (inKeyLength > B)
	{
	SHA1Init(&theSHA1Context);
	SHA1Update(&theSHA1Context, inKey, inKeyLength);
	SHA1Final(inKey, &theSHA1Context);
	inKeyLength = L;
	}

/* start out by storing key in pads */
memset(k_ipad, 0, sizeof k_ipad);
memset(k_opad, 0, sizeof k_opad);
memcpy(k_ipad, inKey, inKeyLength);
memcpy(k_opad, inKey, inKeyLength);

/* XOR key with ipad and opad values */
unsigned int i;
for (i = 0; i < B; i++)
	{
	k_ipad[i] ^= 0x36;
	k_opad[i] ^= 0x5c;
	}
	
/*
* perform inner SHA1
*/
SHA1Init(&theSHA1Context);                 /* init context for 1st pass */
SHA1Update(&theSHA1Context, k_ipad, B);     /* start with inner pad */
SHA1Update(&theSHA1Context, (unsigned char *)inText, inTextLength); /* then text of datagram */
SHA1Final((unsigned char *)outDigest, &theSHA1Context);                /* finish up 1st pass */

/*
* perform outer SHA1
*/
SHA1Init(&theSHA1Context);                   /* init context for 2nd
* pass */
SHA1Update(&theSHA1Context, k_opad, B);     /* start with outer pad */
SHA1Update(&theSHA1Context, outDigest, L);     /* then results of 1st
* hash */
SHA1Final(outDigest, &theSHA1Context);          /* finish up 2nd pass */

}
