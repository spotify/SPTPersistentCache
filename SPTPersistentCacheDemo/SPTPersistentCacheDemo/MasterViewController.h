// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import <UIKit/UIKit.h>

@class DetailViewController;

@interface MasterViewController : UITableViewController

@property (strong, nonatomic) DetailViewController *detailViewController;

@end

