//
//  FileListView.m
//  dreaMote
//
//  Created by Moritz Venn on 05.01.11.
//  Copyright 2011 Moritz Venn. All rights reserved.
//

#import "FileListView.h"

#import "Constants.h"
#import "RemoteConnectorObject.h"
#import "UITableViewCell+EasyInit.h"
#import "PlayListCell.h"

#import "Objects/FileProtocol.h"

@interface FileListView()
- (void)fetchData;
@end

@implementation FileListView

@synthesize fileDelegate = _fileDelegate;
@synthesize reloading = _reloading;
@synthesize files = _files;

- (id)initWithFrame:(CGRect)frame
{
	if((self = [super initWithFrame:frame]))
	{
        self.delegate = self;
		self.dataSource = self;
		self.rowHeight = 38;
		self.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
		self.sectionHeaderHeight = 0;
		self.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);

		_files = [[NSMutableArray alloc] init];
		_playing = NSNotFound;
		_reloading = NO;

		// add header view
		_refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.bounds.size.height, self.bounds.size.width, self.bounds.size.height)];
		_refreshHeaderView.delegate = self;
		[self addSubview:_refreshHeaderView];
    }
    return self;
}

- (void)dealloc
{
	// remove known references to us
	self.delegate = nil;
	self.dataSource = nil;
	_refreshHeaderView.delegate = nil;

	SafeRetainAssign(_path, nil);
	SafeRetainAssign(_files, nil);
	SafeRetainAssign(_fileDelegate, nil);
	SafeRetainAssign(_fileXMLDoc, nil);
	SafeRetainAssign(_refreshHeaderView, nil);
	SafeRetainAssign(_selected, nil);

	[super dealloc];
}

- (NSString *)path
{
	return SafeReturn(_path);
}

- (BOOL)isPlaylist
{
	return _isPlaylist;
}

- (void)setIsPlaylist:(BOOL)isPlaylist
{
	_isPlaylist = isPlaylist;
	self.allowsSelectionDuringEditing = isPlaylist;
}

- (NSMutableArray *)selectedFiles
{
	if(_selected) return SafeReturn(_selected);

	_selected = [[NSMutableArray alloc] init];
	return SafeReturn(_selected);
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	[super setEditing:editing animated:animated];

	// no longer editing in playlist, clean multi-selection
	if(!editing && _isPlaylist)
	{
		if(_selected.count)
		{
			[_selected removeAllObjects]; // not using property here to prevent possibly useless creation of this array

			if(_fileDelegate != nil)
				[_fileDelegate fileListView:self fileMultiSelected:nil];
		}
	}
}

- (void)emptyData
{
	// Free Caches and reload data
	[_files removeAllObjects];
	NSIndexSet *idxSet = [NSIndexSet indexSetWithIndex: 0];
	[self reloadSections:idxSet withRowAnimation:UITableViewRowAnimationRight];
	SafeRetainAssign(_fileXMLDoc, nil);
}

- (void)setPath:(NSString *)new
{
	// Same bouquet assigned, abort
	if([_path isEqualToString: new]) return;
	SafeRetainAssign(_path, new);

	// Free Caches and reload data
	[self emptyData];
	[_refreshHeaderView setTableLoadingWithinScrollView:self];

	// Run this in our "temporary" queue
	[RemoteConnectorObject queueInvocationWithTarget:self selector:@selector(fetchData)];
}

/* start download of file list */
- (void)fetchData
{
	CXMLDocument *newDocument = nil;
	_reloading = YES;
	if(self.isPlaylist)
		newDocument = [[RemoteConnectorObject sharedRemoteConnector] fetchPlaylist:self];
	else
		newDocument = [[RemoteConnectorObject sharedRemoteConnector] fetchFiles:self path:_path];
	SafeRetainAssign(_fileXMLDoc, newDocument);
}

