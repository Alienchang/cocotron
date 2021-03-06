/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <AppKit/NSPopUpButtonCell.h>
#import <AppKit/NSMenu.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSGraphicsStyle.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSPopUpWindow.h>
#import <Foundation/NSKeyedArchiver.h>
#import <AppKit/NSRaise.h>

@implementation NSPopUpButtonCell

-(void)encodeWithCoder:(NSCoder *)coder {
   NSUnimplementedMethod();
}

-initWithCoder:(NSCoder *)coder {
   [super initWithCoder:coder];

   if([coder allowsKeyedCoding]){ 
    _pullsDown=[coder decodeBoolForKey:@"NSPullDown"];
    _menu=[[coder decodeObjectForKey:@"NSMenu"] retain];
    _selectedIndex=[[_menu itemArray] indexOfObjectIdenticalTo:[coder decodeObjectForKey:@"NSMenuItem"]];
    
    if(_selectedIndex<0 && [_menu itemArray]>0)
     _selectedIndex=0;
	 
	 _arrowPosition = [coder decodeIntForKey: @"NSArrowPosition"];
	 _preferredEdge = [coder decodeIntForKey: @"NSPreferredEdge"];
   }
   else {
    [NSException raise:NSInvalidArgumentException format:@"%@ can not initWithCoder:%@",isa,[coder class]];
   }
   return self;
}

-(void)awakeFromNib {
}


-copyWithZone:(NSZone *)zone {
    NSPopUpButtonCell *copy = [super copyWithZone:zone];

    copy->_menu = [_menu copy];

    return copy;
}

-initTextCell:(NSString *)string pullsDown:(BOOL)pullDown
{
    [super initTextCell:string];
    _menu = [[NSMenu alloc] initWithTitle:string];
    [_menu addItemWithTitle:string action:[self action] keyEquivalent:@""];
        
    [self setPullsDown:pullDown];
    
    return self;
}

-(void)dealloc {
   [_menu release];
   [super dealloc];
}

-(BOOL)pullsDown
{
    return _pullsDown;
}

-(NSMenu *)menu
{
    return _menu;
}

-(NSRectEdge)preferredEdge
{
	return _preferredEdge;
}

-(void)setPreferredEdge:(NSRectEdge)edge
{
	edge = _preferredEdge;
}

-(NSArray *)itemArray {
   return [_menu itemArray];
}

-(int)numberOfItems {
   return [_menu numberOfItems];
}

-(NSMenuItem *)itemAtIndex:(int)index {
   return [_menu itemAtIndex:index];
}

- (NSMenuItem *)lastItem {
   return [_menu itemAtIndex:[_menu numberOfItems]-1];
}

-(NSMenuItem *)itemWithTitle:(NSString *)title {
   return [_menu itemWithTitle:title];
}

-(int)indexOfItemWithTitle:(NSString *)title {
   return [_menu indexOfItemWithTitle:title];
}

-(int)indexOfItemWithTag:(int)tag {
   return [_menu indexOfItemWithTag:tag];
}

-(NSMenuItem *)selectedItem {
   return [_menu itemAtIndex:_selectedIndex];
}

-(NSString *)titleOfSelectedItem {
   return [[self selectedItem] title];
}

-(int)indexOfSelectedItem {
   return _selectedIndex;
}

-(void)setPullsDown:(BOOL)flag
{
    _pullsDown = flag;
}

-(void)setMenu:(NSMenu *)menu
{
    menu = [menu retain];
    [_menu release];
    _menu = menu;
}

-(void)addItemWithTitle:(NSString *)title {
   [_menu addItemWithTitle:title action:NULL keyEquivalent:nil];
}

-(void)addItemsWithTitles:(NSArray *)titles {
   int i,count=[titles count];

   for(i=0;i<count;i++)
    [self addItemWithTitle:[titles objectAtIndex:i]];
}

-(void)removeAllItems {
   [_menu removeAllItems];
}

-(void)removeItemAtIndex:(int)index {
   [_menu removeItemAtIndex:index];
}

-(void)insertItemWithTitle:(NSString *)title atIndex:(int)index {
   [_menu insertItemWithTitle:title action:NULL keyEquivalent:nil atIndex:index];
}

