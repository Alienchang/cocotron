/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <AppKit/KGDeviceContext_gdi.h>
#import <Foundation/NSGeometry.h>

@interface KGDeviceContext_gdiDIBSection : KGDeviceContext_gdi {
   KGDeviceContext_gdi *_compatible;
   HBITMAP              _bitmap;
   int                  _bitsPerPixel;
   size_t               _bitsPerComponent;
   size_t               _bytesPerRow;
   void                *_bits;
}

-initWithWidth:(size_t)width height:(size_t)height deviceContext:(KGDeviceContext_gdi *)compatible bitsPerPixel:(int)bpp;
-initWithWidth:(size_t)width height:(size_t)height deviceContext:(KGDeviceContext_gdi *)compatible;

-(void *)bitmapBytes;

-(size_t)bitsPerComponent;
-(size_t)bytesPerRow;

-(int)bitsPerPixel;

@end
