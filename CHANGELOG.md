# Change Log
All notable changes to this project will be documented in this file. SPTPersistentCache adheres to [Semantic Versioning](http://semver.org/).

--
## [1.1.1](https://github.com/spotify/SPTPersistentCache/releases/tag/1.1.1)
_Released on 2017-08-15._

### Fixed
* SPTPersistentCacheOptions properties are now copied corrently when using `-copy`. 

## [1.1.0](https://github.com/spotify/SPTPersistentCache/releases/tag/1.1.0)
_Released on 2016-11-18._

### Added
* Added ability to track the caches performance in time.

### Fixed
* When deleting or adding a large amount of items, the cache can now be configured prioritise these insertions compared to normal reads/writes.

### Removed
* Removed support for iOS 7.x.
* Removed support for OSX 10.9.x.

### Changed
* Now uses NSOperationQueues rather than GCD for prioritization reasons.
* Large removes, prunes and garbage collection routines are now asynchronous (this is an API breakage).

## [1.0.0](https://github.com/spotify/SPTPersistentCache/releases/tag/1.0.0)
_Released on 2015-03-11._

### Added
* Initial release of SPTPersistentCache.
