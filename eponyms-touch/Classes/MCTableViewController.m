//
//  MCTableViewController.m
//  medcalc
//
//  Created by Pascal Pfiffner on 09.01.10.
//	Copyright 2010 MedCalc. All rights reserved.
//	This sourcecode is released under the Apache License, Version 2.0
//	http://www.apache.org/licenses/LICENSE-2.0.html/
//  
//  A tableviewcontroller that can save its state automatically. Uses TouchTableView instead of UITableView.
//  

#import "MCTableViewController.h"
#import "TouchTableView.h"

#define kMCTVCStateSaveMask @"MCTVC_lastState_%@"


@interface MCTableViewController ()

- (NSString *) stateSaveName;
- (void) registerForKeyboardNotifications;
- (void) forgetAboutKeyboardNotifications;
- (void) keyboardWillShow:(NSNotification*)aNotification;
- (void) keyboardWillHide:(NSNotification*)aNotification;

@end



@implementation MCTableViewController

@synthesize tableStyle;
@dynamic tableView;
@dynamic noDataHint;


- (void) dealloc
{
	self.tableView = nil;
	[noDataHint release];
	
	[super dealloc];
}

- (void) viewDidUnload
{
	self.tableView = nil;
	
	[super viewDidUnload];
}


- (id) init
{
	return [self initWithStyle:UITableViewStylePlain];
}

- (id) initWithStyle:(UITableViewStyle)style
{
	if (self = [super initWithNibName:nil bundle:nil]) {
		tableStyle = style;
	}
	return self;
}

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if (self = [super initWithNibName:nil bundle:nil]) {		// check whether this can be improved when loading from XIBs
		tableStyle = UITableViewStylePlain;
	}
	return self;
}
#pragma mark -



#pragma mark KVC
- (TouchTableView *) tableView
{
	return tableView;
}
- (void) setTableView:(TouchTableView *)newTableView
{
	if (newTableView != tableView) {
		tableView = newTableView;
		self.tableView = newTableView;
		
		if (nil != tableView && nil != noDataHint) {
			tableView.noDataHint = noDataHint;
		}
	}
}
#pragma mark -



#pragma mark View Tasks
- (void) loadView
{
	// create the table
	CGRect availRect = [[UIScreen mainScreen] applicationFrame];
	if (nil != self.tabBarController) {
		CGRect tabBarRect = [self.tabBarController tabBar].bounds;
		availRect.size.height -= tabBarRect.size.height;
	}
	
	self.tableView = [[[TouchTableView alloc] initWithFrame:availRect style:tableStyle] autorelease];
	tableView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	tableView.autoresizesSubviews = YES;
	
	tableView.delegate = self;
	tableView.dataSource = self;
	
	self.view = tableView;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	if (shouldShowDataHintAfterLoading) {
		[self showNoDataHintAnimated:NO];
		shouldShowDataHintAfterLoading = NO;
	}
}

- (void) viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self registerForKeyboardNotifications];
	
	NSIndexPath *selectedRow = [tableView indexPathForSelectedRow];
	if (selectedRow) {
		[tableView deselectRowAtIndexPath:selectedRow animated:animated];
	}
}

- (void) viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self forgetAboutKeyboardNotifications];
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated
{
	[tableView setEditing:editing animated:animated];
	[super setEditing:editing animated:animated];
}
#pragma mark -



#pragma mark No Data Hint
- (NSString *) noDataHint
{
	return noDataHint;
}
- (void) setNoDataHint:(NSString *)newHint
{
	if (newHint != noDataHint) {
		[noDataHint release];
		noDataHint = [newHint copy];
		
		if (nil != tableView) {
			tableView.noDataHint = noDataHint;
		}
	}
}

- (void) showNoDataHintAnimated:(BOOL)animated
{
	if ([self isViewLoaded]) {
		[tableView showNoDataLabelAnimated:animated];
	}
	else {
		shouldShowDataHintAfterLoading = YES;
	}
}

- (void) hideNoDataHintAnimated:(BOOL)animated
{
	[tableView hideNoDataLabelAnimated:animated];
}
#pragma mark -



#pragma mark Data Source
- (NSInteger) tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
	return 0;
}

- (UITableViewCell *) tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return nil;
}
#pragma mark -



#pragma mark State saving and restoring
- (NSString *) stateSaveName
{
	return [NSString stringWithFormat:kMCTVCStateSaveMask, autosaveName];
}

- (NSDictionary *) currentState
{
	if ([self isViewLoaded]) {
		
		// get scroll position
		NSNumber *scrollPos = [NSNumber numberWithFloat:self.tableView.contentOffset.y];
		NSDictionary *state = [NSDictionary dictionaryWithObject:scrollPos forKey:@"scrollPosition"];
		return state;
	}
	return nil;
}

- (void) setStateTo:(NSDictionary *)state
{
	if ([state isKindOfClass:[NSDictionary class]]) {
		NSNumber *scrollPos = [state objectForKey:@"scrollPosition"];
		if (nil != scrollPos) {
			self.tableView.contentOffset = CGPointMake(0.f, [scrollPos floatValue]);
		}
	}
}
#pragma mark -



#pragma mark UIKeyboardNotifications
- (void) registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillShow:)
												 name:UIKeyboardWillShowNotification object:nil];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillHide:)
												 name:UIKeyboardWillHideNotification object:nil];
}

- (void) forgetAboutKeyboardNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}


- (void) keyboardWillShow:(NSNotification*)aNotification
{
	NSDictionary *info = [aNotification userInfo];
	NSValue *boundsValue = [info objectForKey:UIKeyboardBoundsUserInfoKey];			// deprecated as of iOS 3.2. Use UIKeyboardFrameEndUserInfoKey some time
	CGSize keyboardSize = [boundsValue CGRectValue].size;
	
	// Resize the table view view
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationBeginsFromCurrentState:YES];
	
	CGRect viewFrame = [self.tableView frame];
	viewFrame.size.height -= keyboardSize.height;
	self.tableView.frame = viewFrame;
	
	[UIView commitAnimations];
}


- (void) keyboardWillHide:(NSNotification*)aNotification
{
	NSDictionary* info = [aNotification userInfo];
	NSValue* boundsValue = [info objectForKey:UIKeyboardBoundsUserInfoKey];			// deprecated as of iOS 3.2. Use UIKeyboardFrameEndUserInfoKey some time
	CGSize keyboardSize = [boundsValue CGRectValue].size;
	
	// adjust table view height to full height again
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationBeginsFromCurrentState:YES];
	
	CGRect viewFrame = [self.tableView frame];
	viewFrame.size.height += keyboardSize.height;
	self.tableView.frame = viewFrame;
	
	[UIView commitAnimations];
}


@end
