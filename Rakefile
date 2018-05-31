require 'active_support'
require 'active_support/core_ext'
require 'colored'
require 'rubygems'
require 'shellwords'
require 'set'
require 'simctl'

SIMULATOR_TEST_DEVICE_TYPES = [
  'com.apple.CoreSimulator.SimDeviceType.iPhone-5', # 32-bit iPhone
  'com.apple.CoreSimulator.SimDeviceType.iPhone-6', # 64-bit iPhone
  # TODO: support watchOS and tvOS
  # 'com.apple.CoreSimulator.SimDeviceType.Apple-TV-1080p', # Apple TV
]

SUPPORTED_ARCHS = [
  'macosx',
  'iphoneos', 'iphonesimulator',
  # TODO: support watchOS and tvOS
  #'watchos', 'watchsimulator',
  #'appletvos', 'appletvsimulator'
]

FRAMEWORK_SCHEMES = [
  'SPTPersistentCache-iOS',
  'SPTPersistentCache-OSX',
  # TODO: support watchOS and tvOS
  #'SPTPersistentCache-TV',
  #'SPTPersistentCache-Watch'
]

TEST_DERIVED_DATA_PATH = 'build/testDD'

namespace :validate do
  desc 'Lint Podspec'
  task :podspec do
    travis_fold('lint-podspec') do
      system("pod spec lint SPTPersistentCache.podspec --quick") || fail!("Podspec lint failed")
    end
  end

  desc 'Validate License Conformance'
  task :license do
    travis_fold('validate-license-conformance') do
      source_files = `git ls-files`.split("\n").select{|x| x =~ /\.(h|m|mm)$/}
      system('other/validate_license_conformance.sh', 'other/expected_license_header.txt', *source_files) || fail!("License conformance failed")
    end
  end

  desc 'Run all validations'
  task :all => [:podspec, :license]
end

namespace :build do
  desc 'Build libraries for all platforms (Release)'
  task :libraries do
    for sdk in SUPPORTED_ARCHS
      travis_fold("library-#{sdk}") do
        xcodebuild('build', scheme: 'SPTPersistentCache', configuration: 'Release', sdk: sdk)
      end
    end
  end

  desc 'Build frameworks for all platforms (Release)'
  task :frameworks do
    for framework in FRAMEWORK_SCHEMES
      travis_fold("framework-#{framework}") do
        xcodebuild('build', scheme: framework, configuration: 'Release')
      end
    end
  end

  desc 'Build SPTPersistentCacheDemo for the simulator'
  task :demo do
    travis_fold('build-demo') do
      device = get_device_for_demo_build
      destination = "platform=iOS Simulator,id=#{device.udid}"
      xcodebuild('build', scheme: 'SPTPersistentCacheDemo', configuration: 'Debug', destination: destination)
    end
  end

  desc 'Build libraries, frameworks, and demo project'
  task :all => [:libraries, :frameworks, :demo]
end

namespace :test do
  desc 'Run tests on macOS'
  task :macos do
    travis_fold('test-macos') do
      xcodebuild('test', scheme: 'SPTPersistentCache',
        destination: 'platform=OS X,arch=x86_64',
        enableCodeCoverage: 'YES',
        derivedDataPath: "#{TEST_DERIVED_DATA_PATH}/MacOSX")
    end
  end

  desc 'Run tests on the simulator matrix'
  task :simulators do
    # find devices for each runtime
    platforms = Set.new
    devices = get_test_simulators
    for device in devices
      runtime_ident = device.runtime.identifier
      platforms << platform_from_runtime_ident(runtime_ident)
    end

    # build-for-testing for each platform
    platform_test_bundles = {}
    for platform in platforms
      dd_path = File.expand_path(File.join(TEST_DERIVED_DATA_PATH, platform))
      travis_fold("build-for-testing-#{platform}") do
        xcodebuild('build-for-testing', 'ONLY_ACTIVE_ARCH=NO',
          scheme: 'SPTPersistentCache', sdk: platform.downcase,
          derivedDataPath: dd_path, enableCodeCoverage: 'YES')
      end

      bundles = Dir["#{dd_path}/**/*.xctest"]
      fail!("Failed to find test bundles for #{platform}") if bundles.blank?
      platform_test_bundles[platform] = bundles
    end

    # run tests
    for device in devices
      d_plist = device.send(:plist)
      device_type = d_plist.deviceType.split('.').last
      runtime = d_plist.runtime.split('.').last
      platform = platform_from_runtime_ident(d_plist.runtime)

      for bundle in platform_test_bundles[platform]
        base = File.basename(bundle, '.xctest')
        travis_fold("testing-#{device_type}-#{runtime}-#{base}") do
          simctl_test(device, platform, bundle)
        end
      end
    end
  end

  desc 'Capture Coverage'
  task :coverage do
    travis_fold('coverage') do
      platform_to_raw = {}
      for raw in Dir["#{profraw_dir}/**/*.profraw"]
        platform = File.basename(File.dirname(raw))
        platform_to_raw[platform] ||= []
        platform_to_raw[platform] << raw
      end

      if platform_to_raw.empty?
        puts 'No coverage to capture'
        next
      end

      # merge profdata
      for platform, raws in platform_to_raw
        profdata = File.join(TEST_DERIVED_DATA_PATH, "Coverage.#{platform}.profdata")
        system('xcrun', 'llvm-profdata', 'merge', '-o', profdata, *raws) || fail!('Failed to merge profdata')
      end

      # dry-run unless running in travis
      extra = is_travis? ? [] : ['-d']

      # post to codecov
      system('curl -s https://codecov.io/bash > build/codecov.sh')
      system('chmod +x build/codecov.sh')
      system(
        'build/codecov.sh', '-D',
        TEST_DERIVED_DATA_PATH,
        '-X', 'xcodellvm', # use xcode llvm coverage processor
        *extra
      )
    end
  end

  desc 'Run all tests'
  task :all => [:macos, :simulators, :coverage]
