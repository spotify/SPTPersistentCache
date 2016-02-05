Pod::Spec.new do |s|

    s.name         = "SPTPersistentDataCache"
    s.version      = "1.0.0"
    s.summary      = "SPTPersistentDataCache is a fast, binary, LRU cache used by the Spotify app"

    s.description  = <<-DESC
                        Everyone tries to implement a cache at some point in their apps lifecycle,
                        and this is ours. This is a library that allows people to cache NSData
                        with TTL values and semantics for disk management.
                     DESC

    s.ios.deployment_target = "7.0"
    s.osx.deployment_target = "10.8"

    s.homepage     = "https://github.com/spotify/SPTPersistentDataCache"
    s.license      = "Apache 2.0"
    s.author       = { "Dmitry Ponomarev" => "dmitry@spotify.com" }
    s.source       = { :git => "https://github.com/spotify/SPTPersistentDataCache.git", :tag => s.version }
    s.source_files = "include/SPTPersistentDataCache/*.h", "Sources/*.{h,m}"
    s.public_header_files = "include/SPTPersistentDataCache/*.h"
    s.xcconfig = { 'OTHER_LDFLAGS' => '-lObjC' }
    s.module_map = 'include/SPTPersistentDataCache/module.modulemap'

end
