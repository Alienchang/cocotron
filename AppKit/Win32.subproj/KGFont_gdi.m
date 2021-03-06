#import "KGFont_gdi.h"
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0501
#import <windows.h>
#import <Foundation/NSString_win32.h>
#import "Win32Font.h"

@implementation KGFont(GDI)

+allocWithZone:(NSZone *)zone {
   return NSAllocateObject([KGFont_gdi class],0,NULL);
}

@end

@interface KGFont_gdi(forward)
-(void)fetchGlyphsToCharacters;
@end

@implementation KGFont_gdi

static HFONT Win32FontHandleWithName(NSString *name,int unitsPerEm){
   const unichar *wideName=(const unichar *)[name cStringUsingEncoding:NSUnicodeStringEncoding];
   return CreateFontW(-unitsPerEm,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,DEFAULT_QUALITY,DEFAULT_PITCH|FF_DONTCARE,wideName);
}

-initWithFontName:(NSString *)name {
   if(name==nil){
    [self release];
    return nil;
   }
   _name=[name copy];

   HDC dc=GetDC(NULL);

   if(dc==NULL){
    [self release];
    return nil;
   }
   
// P. 931 "Windows Graphics Programming" by Feng Yuan, 1st Ed. A font with height of negative otmEMSquare will have precise metrics
// 2048 is a common TrueType em square, so we try that first, and if the font is not TrueType, maybe we'll get some decent metrics with a big size.
   _unitsPerEm=2048;
   
   HFONT           font=Win32FontHandleWithName(name,_unitsPerEm);
   TEXTMETRIC      gdiMetrics;

   if(font==NULL){
    ReleaseDC(NULL,dc);
    [self release];
    return nil;
   }

   SelectObject(dc,font);
   GetTextMetrics(dc,&gdiMetrics);

// default values if not truetype or truetype queries fail
   _ascent=gdiMetrics.tmAscent;
   _descent=-gdiMetrics.tmDescent;
   _leading=gdiMetrics.tmInternalLeading+gdiMetrics.tmExternalLeading;
   _capHeight=gdiMetrics.tmHeight;
   _xHeight=gdiMetrics.tmHeight;
   _italicAngle=0;
   _stemV=0;
   _bbox.origin.x=0;
   _bbox.origin.y=0;
   _bbox.size.width=gdiMetrics.tmMaxCharWidth;
   _bbox.size.height=gdiMetrics.tmHeight;
   
   if(gdiMetrics.tmPitchAndFamily&TMPF_TRUETYPE){
    int                 size=GetOutlineTextMetricsW(dc,0,NULL);
    OUTLINETEXTMETRICW *ttMetrics=__builtin_alloca(size);

    ttMetrics->otmSize=sizeof(OUTLINETEXTMETRICW);
    if(size=GetOutlineTextMetricsW(dc,size,ttMetrics)){
   
     if(ttMetrics->otmEMSquare!=_unitsPerEm){
      // if our first try didn't have the typical em square, recreate using the em square 
      LOGFONT logFont;
      
      GetObject(font,sizeof(logFont),&logFont);
      logFont.lfHeight=-ttMetrics->otmEMSquare;
      logFont.lfWidth=0;
     
      HFONT emSquareFont=CreateFontIndirect(&logFont);
      SelectObject(dc,emSquareFont);
      DeleteObject(font);
      font=emSquareFont;

      ttMetrics->otmSize=sizeof(OUTLINETEXTMETRICW);
      size=GetOutlineTextMetricsW(dc,size,ttMetrics);
     }
      
     if(size!=0){
      _unitsPerEm=ttMetrics->otmEMSquare;
      
      if([name isEqualToString:@"Marlett"]){
       _useMacMetrics=NO;
       _ascent=ttMetrics->otmAscent;
       _descent=ttMetrics->otmDescent;
       _leading=ttMetrics->otmLineGap;
      }
      else {
       _useMacMetrics=YES;
       _ascent=ttMetrics->otmMacAscent;
       _descent=ttMetrics->otmMacDescent;
       _leading=ttMetrics->otmMacLineGap;
      }
      
      _capHeight=ttMetrics->otmsCapEmHeight;
      _xHeight=ttMetrics->otmsXHeight;
      _italicAngle=ttMetrics->otmItalicAngle;
      _stemV=0;
      _bbox.origin.x=ttMetrics->otmrcFontBox.left;
      _bbox.origin.y=ttMetrics->otmrcFontBox.bottom;
      _bbox.size.width=ttMetrics->otmrcFontBox.right-ttMetrics->otmrcFontBox.left;
      _bbox.size.height=ttMetrics->otmrcFontBox.top-ttMetrics->otmrcFontBox.bottom;
     }
    }
   }
   
   DeleteObject(font);
   ReleaseDC(NULL,dc);
   
   return self;
}

-(void)dealloc {
   if(_glyphsToCharacters!=NULL)
    NSZoneFree(NULL,_glyphsToCharacters);
   [super dealloc];
}