-(NSImage *)arrowImage {
   if(_pullsDown)
    return [NSImage imageNamed:@"NSPopUpButtonCellPullDown"];
   else
    return [NSImage imageNamed:@"NSPopUpButtonCellPopUp"];
}

-(void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)controlView {
	NSRect fakeFrame = frame;
	NSImage * arrowImage = ( _arrowPosition != NSPopUpNoArrow ) ? [self arrowImage] : NULL;
	
	if( _arrowPosition == NSPopUpArrowAtBottom )
	{
		// For ONLY this arrow position, we adjust the frame to exclude the arrow we're going to draw afterwards
		fakeFrame.size.width -= [arrowImage size].width + 4;		
	}
	
	[super drawInteriorWithFrame: fakeFrame inView: controlView];
	
	// Now draw the arrow
    if( _arrowPosition != NSPopUpNoArrow )
	{
		NSRect otherFrame = frame;
		NSSize arrowSize = [arrowImage size];
		otherFrame.origin.x += otherFrame.size.width - ( arrowSize.width + 2 );
		otherFrame.origin.y += ( otherFrame.size.height - arrowSize.height ) / 2;
		otherFrame.size =  arrowSize;
		[[controlView graphicsStyle] drawButtonImage:arrowImage inRect:otherFrame enabled:YES mixed:YES];
	}
}

-(void)selectItemAtIndex:(int)index {
	[self willChangeValueForKey:@"selectedItem"];
   _selectedIndex=index;
	[self didChangeValueForKey:@"selectedItem"];
}

-(void)selectItemWithTitle:(NSString *)title {
   [self selectItemAtIndex:[self indexOfItemWithTitle:title]];
}

-(NSCellImagePosition)imagePosition {
   return NSImageRight;
}

-(NSString *)title {
   NSArray *items=[_menu itemArray];

   if(_selectedIndex<0 || _selectedIndex>=[items count])
    return @"**ERROR**";

   if(_pullsDown)
    return [[items objectAtIndex:0] title];
   else
    return [[items objectAtIndex:_selectedIndex] title];
}

-(int)tag {
   return [[_menu itemAtIndex:_selectedIndex] tag];
}

-(BOOL)trackMouse:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)flag {
   NSPopUpWindow *window;
   NSPoint        origin=[controlView bounds].origin;
   
#if 0
   // Note: the min options don't mean much unless we don't have room for the menu, so either way we just pop
   // up over the button itself. However, maxX and maxY *do* have special meanings
   switch( _preferredEdge )
   {
      case NSMinXEdge:
      case NSMinYEdge:
	     break;
	  case NSMaxXEdge:
		 origin.x += [controlView bounds].size.width;
	     break;
	  case NSMaxYEdge: 
         // Remember, our Y axis is flipped in Cocoa. Also, not sure why we need the -4 offset here, 
		 // can't figure out where the offset comes from, but it works			
		 origin.y -= [controlView bounds].size.height - 4;
	     break;
   }
#endif
  
   origin=[controlView convertPoint:origin toView:nil];
   origin=[[controlView window] convertBaseToScreen:origin];

   window=[[NSPopUpWindow alloc] initWithFrame:NSMakeRect(origin.x,origin.y,
     cellFrame.size.width,cellFrame.size.height)];
   [window setMenu:_menu];
   if([self font]!=nil)
    [window setFont:[self font]];

   if(_pullsDown)
    [window selectItemAtIndex:0];
   else
    [window selectItemAtIndex:_selectedIndex];

   int itemIndex=[window runTrackingWithEvent:event];
   if(itemIndex!=NSNotFound)
	[self selectItemAtIndex:itemIndex];

   [window close]; // release when closed=YES

   return YES;
}

- (void)moveUp:(id)sender {
    int index = [self indexOfSelectedItem];
    
    if (index > 0)
        [self selectItemAtIndex:index-1];
}

- (void)moveDown:(id)sender {
    int index = [self indexOfSelectedItem];
    
    if (index < [self numberOfItems]-1)
        [self selectItemAtIndex:index+1];
}

@end
