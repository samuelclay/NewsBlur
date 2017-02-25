## v.2.3.0 - 25 Nov, 2016

Features

-  Parsing time for big arrays (e.g. 4mb+) is now linear and works well for arbitrary array sizes

This case is a magnitude faster than before

    OLD STR: * big array x 1.09 ops/sec ±2.15% (7 runs sampled)
    OLD BUF: * big array x 1.23 ops/sec ±2.67% (8 runs sampled)

    NEW STR: * big array x 273 ops/sec ±2.09% (85 runs sampled)
    NEW BUF: * big array x 259 ops/sec ±1.32% (85 runs sampled)
    (~10mb array with 1000 entries)

## v.2.2.0 - 18 Nov, 2016

Features

-  Improve `stringNumbers` parsing performance by up to 100%

Bugfixes

-  Do not unref the interval anymore due to issues with NodeJS

## v.2.1.1 - 31 Oct, 2016

Bugfixes

-  Remove erroneously added const to support Node.js 0.10

## v.2.1.0 - 30 Oct, 2016

Features

-  Improve parser errors by adding more detailed information to them
-  Accept manipulated Object.prototypes
-  Unref the interval if used

## v.2.0.4 - 21 Jul, 2016

Bugfixes

-  Fixed multi byte characters getting corrupted

## v.2.0.3 - 17 Jun, 2016

Bugfixes

-  Fixed parser not working with huge buffers (e.g. 300 MB)

## v.2.0.2 - 08 Jun, 2016

Bugfixes

-  Fixed parser with returnBuffers option returning corrupted data

## v.2.0.1 - 04 Jun, 2016

Bugfixes

-  Fixed multiple parsers working concurrently resulting in faulty data in some cases

## v.2.0.0 - 29 May, 2016

The javascript parser got completly rewritten by [Michael Diarmid](https://github.com/Salakar) and [Ruben Bridgewater](https://github.com/BridgeAR) and is now a lot faster than the hiredis parser.
Therefore the hiredis parser was deprecated and should only be used for testing purposes and benchmarking comparison.

All Errors returned by the parser are from now on of class ReplyError

Features

-  Improved performance by up to 15x as fast as before
-  Improved options validation
-  Added ReplyError Class
-  Added parser benchmark
-  Switched default parser from hiredis to JS, no matter if hiredis is installed or not

Removed

-  Deprecated hiredis support

## v.1.3.0 - 27 Mar, 2016

Features

-  Added `auto` as parser name option to check what parser is available
-  Non existing requested parsers falls back into auto mode instead of always choosing the JS parser

## v.1.2.0 - 27 Mar, 2016

Features

-  Added `stringNumbers` option to make sure all numbers are returned as string instead of a js number for precision
-  The parser is from now on going to print warnings if a parser is explicitly requested that does not exist and gracefully chooses the JS parser

## v.1.1.0 - 26 Jan, 2016

Features

-  The parser is from now on going to reset itself on protocol errors