-(CGGlyph)glyphWithGlyphName:(NSString *)name {
   return 0;
}

-(NSString *)copyGlyphNameForGlyph:(CGGlyph)glyph {
   return nil;
}

-(NSData *)copyTableForTag:(uint32_t)tag {
   return nil;
}

-(void)fetchAdvances {
   [self fetchGlyphsToCharacters];
   
   HANDLE   library=LoadLibrary("GDI32");
   FARPROC  getGlyphIndices=GetProcAddress(library,"GetGlyphIndicesW");
   HDC      dc=GetDC(NULL);
   unichar  characters[65536];
   uint16_t glyphs[65536];
   int      i,max;
   ABCFLOAT *abc;
   
   for(i=0;i<65536;i++)
    characters[i]=i;
    
   HFONT font=Win32FontHandleWithName(_name,_unitsPerEm);
   SelectObject(dc,font);

   getGlyphIndices(dc,characters,65535,glyphs,0);

   _advances=NSZoneMalloc(NULL,sizeof(int)*_numberOfGlyphs);
   max=65535;
   max=((max/128)+1)*128;
   abc=__builtin_alloca(sizeof(ABCFLOAT)*max);
   if(!GetCharABCWidthsFloatW(dc,0,max-1,abc))
    NSLog(@"GetCharABCWidthsFloat failed");
   else {
    for(i=max;--i>=0;){
     CGGlyph glyph=glyphs[i];
     
     if(glyph<_numberOfGlyphs)
      _advances[glyph]=abc[i].abcfA+abc[i].abcfB+abc[i].abcfC;
    }
   }
   
   DeleteObject(font);
   ReleaseDC(NULL,dc);
}

-(Win32Font *)createGDIFontSelectedInDC:(HDC)dc pointSize:(CGFloat)pointSize {
   if(_useMacMetrics){
    if (pointSize <= 10.0)
       pointSize=pointSize;
    else if (pointSize < 20.0)
       pointSize=pointSize/(1.0 + 0.2*sqrtf(0.0390625*(pointSize - 10.0)));
    else
       pointSize=pointSize/1.125;
   }
   int        height=(pointSize*GetDeviceCaps(dc,LOGPIXELSY))/72.0;
   Win32Font *result=[[Win32Font alloc] initWithName:_name height:height antialias:NO];
   
   SelectObject(dc,[result fontHandle]);
   
   return result;
}

// These are only used for PDF generation until we get PS glyph names working
// They are both temporary and inaccurate 

-(void)fetchGlyphsToCharacters {
   HDC      dc=GetDC(NULL);
   unichar  characters[65536];
   uint16_t glyphs[65536];
   int      i,maxGlyph=0;
   HANDLE   library=LoadLibrary("GDI32");
   FARPROC  getGlyphIndices=GetProcAddress(library,"GetGlyphIndicesW");

   for(i=0;i<65536;i++)
    characters[i]=i;
    
   HFONT font=Win32FontHandleWithName(_name,_unitsPerEm);
   SelectObject(dc,font);
   getGlyphIndices(dc,characters,65535,glyphs,0);
   DeleteObject(font);
   ReleaseDC(NULL,dc);
   
   for(i=0;i<65536;i++)
    maxGlyph=MAX(maxGlyph,glyphs[i]);
   _numberOfGlyphs=maxGlyph+1;

   _glyphsToCharacters=NSZoneMalloc(NULL,sizeof(unichar)*_numberOfGlyphs);
   for(i=65536;--i>=0;){
    if(glyphs[i]<_numberOfGlyphs)
     _glyphsToCharacters[glyphs[i]]=characters[i];
   }
}

-(void)getMacRomanBytes:(unsigned char *)bytes forGlyphs:(const CGGlyph *)glyphs length:(unsigned)length {
   if(_glyphsToCharacters==NULL)
    [self fetchGlyphsToCharacters];

   int i;
   
   for(i=0;i<length;i++){
    if(glyphs[i]<_numberOfGlyphs){
     unichar code=_glyphsToCharacters[glyphs[i]];
     
     if(code<256)
      bytes[i]=code;
     else
      bytes[i]=' ';
    }
    else
     bytes[i]=' ';
   }
}

-(CGGlyph *)MacRomanEncoding {
   if(_MacRomanEncoding==NULL){
    HDC      dc=GetDC(NULL);
    unichar  characters[256];
    HANDLE   library=LoadLibrary("GDI32");
    FARPROC  getGlyphIndices=GetProcAddress(library,"GetGlyphIndicesW");
    int      i;
   
    _MacRomanEncoding=NSZoneMalloc(NULL,sizeof(CGGlyph)*256);
    for(i=0;i<256;i++)
     characters[i]=i;
    
    HFONT font=Win32FontHandleWithName(_name,_unitsPerEm);
    SelectObject(dc,font);
    getGlyphIndices(dc,characters,256,_MacRomanEncoding,0);
    DeleteObject(font);
    ReleaseDC(NULL,dc);
   }
   return _MacRomanEncoding;
}

@end
