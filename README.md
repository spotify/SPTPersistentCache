<img alt="SPTPersistentCache" src="banner@2x.png" width="100%" max-width="888">

[![Build Status](https://api.travis-ci.org/spotify/SPTPersistentCache.svg)](https://travis-ci.org/spotify/SPTPersistentCache)
[![Coverage Status](https://codecov.io/github/spotify/SPTPersistentCache/coverage.svg?branch=master)](https://codecov.io/github/spotify/SPTPersistentCache?branch=master)
[![Documentation](https://img.shields.io/cocoapods/metrics/doc-percent/SPTPersistentCache.svg)](http://cocoadocs.org/docsets/SPTPersistentCache/)
[![License](https://img.shields.io/github/license/spotify/SPTPersistentCache.svg)](LICENSE)
[![CocoaPods](https://img.shields.io/cocoapods/v/SPTPersistentCache.svg)](https://cocoapods.org/?q=SPTPersistentCache)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Spotify FOSS Slack](https://slackin.spotify.com/badge.svg)](https://slackin.spotify.com)
[![Readme Score](http://readme-score-api.herokuapp.com/score.svg?url=https://github.com/spotify/sptpersistentcache)](http://clayallsopp.github.io/readme-score?url=https://github.com/spotify/sptpersistentcache)

Everyone tries to implement a cache at some point in their app’s lifecycle, and this is ours. This is a library that allows people to cache `NSData` with time to live (TTL) values and semantics for disk management.

- [x] 📱 iOS 7.0+
- [x] 💻 OS X 10.9+

## Architecture :triangular_ruler:
`SPTPersistentCache` is designed as an LRU cache which stores all the data in a single binary file, with entries containing the length, last accessed time and a CRC check designed to prevent corruption. It can be used to automatically schedule garbage collection and invoke pruning.

## Installation :inbox_tray:
`SPTPersistentCache` can be installed in a variety of ways including traditional static libraries and dynamic frameworks.

### Static Library
Simply include `SPTPersistentCache.xcodeproj` in your App’s Xcode project, and link your app with the library in the “Build Phases” section.

### CocoaPods
We are indexed on [CocoaPods](http://cocoapods.org), which can be installed using [Ruby gems](https://rubygems.org/):
```shell
$ gem install cocoapods
```
Then simply add `SPTPersistentCache` to your `Podfile`.
```
pod 'SPTPersistentCache', '~> 1.0'
```
Lastly let CocoaPods do it's thing by running:
```shell
$ cocoapods update
```

### Carthage
We support [Carthage](https://github.con/Carthage/Carthage) and provide pre-built binary frameworks for all new releases. Start by making sure you have the latest version of Carthage installed, e.g. using [Homebrew](http://brew.sh/):
```shell
$ brew update
$ brew install carthage
```
You will also need to add `SPTPersistentCache` to your `Cartfile`:
```
github 'spotify/SPTPersistentCache' ~> 1.0
```
After that is all said and done, let Carthage pull in SPTPersistentCache like so:
```shell
$ carthage update
```
Next up, you need to add the framework to the Xcode project of your App. Lastly link the framework with your App and copy it to the App’s Frameworks directory under the “Build Phases”.

## Usage example :eyes:
For an example of this framework's usage, see the demo application `SPTPersistentCacheDemo` in `SPTPersistentCache.xcworkspace`.

### Creating the SPTPersistentCache
It is best to use different caches for different types of data you want to store, and not just one big cache for your entire application. However, only create one `SPTPersistentCache` instance for each cache, otherwise you might encounter anomalies when the two different caches end up writing to the same file.
```objc
SPTPersistentCacheOptions *options = [[SPTPersistentCacheOptions alloc] initWithCachePath:cachePath
                                                                               identifier:@"com.spotify.demo.image.cache"
                                                                      currentTimeCallback:nil
                                                                defaultExpirationInterval:(60 * 60 * 24 * 30)
                                                                 garbageCollectorInterval:(NSUInteger)(1.5 * SPTPersistentCacheDefaultGCIntervalSec)
                                                                                    debug:^(NSString *string) {
                                                                                              NSLog(@"%@", string);
                                                                                          }];
options.sizeConstraintBytes = 1024 * 1024 * 10; // 10 MiB
SPTPersistentCache *cache = [[SPTPersistentCache alloc] initWithOptions:options];
```
Note that in  the above example, the `currentTimeCallback` is `nil`. When this is nil it will default to using `NSDate` for its current time.

### Storing Data in the SPTPersistentCache
When storing data in the `SPTPersistentCache`, you must be aware of the file system semantics. The key will be used as the file name within the cache directory to save. The reason we did not implement a hash function under the hood is because we wanted to give the option of what hash function to use to the user, so it is recommended that when you insert data into the cache for a key, that you create the key using your own hashing function (at Spotify we use SHA1, although better hashing functions exist these days). If you want the cache record, i.e. file, to exist without any TTL make sure you store it as a locked file.
```objc
NSData *data = UIImagePNGRepresentation([UIImage imageNamed:@"my-image"]);
NSString *key = @"MyHashValue";
[self.cache storeData:data
              forKey:key
              locked:YES
        withCallback:^(SPTPersistentCacheResponse *cacheResponse) {
             NSLog(@"cacheResponse = %@", cacheResponse);
        } onQueue:dispatch_get_main_queue()];
```

### Loading Data in the SPTPersistentCache
In order to restore data you already have saved in the `SPTPersistentCache`, you simply feed it the same key that you used to store the data.
```objc
NSString *key = @"MyHashValue";
[self.cache loadDataForKey:key withCallback:^(SPTPersistentCacheResponse *cacheResponse) {
    UIImage *image = [UIImage imageWithData:cacheResponse.record.data];
} onQueue:dispatch_get_main_queue()];
```
Note that if the TTL has expired, you will not receive a result.

## Background story :book:
At Spotify we began to standardise the way we handled images in a centralised way, and in doing so we initially created a component that was handling images and their caching. But then our requirements changed, and we began to need caching for our backend calls and preview MP3 downloads as well. In doing so, we managed to separate out our caching logic into a generic component that can be used for any piece of data.

Thus we boiled down what we needed in a cache, the key features being TTL on specific pieces of data, disk management to make sure we don't use too much, and protections against data corruption. It also became very useful to separate different caches into separate files (such as images and mp3s), in order to easily measure how much space each item is taking up.

## Contributing :mailbox_with_mail:
Contributions are welcomed, have a look at the [CONTRIBUTING.md](CONTRIBUTING.md) document for more information.

## License :memo:
The project is available under the [Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0) license.

### Acknowledgements
- Font in readme banner is “[Kyrilla Sans-Serif Bold](http://www.1001freefonts.com/kyrilla_sans_serif.font)” by [Manfred Klein](http://manfred-klein.ina-mar.com/).
- Icon in readme banner is “[Treasure Chest](https://thenounproject.com/term/treasure-chest/168777)” by Richard Cordero from the Noun Project.
