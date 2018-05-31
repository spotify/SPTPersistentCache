/*
 * Copyright (c) 2018 Spotify AB.
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
#import "MasterViewController.h"

#import <SPTPersistentCache/SPTPersistentCache.h>

#import "DetailViewController.h"

@interface MasterViewController () <UIAlertViewDelegate>

@property (nonatomic, strong) NSMutableArray *objects;
@property (nonatomic, strong) SPTPersistentCache *cache;

@end

@implementation MasterViewController

#pragma mark UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.objects = [NSMutableArray new];
    NSString *cacheIdentifier = @"com.spotify.demo.image.cache";
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                               NSUserDomainMask,
                                                               YES).firstObject stringByAppendingString:cacheIdentifier];
    
    SPTPersistentCacheOptions *options = [SPTPersistentCacheOptions new];
    options.cachePath = cachePath;
    options.cacheIdentifier = cacheIdentifier;
    options.defaultExpirationPeriod = 60 * 60 * 24 * 30;
    options.garbageCollectionInterval = (NSUInteger)(1.5 * SPTPersistentCacheDefaultGCIntervalSec);
    options.sizeConstraintBytes = 1024 * 1024 * 10; // 10 MiB
    options.debugOutput = ^(NSString *string) {
        NSLog(@"%@ %@", @(__PRETTY_FUNCTION__), string);
    };

    self.cache = [[SPTPersistentCache alloc] initWithOptions:options];
    self.navigationItem.leftBarButtonItem = self.editButtonItem;

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                               target:self
                                                                               action:@selector(addButtonAction:)];
    self.navigationItem.rightBarButtonItem = addButton;
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
}

- (void)viewWillAppear:(BOOL)animated
{
    self.clearsSelectionOnViewWillAppear = self.splitViewController.isCollapsed;
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark UIBarButtonItem

- (void)addButtonAction:(UIBarButtonItem *)addButton
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Image"
                                                        message:@"Add an image:"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"OK", nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alertView show];
}

#pragma mark UIStoryboardSegue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSString *object = self.objects[(NSUInteger)indexPath.row];
        DetailViewController *controller = (DetailViewController *)[[segue destinationViewController] topViewController];
        controller.persistentDataCache = self.cache;
        [controller setDetailItem:object];
        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
    }
}

#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.objects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    NSDate *object = self.objects[(NSUInteger)indexPath.row];
    cell.textLabel.text = [object description];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSUInteger row = (NSUInteger)indexPath.row;

        [self.cache removeDataForKeys:@[ self.objects[row] ] callback:nil onQueue:nil];
        [self.objects removeObjectAtIndex:row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }
}

#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *imageURL = [alertView textFieldAtIndex:0].text;
    if (!imageURL.length) {
        return;
    }
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    NSURL *url = [NSURL URLWithString:imageURL];

    NSAssert(url != nil, @"Couldn’t create a wellformed URL from the image URL string \"%@\"", imageURL);

    [[session dataTaskWithURL:url
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                [self.cache storeData:data
                               forKey:[NSString stringWithFormat:@"%lu", (unsigned long)imageURL.hash]
                               locked:YES
                         withCallback:^(SPTPersistentCacheResponse *cacheResponse) {
                             NSLog(@"cacheResponse = %@", cacheResponse);
                         } onQueue:dispatch_get_main_queue()];
                dispatch_async(dispatch_get_main_queue(), ^ {
                    [self.objects insertObject:imageURL atIndex:0];
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
                    [self.tableView insertRowsAtIndexPaths:@[ indexPath ]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                });
            }] resume];
}

@end