end

namespace :local do
  desc 'Package with Carthage'
  task :package do
    travis_fold('carthage-build-and-archive') do
      system('carthage build --no-skip-current') || fail!('Carthage build failed')
      system('carthage archive SPTPersistentCache') || fail!('Carthage archive failed')
    end
  end
end

namespace :ci do
  desc 'Build, test, and validate'
  task :build_and_test => ['validate:all', 'build:all', 'test:all']

  desc 'Package for deployment'
  task :package do
    travis_fold('carthage-install') do
      system('brew update && brew install carthage') || fail!('Unable to install Carthage')
    end
    Rake::Task['local:package'].invoke
  end
end

#
# Run the given xcodebuild command
#
def xcodebuild(*args)
  opts = args.last.is_a?(Hash) ? args.pop : {}
  opts[:workspace] ||= 'SPTPersistentCache.xcworkspace'
  opts[:configuration] ||= 'Debug'

  args = ['xcrun', 'xcodebuild', 'NSUnbufferedIO=YES'] + args
  for k, v in opts
    args.push("-#{k}", v.to_s)
  end

  full_cmd = Shellwords.shelljoin(args)
  puts full_cmd.blue
  system("set -o pipefail && #{full_cmd} | xcpretty") || fail!('xcodebuild failed')
end

#
# Get the Xcode developer dir
#
def developer_dir
  @developer_dir ||= `xcode-select -p`.strip
end

#
# Run a logic test with simctl
#
def simctl_test(device, platform, bundle)
  udid = device.udid
  xctest_path = "#{developer_dir}/Platforms/#{platform}.platform/Developer/Library/Xcode/Agents/xctest"

  full_cmd = Shellwords.shelljoin(['xcrun', 'simctl', 'spawn', udid, xctest_path, bundle])
  puts full_cmd.blue

  # capture raw profiles
  env = { 'SIMCTL_CHILD_LLVM_PROFILE_FILE' => "#{profraw_dir}/#{platform}/%p.profraw" }
  system(env, "set -o pipefail && #{full_cmd} 2>&1 | xcpretty") || fail!('tests failed')
end

#
# Get the list of test devices
#
def get_test_simulators()
  # get devices by type
  available_devices = SimCtl.list_devices.where(available?: true)
  devices_by_type = available_devices.group_by{ |d|
    d.send(:plist).deviceType
  }.slice(*SIMULATOR_TEST_DEVICE_TYPES)

  # get the latest runtime for each device
  result = []

  for type, devices in devices_by_type
    mapping = {}

    for device in devices
      runtime = device.runtime
      runtime_v = Gem::Version.new(runtime.version)
      key = runtime_v.segments.first
      existing = mapping[key]

      if !existing
        mapping[key] = device
      elsif runtime_v > Gem::Version.new(existing.runtime.version)
        mapping[key] = device
      end
    end

    result.concat(mapping.values)
  end

  return result
end

#
# Get the device for building the iOS demo application.
#
def get_device_for_demo_build
  runtime = SimCtl::Runtime.latest('iOS')
  SimCtl.list_devices.where(available?: true, os: runtime.name).find do |dev|
    dev.send(:plist).deviceType == 'com.apple.CoreSimulator.SimDeviceType.iPhone-6'
  end
end

#
# Return true if running in travis.
#
def is_travis?
  ENV.has_key?('TRAVIS') && ENV.has_key?('CI') 
end

#
# Wrap in a travis block
#
def travis_fold(name)
  puts is_travis? ? "travis_fold:start:#{name}" : name.magenta
  yield
ensure
  puts is_travis? ? "travis_fold:end:#{name}" : name.magenta
end

#
# Fail with the given message and exit
#
def fail!(message)
  $stderr.puts "error: #{message}"
  exit 1
end

#
# Get the platform from the runtime identifier
#
def platform_from_runtime_ident(ident)
  last = ident.split('.').last
  return 'iPhoneSimulator' if last =~ /iOS/
  return 'AppleTVSimulator' if last =~ /tvOS/
  return 'WatchSimulator' if last =~ /watchOS/
  return nil
end

def profraw_dir
  File.expand_path(File.join(TEST_DERIVED_DATA_PATH, 'profraw'))
end
