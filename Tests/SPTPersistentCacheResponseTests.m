// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <XCTest/XCTest.h>
#import "SPTPersistentCacheRecord+Private.h"
#import <SPTPersistentCache/SPTPersistentCacheRecord.h>
#import "SPTPersistentCacheResponse+Private.h"
#import <SPTPersistentCache/SPTPersistentCacheResponse.h>
#import "SPTPersistentCacheObjectDescriptionStyleValidator.h"


static const SPTPersistentCacheResponseCode SPTPersistentCacheResponseTestsTestCode   = SPTPersistentCacheResponseCodeNotFound;

@interface SPTPersistentCacheResponseTests : XCTestCase
@property (nonatomic, strong) SPTPersistentCacheResponse *persistentCacheResponse;
@property (nonatomic, strong) NSError *testError;
@property (nonatomic, strong) SPTPersistentCacheRecord *testCacheRecord;
@end

@implementation SPTPersistentCacheResponseTests

- (void)setUp
{
    [super setUp];
    
    self.testError = [NSError errorWithDomain:@""
                                         code:404
                                     userInfo:nil];
    
    self.testCacheRecord = [[SPTPersistentCacheRecord alloc] init];
    
    self.persistentCacheResponse = [[SPTPersistentCacheResponse alloc] initWithResult:SPTPersistentCacheResponseTestsTestCode
                                                                                error:self.testError
                                                                               record:self.testCacheRecord];
}

- (void)testDesignatedInitializer
{
    XCTAssertEqual(self.persistentCacheResponse.result, SPTPersistentCacheResponseTestsTestCode);
    XCTAssertEqualObjects(self.persistentCacheResponse.error, self.testError);
    XCTAssertEqualObjects(self.persistentCacheResponse.record, self.testCacheRecord);
}

#pragma mark Test describing objects

- (void)testDescriptionAdheresToStyle
{
    SPTPersistentCacheObjectDescriptionStyleValidator *styleValidator = [SPTPersistentCacheObjectDescriptionStyleValidator new];

    NSString * const description = self.persistentCacheResponse.description;

    XCTAssertTrue([styleValidator isValidStyleDescription:description], @"The description string should follow our style.");
}

- (void)testDescriptionContainsClassName
{
    NSString * const description = self.persistentCacheResponse.description;

    const NSRange classNameRange = [description rangeOfString:@"SPTPersistentCacheResponse"];
    XCTAssertNotEqual(classNameRange.location, NSNotFound, @"The class name should exist in the description");
}

- (void)testDebugDescriptionContainsClassName
{
    NSString * const debugDescription = self.persistentCacheResponse.debugDescription;

    const NSRange classNameRange = [debugDescription rangeOfString:@"SPTPersistentCacheResponse"];
    XCTAssertNotEqual(classNameRange.location, NSNotFound, @"The class name should exist in the debugDescription");
}

- (void)testStringFromResponseCodeUniqueness
{
    SPTPersistentCacheResponseCode code = SPTPersistentCacheResponseCodeOperationSucceeded;
    
    NSArray *allResponses;
    
    switch (code) { // Ensure this method includes all states of enum.
        case SPTPersistentCacheResponseCodeOperationSucceeded:
        case SPTPersistentCacheResponseCodeNotFound:
        case SPTPersistentCacheResponseCodeOperationError: {
            allResponses = @[NSStringFromSPTPersistentCacheResponseCode(SPTPersistentCacheResponseCodeOperationSucceeded),
                             NSStringFromSPTPersistentCacheResponseCode(SPTPersistentCacheResponseCodeNotFound),
                             NSStringFromSPTPersistentCacheResponseCode(SPTPersistentCacheResponseCodeOperationError)];
        }
    }
    
    NSSet *uniqueResponses = [NSSet setWithArray:allResponses];
    
    XCTAssertEqual(allResponses.count,
                   uniqueResponses.count,
                   @"Each string for the response codes should be unique.");

}


@end
