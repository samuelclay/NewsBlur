Instapaper-Activity
===================

iOS UIActivity for reading later on Instapaper. Initially conceived to be used on one of my own projects: [Nyndoo](http://www.nyndoo.com) a page-per-tweet twitter client.

Feel free to add any request, bug or inquiry on the issues section!

Previews
========
![](https://raw.github.com/marianoabdala/ZYInstapaperActivity/master/Resources/Intro.PNG)
![](https://raw.github.com/marianoabdala/ZYInstapaperActivity/master/Resources/UIActivityViewController.PNG)
![](https://raw.github.com/marianoabdala/ZYInstapaperActivity/master/Resources/WithTheGang.PNG)
![](https://raw.github.com/marianoabdala/ZYInstapaperActivity/master/Resources/Credentials.PNG)
![](https://raw.github.com/marianoabdala/ZYInstapaperActivity/master/Resources/Adding.PNG)

Usage sample
============

    NSURL *url =
    [NSURL URLWithString:@"http://mariano.zerously.com/post/28497816299/fixed-quotes"];
    
    UIActivityViewController *activityViewController =
    [[UIActivityViewController alloc] initWithActivityItems:@[ url ]
                                      applicationActivities:@[ [ZYInstapaperActivity instance] ]];
    
    [self presentViewController:activityViewController
                       animated:YES
                     completion:nil];


**With some extra options**

    NSURL *url =
    [NSURL URLWithString:@"http://mariano.zerously.com/post/28497816299/fixed-quotes"];
    
    ZYInstapaperActivityItem *item =
    [[ZYInstapaperActivityItem alloc] initWithURL:textFieldURL];
    
    item.title = @"Fixed quotes";
    item.description = @"Saved using @Nyndoo.";
    
    NSArray *activityItems =
    @[ item ];
    
    NSArray *applicationActivities =
    @[ [ZYInstapaperActivity instance] ];
    
    UIActivityViewController *activityViewController =
    [[UIActivityViewController alloc] initWithActivityItems:activityItems
                                      applicationActivities:applicationActivities];
    
    //Show only Instapaper Activity.
    activityViewController.excludedActivityTypes =
    @[  UIActivityTypePostToFacebook,
        UIActivityTypePostToTwitter,
        UIActivityTypePostToWeibo,
        UIActivityTypeMessage,
        UIActivityTypeMail,
        UIActivityTypePrint,
        UIActivityTypeCopyToPasteboard,
        UIActivityTypeAssignToContact,
        UIActivityTypeSaveToCameraRoll  ];
    
    [self presentViewController:activityViewController
                       animated:YES
                     completion:nil];

How to install
==============

1. Drag the ZYInstapaperActivity folder into your own project.
2. Make sure the Security.framework is linked, if not link it.
3. Make sure you are not already using Apple's KeychainItemWrapper, if you are you'll have it duplicate. Choose one and delete the other.

Other referenced projects
=========================
* [KeychainItemWrapper ARCified](https://gist.github.com/1170641) by [David Hoerl](https://github.com/dhoerl)
* [ZYActivity](https://github.com/marianoabdala/ZYActivity) by [Mariano Abdala](https://github.com/marianoabdala)
* [ZYTopAlignedLabel](https://github.com/marianoabdala/Zerously-toolkit) by [Mariano Abdala](https://github.com/marianoabdala)

License
=======

Copyright (c) 2012 Mariano Abdala.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
