// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

#import "DetailViewController.h"

#import <SPTPersistentCache/SPTPersistentCache.h>
#import <SPTPersistentCache/SPTPersistentCacheResponse.h>
#import <SPTPersistentCache/SPTPersistentCacheRecord.h>

@interface DetailViewController ()

@end

@implementation DetailViewController

#pragma mark DetailViewController

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
            
        // Update the view.
        [self configureView];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.
    if (self.detailItem) {
        [self.persistentDataCache loadDataForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[self.detailItem hash]]
                                    withCallback:^(SPTPersistentCacheResponse *response) {
                                        if (response.result != SPTPersistentCacheResponseCodeOperationSucceeded) {
                                            NSLog(@"Failed: %@", response.error);
                                            return;
                                        }
                                        NSData *imageData = response.record.data;
                                        self.detailImageView.image = [UIImage imageWithData:imageData];
                                    }
                                         onQueue:dispatch_get_main_queue()];
    }
}

#pragma mark UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self configureView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
