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
#import "MainWindowController.h"
#import <SPTPersistentCache/SPTPersistentCache.h>

@interface MainWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSMutableArray *cacheFiles;

@property (nonatomic, strong) NSString *magic;
@property (nonatomic, strong) NSString *headerSize;
@property (nonatomic, strong) NSString *payloadSize;
@property (nonatomic, strong) NSString *crc;
@property (nonatomic, strong) NSString *updateTime;
@property (nonatomic, strong) NSString *ttl;
@property (nonatomic, strong) NSString *refCount;
@property (nonatomic, strong) NSString *hrUpdateTime;
@property (nonatomic, strong) NSString *imageSize;

@property (nonatomic, strong) NSURL *cacheURL;
@property (nonatomic, strong) NSData *payload;
@property (nonatomic, strong) id object;
@property (nonatomic, strong) NSImageView *imageView;

@property (nonatomic, weak) IBOutlet NSTableView *tableView;
@property (nonatomic, weak) IBOutlet NSView *containerView;

@end

@implementation MainWindowController
{
    SPTPersistentCacheRecordHeader _currHeader;
    BOOL _crcValid;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    if (self.imageView == nil) {
        self.imageView = [[NSImageView alloc] initWithFrame:CGRectMake(319, 20, 357, 357)];
        self.imageView.imageFrameStyle = NSImageFramePhoto;
        [self.containerView addSubview:self.imageView];
    }
}

- (void)dealloc
{
}

#pragma mark - Menu items
- (void)openDocument:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = NO;
    panel.canCreateDirectories = NO;
    panel.showsHiddenFiles = YES;
    panel.message = @"Select cache folder";
    panel.directoryURL = self.cacheURL;

    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (NSFileHandlingPanelCancelButton == result) {
            return;
        }

        [panel orderOut:self.window];

        self.cacheURL = panel.URL;
        [self loadFilesAtURL:panel.URL];
    }];
}

- (void)reload:(id)sender
{
    [self loadFilesAtURL:self.cacheURL];
}

-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if (menuItem.tag == 2)
        return self.cacheURL != nil;

    return YES;
}

- (void)loadFilesAtURL:(NSURL *)url
{
    NSError *error = nil;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url
                                                   includingPropertiesForKeys:nil
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                        error:&error];
    if (files == nil) {
        [NSApp presentError:error];
        return;
    }

    self.cacheFiles = [files mutableCopy];
    [self.tableView reloadData];
}

#pragma mark - TableView datasource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.cacheFiles count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return [[[self.cacheFiles objectAtIndex:row] pathComponents] lastObject];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    NSInteger idx = [self.tableView selectedRow];
    if (idx == -1) {
        // TODO: clear fields
        return;
    }

    NSString *fullFilePath = [self.cacheFiles objectAtIndex:idx];
    NSData *rawData = [NSData dataWithContentsOfFile:fullFilePath];

    SPTPersistentCacheRecordHeader *h = SPTPersistentCacheGetHeaderFromData(__DECONST(void*, [rawData bytes]), [rawData length]);

    if (h == NULL) {
        // TODO: error
        return;
    }

    if (-1 != SPTPersistentCacheValidateHeader(h)) {
        // TODO: error
        return;
    }

    memcpy(&_currHeader, h, SPTPersistentCacheRecordHeaderSize);

    self.magic = [NSString stringWithFormat:@"0x%X", _currHeader.magic];
    self.headerSize = [NSString stringWithFormat:@"%u", _currHeader.headerSize];
    self.payloadSize = [NSString stringWithFormat:@"%llu", _currHeader.payloadSizeBytes];
    self.crc = [NSString stringWithFormat:@"0x%X", _currHeader.crc];
    self.updateTime = [NSString stringWithFormat:@"%llu", _currHeader.updateTimeSec];
    self.ttl = [NSString stringWithFormat:@"%llu", _currHeader.ttl];
    self.refCount = [NSString stringWithFormat:@"%d", _currHeader.refCount];
    self.hrUpdateTime = [NSDateFormatter localizedStringFromDate:[NSDate dateWithTimeIntervalSince1970:_currHeader.updateTimeSec]
                                                       dateStyle:NSDateFormatterMediumStyle
                                                       timeStyle:NSDateFormatterLongStyle];

    NSRange payloadRange = NSMakeRange(SPTPersistentCacheRecordHeaderSize, _currHeader.payloadSizeBytes);
    self.payload = [rawData subdataWithRange:payloadRange];

    self.object = [[NSImage alloc] initWithData:self.payload];

    self.imageView.image = self.object;
    self.imageSize = NSStringFromSize([self.object size]);
}

@end
