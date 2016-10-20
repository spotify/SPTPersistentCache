# Spotify CI Scripts

[![Build Status](https://travis-ci.org/spotify/ios-ci.svg?branch=master)](https://travis-ci.org/spotify/ios-ci)
![Platforms supported: iOS, tvOS, watchOS and OS X](https://img.shields.io/badge/platform-iOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20OS%20X-blue.svg)

A collection of scripts Spotify runs on its Open Source iOS, tvOS, watchOS and OS X projects. The scripts are opinionated and will not work with any CI setup. However should you choose a similar stack as ours they should work for you as well.

We’re currently using the following stack:
- OS X (as this is for Apple platforms).
- Travis-CI for running the CI jobs.
  - Other CI provides might work.
- Codecov for code coverage reporting and visualization.

## Installing
There are primarily two routes on how to add the scripts to your repository. Either as a git submodule (only appropriate for apps) or using git subtree merging.

### For applications
If you want to add _ios-ci_ as a dependency to an **application**, add the repository as a [submodule](http://git-scm.com/book/en/Git-Tools-Submodules). When this is done continue with [configuring the CI](#configuring)

### For frameworks and libraries
If you want to add _ios-ci_ as a dependency to a **framework or library**, prefer [subtree merging](http://git-scm.com/book/en/Git-Tools-Subtree-Merging). As it will make sure the ci files are bundled with the repo, thus making sure the repo stays intact and doesn’t require users to deal with your submodule.

To add the scripts as a subtree for the first time:

```shell
$ git remote add ios-ci https://github.com/spotify/ios-ci.git
$ git fetch ios-ci
$ git read-tree --prefix=ci/ -u ios-ci/master
$ git reset
```

Then add the files to git as normally and commit.

To bring in upstream changes later:

```shell
$ git fetch -p ios-ci
$ git merge --squash -s subtree --no-commit -Xsubtree=ci/ ios-ci/master
$ git reset
```

You might have to fix some merge conflicts. If so resolve the conflicts like any other git merge conflicts and then `git add` the file to mark it as resolved.

## Configuring
First of all you’ll need to copy the provided sample [`Gemfile`](sample/Gemfile) to the repository root, or append it’s list of gem’s to your existing one. And then update them so the CI system will know which version to use.

```shell
$ cp ci/sample/Gemfile .
$ bundle update
```

Next you should configure Travis-CI.

### Travis-CI
Also have a look at the [travis.yml](sample/travis.yml) file.

The important environment variables you need to have set are:

| **Environment variable**      	| **Description**                                                                            	|
|--------------------------------	|--------------------------------------------------------------------------------------------	|
| `PROJECT_NAME`                  | The name of the project/module, used for deployment.                                       	|
| `PROJECT`                      	| Which Xcode project file to use when building.                                             	|
| `SCHEME`                       	| Which Xcode scheme to use.                                                                 	|
| `BUILD_ACTIONS`                	| The build actions that should be passed to `xcodebuild`, e.g. `build` or `build test`.     	|
| `EXTRA_ARGUMENTS`              	| Any extra argument you want to pass to `xcodebuild`, e.g. `-enableCodeCoverage YES`.       	|
| `TEST_SDK`                     	| The SDK which should be used when build and testing.                                       	|
| `TEST_DEST`                    	| The destination the tests should be ran for.                                               	|
| `PODSPEC`                      	| The path to the project’s [CocoaPods](https://cocoapods.org/) podspec file.                	|
| `EXPECTED_LICENSE_HEADER_FILE` 	| The path to a file containing the license header source files are expected to include.     	|
| `LICENSED_SOURCE_FILES_GLOB`   	| A glob for finding all files which should be checked that they include the license header. 	|

## Contributing :mailbox_with_mail:
Contributions are welcomed, have a look at the [CONTRIBUTING.md](CONTRIBUTING.md) document for more information.

## License :memo:
The project is available under the [Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0) license.