/* select file by name */
- (BOOL)selectPlayingByTitle:(NSString *)filename
{
	NSUInteger idx = 0;
	NSUInteger playing = _playing;
	for(NSObject<FileProtocol> *file in _files)
	{
		if([file.title isEqualToString: filename])
		{
			if(playing != idx)
			{
				NSMutableArray *idxPaths = [NSMutableArray arrayWithObject:[NSIndexPath indexPathForRow:idx inSection:0]];
				if(playing != NSNotFound)
					[idxPaths addObject:[NSIndexPath indexPathForRow:playing inSection: 0]];

				_playing = idx;
				[self reloadRowsAtIndexPaths:idxPaths withRowAnimation:UITableViewRowAnimationFade];
				return YES;
			}
			return NO;
		}
		++idx;
	}
	if(playing != NSNotFound)
	{
		_playing = NSNotFound;
		[self reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:playing inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
		return YES;
	}
	return NO;
}

/* re-download data */
- (void)refreshData
{
	[self emptyData];
	[_refreshHeaderView setTableLoadingWithinScrollView:self];

	// Run this in our "temporary" queue
	[RemoteConnectorObject queueInvocationWithTarget:self selector:@selector(fetchData)];
}

/* remove file from list */
- (void)removeFile:(NSObject<FileProtocol> *)file
{
	NSInteger idx = [_files indexOfObject:file];
	NSIndexPath *path = [NSIndexPath indexPathForRow:idx inSection:0];
	if(idx != NSNotFound)
	{
		[_files removeObjectAtIndex:idx];
		[self deleteRowsAtIndexPaths:[NSArray arrayWithObject:path] withRowAnimation:UITableViewRowAnimationFade];
	}
	else
	{
#if IS_DEBUG()
		[NSException raise:@"FileListViewInconsistent" format:@"tried to remove file (%@, %@) which was not found in our list, %@", file.root, file.sref, _reloading ? @"was reloading" : @"not reloading"];
#endif
		NSLog(@"ignoring attempted removal of file which (no longer) exists in our list");
	}
}

/* get list of files */
- (void)getFiles
{
	if(_isPlaylist) return;

	for(NSObject<FileProtocol> *file in _files)
	{
		// file is no directory, just add
		if(!file.isDirectory)
		{
			[_fileDelegate fileListView:self fileSelected:file];
		}
	}
}

#pragma mark -
#pragma mark DataSourceDelegate
#pragma mark -

- (void)dataSourceDelegate:(BaseXMLReader *)dataSource errorParsingDocument:(CXMLDocument *)document error:(NSError *)error
{
	_reloading = NO;
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self];
	[self reloadData];

	// only show alert if in front
	if([self superview])
	{
		const UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failed to retrieve data", @"Title of Alert when retrieving remote data failed.")
															  message:[error localizedDescription]
															 delegate:nil
													cancelButtonTitle:@"OK"
													otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}

- (void)dataSourceDelegate:(BaseXMLReader *)dataSource finishedParsingDocument:(CXMLDocument *)document
{
	_reloading = NO;
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self];
#if INCLUDE_FEATURE(Extra_Animation)
	[self reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
#else
	[self reloadData];
#endif
	if(_isPlaylist && _playing != NSNotFound && _playing < (NSInteger)_files.count)
	{
		[self scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_playing inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	}
}

#pragma mark -
#pragma mark FileSourceDelegate
#pragma mark -

/* add file to list */
- (void)addFile: (NSObject<FileProtocol> *)file
{
	[_files addObject: file];
#if INCLUDE_FEATURE(Extra_Animation) && defined(ENABLE_LAGGY_ANIMATIONS)
	[self insertRowsAtIndexPaths: [NSArray arrayWithObject: [NSIndexPath indexPathForRow:[_files count]-1 inSection:0]]
				withRowAnimation: UITableViewRowAnimationTop];
#endif
}

#pragma mark	-
#pragma mark	UITableView delegate methods
#pragma mark	-

/* create cell for given row */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = nil;
	if(_isPlaylist)
		cell = [PlayListCell reusableTableViewCellInView:tableView withIdentifier:kPlayListCell_ID];
	else
		cell = [UITableViewCell reusableTableViewCellInView:tableView withIdentifier:kVanilla_ID];

	TABLEVIEWCELL_FONT(cell) = [UIFont boldSystemFontOfSize:kTextViewFontSize-1];
	NSObject<FileProtocol> *file = [_files objectAtIndex:indexPath.row];
	TABLEVIEWCELL_TEXT(cell) = file.title;

	if(file.valid)
	{
		if(_isPlaylist)
		{
			if(indexPath.row == _playing)
				TABLEVIEWCELL_IMAGE(cell) = [UIImage imageNamed:@"audio-volume-high.png"];
			else
				TABLEVIEWCELL_IMAGE(cell) = nil;

			if([_selected containsObject:file])
				[(PlayListCell *)cell setMultiSelected:YES animated:NO];
		}
		else
		{
			if(file.isDirectory)
				TABLEVIEWCELL_IMAGE(cell) = [UIImage imageNamed:@"folder.png"];
			else
				TABLEVIEWCELL_IMAGE(cell) = [UIImage imageNamed:@"audio-x-generic.png"];
		}
	}
	else
		TABLEVIEWCELL_IMAGE(cell) = nil;

	return cell;
}

/* select row */
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	// do nothing if reloading
	if(_reloading)
	{
#if IS_DEBUG()
		[NSException raise:@"FileListViewUserInteractionWhileReloading" format:@"willSelectRowAtIndexPath was triggered for indexPath (section %d, row %d) while reloading", indexPath.section, indexPath.row];
#endif
		return nil;
	}

	// See if we have a valid file
	NSObject<FileProtocol> *file = SafeReturn([_files objectAtIndex:indexPath.row]);
	if(!file.valid)
		return nil;
	// if we're in playlist mode and we have a delegate call it back
	else if(_isPlaylist)
	{
		if(self.editing)
		{
			UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
			BOOL selected = [(PlayListCell *)cell toggleMultiSelected];

			if(selected)
				[self.selectedFiles addObject:file];
			else
				[self.selectedFiles removeObject:file];

			if(_fileDelegate != nil)
				[_fileDelegate fileListView:self fileMultiSelected:file];
		}
		else if(_fileDelegate != nil)
			[_fileDelegate fileListView:self fileSelected:file];
		return nil;
	}
	// change current folder or ask what to do with file
	else
	{
		if(file.isDirectory)
		{
			self.path = file.sref;
			return nil;
		}
		else if(_fileDelegate != nil)
			[_fileDelegate fileListView:self fileSelected:file];
	}
	return indexPath;
}

/* edit action */
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(!_isPlaylist) return;
	NSObject<FileProtocol> *file = [_files objectAtIndex: indexPath.row];
	[_fileDelegate fileListView:self fileRemoved:file];
}

/* row selected */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

/* editing style */
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return (self.editing || !_isPlaylist) ? UITableViewCellEditingStyleNone : UITableViewCellEditingStyleDelete;
}

/* number of sections */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

/* number of rows */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [_files count];
}

#pragma mark -
#pragma mark UIScrollViewDelegate Methods
#pragma mark -

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	[_refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	[_refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
}

#pragma mark -
#pragma mark EGORefreshTableHeaderDelegate Methods
#pragma mark -

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view
{
	[self refreshData];
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view
{
	return _reloading;
}

@end
