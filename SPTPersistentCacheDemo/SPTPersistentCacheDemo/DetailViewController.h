// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <UIKit/UIKit.h>

@class SPTPersistentCache;

@interface DetailViewController : UIViewController

@property (nonatomic, strong) SPTPersistentCache *persistentDataCache;
@property (strong, nonatomic) NSObject *detailItem;
@property (nonatomic, weak, readwrite) IBOutlet UIImageView *detailImageView;

@end

