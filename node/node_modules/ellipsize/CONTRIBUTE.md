## Contributing

Any contributions are welcome, be it documentation, bugfixes or new features.
Please use pull request to send me patches. Check the bugtracker first, feature
requests are welcome, as wel as bugreports.

When sending a bug report or a feature request, be sure to give me some context.
How did the bug occur, what platform are you on (Windows? Linux? Mac?), why do
you need this feature, so I can decide on the serverity of the problem or provide
additional pointers, etcetera.

Please be patient, it may take a day or two for me to respond.

## Code guidelines

No tabs, four spaces. Clean up trailing whitespace. This can all be achieved
by simply running:

    make tidy
    make lint

before each commit. Oh, and run `npm test` too.

New features come with a small unit test. I prefer tdd style, not bdd. See the
files in the `test` directory for a start.

Hope you're enjoying my software :)


