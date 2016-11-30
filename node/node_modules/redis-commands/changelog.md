## v.1.3.0 - 20 Oct, 2016

Features

-  Rebuild the commands with the newest Redis unstable release

## v.1.2.0 - 21 Apr, 2016

Features

-  Added support for `MIGRATE [...] KEYS key1, key2` (Redis >= v.3.0.6)
-  Added build sanity check for unhandled commands with moveable keys
-  Rebuild the commands with the newest unstable release
-  Improved performance of .getKeyIndexes()

Bugfix

-  Fixed command command returning the wrong arity due to a Redis bug
-  Fixed brpop command returning the wrong keystop due to a Redis bug

## v.1.1.0 - 09 Feb, 2016

Features

-  Added .exists() to check for command existence
-  Improved performance of .hasFlag()
