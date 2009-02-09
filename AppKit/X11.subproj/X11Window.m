/* Copyright (c) 2008 Johannes Fortmann
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <AppKit/X11Window.h>
#import <AppKit/NSWindow.h>
#import <AppKit/X11Display.h>
#import <X11/Xutil.h>
#import <AppKit/CairoContext.h>

@implementation X11Window

-initWithFrame:(NSRect)frame styleMask:(unsigned)styleMask isPanel:(BOOL)isPanel backingType:(NSUInteger)backingType;
{
   if(self=[super init])
	{
      _deviceDictionary=[NSMutableDictionary new];
      _dpy=[(X11Display*)[NSDisplay currentDisplay] display];
      int s = DefaultScreen(_dpy);
      _frame=[self transformFrame:frame];
      _window = XCreateSimpleWindow(_dpy, DefaultRootWindow(_dpy),
                              _frame.origin.x, _frame.origin.y, _frame.size.width, _frame.size.height, 
                              1, 0, 0);

      XSelectInput(_dpy, _window, ExposureMask | KeyPressMask | KeyReleaseMask | StructureNotifyMask |
      ButtonPressMask | ButtonReleaseMask | ButtonMotionMask | PointerMotionMask | VisibilityChangeMask | FocusChangeMask);
      
      XSetWindowAttributes xattr;
      unsigned long xattr_mask;
      xattr.override_redirect= styleMask == NSBorderlessWindowMask ? True : False;
      xattr_mask = CWOverrideRedirect;
      
      XChangeWindowAttributes(_dpy, _window, xattr_mask, &xattr);
      XMoveWindow(_dpy, _window, _frame.origin.x, _frame.origin.y);
      
      Atom atm=XInternAtom(_dpy, "WM_DELETE_WINDOW", False);
      XSetWMProtocols(_dpy, _window, &atm , 1);
      
      [(X11Display*)[NSDisplay currentDisplay] setWindow:self forID:_window];
      [self sizeChanged];
      
      if(styleMask == NSBorderlessWindowMask)
      {
         [isa removeDecorationForWindow:_window onDisplay:_dpy];
      }
   }
   return self;
}

-(void)dealloc {
   [self invalidate];
   [_backingContext release];
   [_cgContext release];
   [_deviceDictionary release];   
   [super dealloc];
}

+(void)removeDecorationForWindow:(Window)w onDisplay:(Display*)dpy
{
   return;
   struct {
      unsigned long flags;
      unsigned long functions;
      unsigned long decorations;
      long input_mode;
      unsigned long status;
   } hints = {
      2, 0, 0, 0, 0,
   };
   XChangeProperty (dpy, w,
                    XInternAtom (dpy, "_MOTIF_WM_HINTS", False),
                    XInternAtom (dpy, "_MOTIF_WM_HINTS", False),
                    32, PropModeReplace,
                    (const unsigned char *) &hints,
                    sizeof (hints) / sizeof (long));
}

-(void)ensureMapped
{
   if(!_mapped)
   {
      [_cgContext release];
      
      XMapWindow(_dpy, _window);
      _mapped=YES;
      _cgContext = [[CairoContext alloc] initWithWindow:self];
   }
}


-(void)setDelegate:delegate {
   _delegate=delegate;
}

-delegate {
   return _delegate;
}

-(void)invalidate {
   _delegate=nil;
   [_cgContext release];
   _cgContext=nil;

   if(_window) {
      [(X11Display*)[NSDisplay currentDisplay] setWindow:nil forID:_window];
      XDestroyWindow(_dpy, _window);
      _window=0;
   }
}


-(KGContext *)cgContext {
   if(!_backingContext)
   {
      _backingContext=[[CairoContext alloc] initWithSize:_frame.size];
   }
   
   return _backingContext;
}


-(void)setTitle:(NSString *)title {
   XTextProperty prop;
   const char* text=[title cString];
   XStringListToTextProperty((char**)&text, 1, &prop);
   XSetWMName(_dpy, _window, &prop);
}

-(void)setFrame:(NSRect)frame {
   frame=[self transformFrame:frame];
   XMoveResizeWindow(_dpy, _window, frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
   [_cgContext setSize:[self frame].size];
   [_backingContext setSize:[self frame].size];
 }


-(void)showWindowForAppActivation:(NSRect)frame {
   NSUnimplementedMethod();
}

-(void)hideWindowForAppDeactivation:(NSRect)frame {
   NSUnimplementedMethod();
}


-(void)hideWindow {
   XUnmapWindow(_dpy, _window);
   _mapped=NO;
   [_cgContext release];
   _cgContext=nil;
}


-(void)placeAboveWindow:(X11Window *)other {
   [self ensureMapped];

   if(!other) {
      XRaiseWindow(_dpy, _window);
   }
   else {
      Window w[2]={_window, other->_window};
      XRestackWindows(_dpy, w, 1);
   }
}

-(void)placeBelowWindow:(X11Window *)other {
   [self ensureMapped];

   if(!other) {
      XLowerWindow(_dpy, _window);
   }
   else {
      Window w[2]={other->_window, _window};
      XRestackWindows(_dpy, w, 1);
   }
}

-(void)makeKey {
   [self ensureMapped];
   XRaiseWindow(_dpy, _window);
}

-(void)captureEvents {
   // FIXME: find out what this is supposed to do
}

-(void)miniaturize {
   NSUnimplementedMethod();

}

-(void)deminiaturize {
   NSUnimplementedMethod();
}

-(BOOL)isMiniaturized {
   return NO;
}


-(void)flushBuffer {
   [_cgContext copyFromBackingContext:_backingContext];
}


-(NSPoint)mouseLocationOutsideOfEventStream {
   NSUnimplementedMethod();
   return NSZeroPoint;
}




-(NSRect)frame
{
   return [self transformFrame:_frame];
}

-(void)frameChanged
{
   Window root, parent;
   Window window=_window;
   int x, y;
   unsigned int w, h, d, b, nchild;
   Window* children;
   NSRect rect=NSZeroRect;
   // recursively get geometry to get absolute position
   while(window) {
      XGetGeometry(_dpy, window, &root, &x, &y, &w, &h, &b, &d);
      XQueryTree(_dpy, window, &root, &parent, &children, &nchild);
      if(children)
         XFree(children);

      // first iteration: save our own w, h
      if(window==_window)
         rect=NSMakeRect(0, 0, w, h);
      rect.origin.x+=x;
      rect.origin.y+=y;
      window=parent;
   };

   _frame=rect;
   [self sizeChanged];
}

-(void)sizeChanged
{
   [_cgContext setSize:_frame.size];
   [_backingContext setSize:_frame.size];
}

-(Visual*)visual
{
   return DefaultVisual(_dpy, DefaultScreen(_dpy));
}

-(Drawable)drawable
{
   return _window;
}

-(void)addEntriesToDeviceDictionary:(NSDictionary *)entries 
{
   [_deviceDictionary addEntriesFromDictionary:entries];
}

-(NSRect)transformFrame:(NSRect)frame
{
   return NSMakeRect(frame.origin.x, DisplayHeight(_dpy, DefaultScreen(_dpy)) - frame.origin.y - frame.size.height, frame.size.width, frame.size.height);
}

-(NSPoint)transformPoint:(NSPoint)pos;
{
   return NSMakePoint(pos.x, _frame.size.height-pos.y);
}

-(unsigned int)modifierFlagsForState:(unsigned int)state {
   unsigned int ret=0;
   if(state & ShiftMask)
      ret|=NSShiftKeyMask;
   if(state & ControlMask)
      ret|=NSControlKeyMask;
   if(state & Mod2Mask)
      ret|=NSCommandKeyMask;
   // TODO: alt doesn't work; might want to track key presses/releases instead
   return ret;
}


-(void)handleEvent:(XEvent*)ev fromDisplay:(X11Display*)display {
   static id lastFocusedWindow=nil;
   static NSTimeInterval lastClickTimeStamp=0.0;
   static int clickCount=0;
   
   switch(ev->type) {
      case DestroyNotify:
      {
         // we should never get this message before the WM_DELETE_WINDOW ClientNotify
         // so normally, window should be nil here.
         [self invalidate];
         break;
      }
      case ConfigureNotify:
      {
         [self frameChanged];
         [_delegate platformWindow:self frameChanged:[self transformFrame:_frame]];
         break;
      }
      case Expose:
      {
         if (ev->xexpose.count==0) {
            NSRect rect=NSMakeRect(ev->xexpose.x, ev->xexpose.y, ev->xexpose.width, ev->xexpose.height);
            [_delegate platformWindow:self needsDisplayInRect:[self transformFrame:rect]];
         }
         break;
      }
      case ButtonPress:
      {
         NSTimeInterval now=[[NSDate date] timeIntervalSinceReferenceDate];
         if(now-lastClickTimeStamp<[display doubleClickInterval]) {
            clickCount++;
         }
         else {
            clickCount=1;  
         }
         lastClickTimeStamp=now;
         
         NSPoint pos=[self transformPoint:NSMakePoint(ev->xbutton.x, ev->xbutton.y)];
         id event=[NSEvent mouseEventWithType:NSLeftMouseDown
                                  location:pos
                             modifierFlags:[self modifierFlagsForState:ev->xbutton.state]
                                    window:_delegate
                                clickCount:clickCount];
         [display postEvent:event atStart:NO];
         break;
      }
      case ButtonRelease:
      {
         NSPoint pos=[self transformPoint:NSMakePoint(ev->xbutton.x, ev->xbutton.y)];
         id event=[NSEvent mouseEventWithType:NSLeftMouseUp
                                  location:pos
                             modifierFlags:[self modifierFlagsForState:ev->xbutton.state]
                                    window:_delegate
                                clickCount:clickCount];
         [display postEvent:event atStart:NO];
         break;
      }
      case MotionNotify:
      {
         NSPoint pos=[self transformPoint:NSMakePoint(ev->xmotion.x, ev->xmotion.y)];
         NSEventType type=NSMouseMoved;
         
         if(ev->xmotion.state&Button1Mask) {
            type=NSLeftMouseDragged;
         }
         else if (ev->xmotion.state&Button2Mask) {
            type=NSRightMouseDragged;
         }
         
         if(type==NSMouseMoved &&
            ![_delegate acceptsMouseMovedEvents])
            break;
         
         id event=[NSEvent mouseEventWithType:type
                                  location:pos
                             modifierFlags:[self modifierFlagsForState:ev->xmotion.state]
                                    window:_delegate
                                clickCount:1];
         [display postEvent:event atStart:NO];
         [display discardEventsMatchingMask:NSLeftMouseDraggedMask beforeEvent:event];
         break;
      }
      case ClientMessage:
      {
         if(ev->xclient.format=32 &&
            ev->xclient.data.l[0]==XInternAtom(_dpy, "WM_DELETE_WINDOW", False))
            [_delegate platformWindowWillClose:self];
         break;
      }
      case KeyRelease:
      case KeyPress:
      {
         unsigned int modifierFlags=[self modifierFlagsForState:ev->xkey.state];
         char buf[4]={0};
         XLookupString((XKeyEvent*)ev, buf, 4, NULL, NULL);
         id str=[[NSString alloc] initWithCString:buf encoding:NSISOLatin1StringEncoding];
         NSPoint pos=[self transformPoint:NSMakePoint(ev->xkey.x, ev->xkey.y)];
         
         id strIg=[str lowercaseString];
         if(ev->xkey.state) {
            ev->xkey.state=0;
            XLookupString((XKeyEvent*)ev, buf, 4, NULL, NULL);
            strIg=[[NSString alloc] initWithCString:buf encoding:NSISOLatin1StringEncoding];
         }
      
         id event=[NSEvent keyEventWithType:ev->type == KeyPress ? NSKeyDown : NSKeyUp
                                   location:pos
                              modifierFlags:modifierFlags
                                  timestamp:0.0 
                               windowNumber:(NSInteger)_delegate
                                    context:nil
                                 characters:str 
                charactersIgnoringModifiers:strIg
                                  isARepeat:NO
                                    keyCode:ev->xkey.keycode];
         
         [display postEvent:event atStart:NO];
         
         [str release];
         break;
      }

      case FocusIn:
         if(lastFocusedWindow) {
            [_delegate platformWindowDeactivated:self checkForAppDeactivation:NO];
            lastFocusedWindow=nil;  
         }
         [_delegate platformWindowActivated:self];
         lastFocusedWindow=_delegate;
         break;
      case FocusOut:
         [_delegate platformWindowDeactivated:self checkForAppDeactivation:NO];
         lastFocusedWindow=nil;
         break;
         
      default:
         NSLog(@"type %i", ev->type);
         break;
   }
}


@end
