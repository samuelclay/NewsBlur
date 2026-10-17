# Android Play crash audit, October 17, 2026

Play Console showed a 3.71% crash rate for the last 28 days, up 2.355 percentage points. That aggregate is not the crash rate of the latest release. The live production page showed 15.1 available, 16.0 halted, and 16.0.1 in draft.

The investigation initially enumerated 166 historical crash/ANR groups using the Reporting API with no version or foreground-only filter. Following the requested scope refinement, fixes focus on current code and recent reports. The recent API request used start 2026-10-14 and end 2026-10-17 21:00, without a timezone field (the API rejects timezone/UTC-offset arguments). All pages were consumed: 18 issue groups, 117 events, and 28 sample reports. These are 10 crash groups and 8 ANR groups; users can occur in multiple groups.

The complete recent inventory is below, including older-version occurrences. IDs link directly to their Play Console report. Stack traces are sanitized by Google and sometimes omit the exception message or all frames. A matching exception name alone does not establish a root cause or prove a fix.

| Issue | Type | Events | Versions | Entry point |
|---|---|---:|---|---|
| [21d3920c](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/21d3920ce5e84ac492e4763ad52ca786/details) | Crash | 59 | 291–292 | com.newsblur.database.BlurDatabaseHelper.loadCustomIconsFromDb |
| [b805eca9](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/b805eca90679b3c5d409795123181d00/details) | Crash | 16 | 291–291 | com.newsblur.activity.Reading.showUnreadSnackbar |
| [43865057](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/43865057fca3ffad8af5d42baa25696b/details) | Crash | 9 | 291–292 | com.newsblur.database.BlurDatabaseHelper.loadCustomIconsFromDb |
| [ff040600](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/ff040600f98987ee330d8bc335bcb535/details) | Crash | 9 | 291–291 | chromium-SystemWebViewGoogle6432.aab-stable-803710603 - org.chromium.base.JniAndroid.handleException |
| [f685ac18](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/f685ac1825512a7a6bb22d363af57cee/details) | Crash | 4 | 281–281 | com.newsblur.util.SessionDataSource.getNextNonEmptyFolder |
| [0d0c89d4](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/0d0c89d4c6cc2324e2bbdbaaa597b7b7/details) | Crash | 3 | 289–290 | com.google.android.material.appbar.HeaderScrollingViewBehavior.layoutChild |
| [92685481](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/92685481f8379497db16c8cd82747f05/details) | ANR | 3 | 291–291 | com.newsblur.service.SyncRequestCoordinator.request |
| [5162cbb9](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/5162cbb962a594354db87d039d3c577e/details) | ANR | 2 | 291–291 | Native method - android.os.MessageQueue.nativePollOnce |
| [542d6572](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/542d6572dc024f665564b127bc64eb6f/details) | ANR | 2 | 291–291 | com.newsblur.util.ExtensionsKt$executeAsyncTask$3.invokeSuspend |
| [d8563e61](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/d8563e612d891d06356aae70d534763e/details) | Crash | 2 | 291–291 | com.newsblur.util.Log.offerContext |
| [06d5c8eb](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/06d5c8ebcee042a9fbff13d158ab3668/details) | Crash | 1 | 292–292 | Unknown Source - com.newsblur.database.b.w |
| [15c16cdd](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/15c16cdd95430974988e884c08c756c4/details) | ANR | 1 | 291–291 | libcore.io.ForwardingOs.getpid |
| [4277ea3d](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/4277ea3df7564fbed555e8930a9d9467/details) | ANR | 1 | 291–291 | com.newsblur.service.SyncJobRunner.<init> |
| [57b598a5](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/57b598a59bd967131b5596807caded55/details) | Crash | 1 | 291–291 | com.newsblur.service.SyncService.setSyncServiceState |
| [5f54baa2](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/5f54baa2231647f50d71a9ad6e1c92d9/details) | ANR | 1 | 291–291 | com.newsblur.service.SyncJobRunner.launchIn |
| [6ed5fea7](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/6ed5fea758f710afed6c8a277a31e8e6/details) | ANR | 1 | 291–291 | com.newsblur.service.SyncJobRunner.launchIn |
| [bfe268be](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/bfe268bea228839f2eb489404d1886a8/details) | ANR | 1 | 291–291 | android.os.BinderProxy.updateStrictModeBinderHintsIfNeeded |
| [cdf35f41](https://play.google.com/console/developers/6280481402178293168/app/4972990522498280751/vitals/crashes/cdf35f41309c4588de3b26180fea5283/details) | Crash | 1 | 291–291 | java.io.ObjectOutputStream.writeObject0 |

## Verified earlier fixes

- The folder-navigation overflow occurred on version 281. Current code uses bounded traversal, fixed by `553b13981` / `25b30d0a3` and covered by `SessionDataSourceTest`.
- The RecyclerView position failure occurred on versions 289–290. Version 291 includes `8982276e0`, which makes free-account preview rows and diff notifications agree; `Test_StoryViewAdapterSubscriptionPreview` covers that mismatch. This addresses a known cause of the signature; the stripped stack does not establish every historical occurrence had that cause.

## Release boundary

This PR prepares source fixes and validation. It does not publish an Android release or establish that production crash rates have fallen.
