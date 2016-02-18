<img alt="SPTPersistentCache" src="SPTPersistentCache.jpg">

Everyone tries to implement a cache at some point in their apps lifecycle, and this is ours. This is a library that allows people to cache NSData with TTL values and semantics for disk management.

- [x] 📱 iOS 7.0+
- [x] 💻 OS X 10.9+

## Architecture :triangular_ruler:
`SPTPersistentCache` is designed as an LRU cache which stores all the data in a single binary file, with entries containing the length, last accessed time and a CRC check designed to prevent corruption. It can be used to automatically schedule garbage collection and invoke pruning.

## Installation
SPTPersistentCache can be installed in a variety of ways including traditional static libraries and dynamic frameworks.

### Static Library
Simply include `SPTPersistentCache.xcodeproj` in your App’s Xcode project, and link your app with the library in the “Build Phases” section.

## Background story :book:
At Spotify we began to standardise the way we handled images in a centralised way, and in doing so we initially created a component that was handling images and their caching. But then our requirements changed, and we began to need caching for our backend calls and preview MP3 downloads as well. In doing so, we managed to separate out our caching logic into a generic component that can be used for any piece of data.

Thus we boiled down what we needed in a cache, the key features being TTL on specific pieces of data, disk management to make sure we don't use too much, and protections against data corruption. It also became very useful to separate different caches into separate files (such as images and mp3s), in order to easily measure how much space each item is taking up.

## Contributing :mailbox_with_mail:
Contributions are welcomed, have a look at the [CONTRIBUTING.md](CONTRIBUTING.md) document for more information.

## License :memo:
The project is available under the [Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0) license.