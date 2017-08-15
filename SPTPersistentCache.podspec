Pod::Spec.new do |s|

    s.name         = "SPTPersistentCache"
    s.version      = "1.1.1"
    s.summary      = "SPTPersistentCache is a fast, binary, LRU cache used in the Spotify iOS app"

    s.description  = <<-DESC
                        Everyone tries to implement a cache at some point in their apps lifecycle,
                        and this is ours. This is a library that allows people to cache NSData
                        with TTL values and semantics for disk management.
                     DESC

    s.ios.deployment_target = "8.0"
    s.osx.deployment_target = "10.10"

    s.homepage          = "https://github.com/spotify/SPTPersistentCache"
    s.social_media_url  = "https://twitter.com/spotifyeng"
    s.license           = "Apache 2.0"
    s.author            = {
        "Dmitry Ponomarev" => "dmitry@spotify.com"
    }

    s.source                = { :git => "https://github.com/spotify/SPTPersistentCache.git", :tag => s.version }
    s.source_files          = "include/SPTPersistentCache/*.h", "Sources/**/*.{h,m,c}"
    s.public_header_files   = "include/SPTPersistentCache/*.h"
    s.xcconfig              = {
        "OTHER_LDFLAGS" => "-lObjC"
    }

end
