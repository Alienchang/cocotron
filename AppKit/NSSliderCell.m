/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#import <AppKit/NSSliderCell.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSMatrix.h>
#import <AppKit/NSControl.h>
#import <Foundation/NSKeyedArchiver.h>
#import <AppKit/NSGraphicsStyle.h>
#import <AppKit/NSRaise.h>

#define PIXELINSET	8
#define TICKHEIGHT      8

@implementation NSSliderCell

-(void)encodeWithCoder:(NSCoder *)coder {
   NSUnimplementedMethod();
}

-initWithCoder:(NSCoder *)coder {
   [super initWithCoder:coder];

   if([coder allowsKeyedCoding]){
    NSKeyedUnarchiver *keyed=(NSKeyedUnarchiver *)coder;
    
    _minValue=[keyed decodeDoubleForKey:@"NSMinValue"];
    _maxValue=[keyed decodeDoubleForKey:@"NSMaxValue"];
    _numberOfTickMarks=[keyed decodeIntForKey:@"NSNumberOfTickMarks"];
    _tickMarkPosition=[keyed decodeIntForKey:@"NSTickMarkPosition"];
    _allowsTickMarkValuesOnly=[keyed decodeBoolForKey:@"NSAllowsTickMarkValuesOnly"];
   }
   else {
    [NSException raise:NSInvalidArgumentException format:@"-[%@ %s] is not implemented for coder %@",isa,sel_getName(_cmd),coder];
   }

   return self;
}

-initTextCell:(NSString *)string {
   [super initTextCell:string];
   _isContinuous=YES; // NSCell defaults to NO, NSSliderCell defaults to YES
   _type=NSLinearSlider;
   _minValue=0;
   _maxValue=0;
   _altIncrementValue=0;
   _isVertical=-1;
   _lastRect=NSZeroRect;
   _numberOfTickMarks=0;
   _tickMarkPosition=NSTickMarkBelow;
   _allowsTickMarkValuesOnly=NO;
   return self;
}

-initImageCell:(NSImage *)image {
   [super initImageCell:image];
   _isContinuous=YES; // NSCell defaults to NO, NSSliderCell defaults to YES
   _type=NSLinearSlider;
   _minValue=0;
   _maxValue=0;
   _altIncrementValue=0;
   _isVertical=-1;
   _lastRect=NSZeroRect;
   _numberOfTickMarks=0;
   _tickMarkPosition=NSTickMarkBelow;
   _allowsTickMarkValuesOnly=NO;
   return self;
}

+(BOOL)prefersTrackingUntilMouseUp {
   return YES;
}

-(NSSliderType)sliderType {
   return _type;
}

-(double)minValue {
   return _minValue;
}

-(double)maxValue {
   return _maxValue;
}

-(double)altIncrementValue {
   return _altIncrementValue;
}

-(NSInteger)numberOfTickMarks {
   return _numberOfTickMarks;
}

-(NSTickMarkPosition)tickMarkPosition {
   return _tickMarkPosition;
}

-(BOOL)allowsTickMarkValuesOnly {
   return _allowsTickMarkValuesOnly;
}

-(CGFloat)knobThickness {
   return 0;
}

-(void)setSliderType:(NSSliderType)value {
   _type=value;
}

-(void)setMinValue:(double)minValue {
   _minValue = minValue;
}

-(void)setMaxValue:(double)maxValue {
   _maxValue = maxValue;
}

-(void)setAltIncrementValue:(double)value {
   _altIncrementValue=value;
}

-(void)setNumberOfTickMarks:(NSInteger)number {
   _numberOfTickMarks=number;
}

-(void)setTickMarkPosition:(NSTickMarkPosition)position {
   _tickMarkPosition=position;
}

-(void)setAllowsTickMarkValuesOnly:(BOOL)valuesOnly {
   _allowsTickMarkValuesOnly=valuesOnly;
}

-(void)setKnobThickness:(CGFloat)thickness {
// deprecated, do nothing
}

-(NSInteger)isVertical {
   return _isVertical;
}

-(NSInteger)indexOfTickMarkAtPoint:(NSPoint)point {
   int i;
   
   for(i=0;i<_numberOfTickMarks;i++){
    NSRect check=[self rectOfTickMarkAtIndex:i];
    
    check=NSInsetRect(check,-1,-1);
    
    if(NSPointInRect(point,check))
     return i;
   }
   
   return NSNotFound;
}

-(double)tickMarkValueAtIndex:(NSInteger)index {
   double  length=(_isVertical?_lastRect.size.height:_lastRect.size.width)-2*PIXELINSET;

   return (_numberOfTickMarks==1)?length/2:index*(length/(_numberOfTickMarks-1));
}

-(double)closestTickMarkValueToValue:(double)value {
   NSUnimplementedMethod();
   return 0;
}

-(NSRect)trackRect {
   NSUnimplementedMethod();
   return NSZeroRect;
}

-(NSRect)rectOfTickMarkAtIndex:(NSInteger)index {
   NSRect result;
   CGFloat  length=(_isVertical?_lastRect.size.height:_lastRect.size.width)-2*PIXELINSET;
   CGFloat  position=floor((_numberOfTickMarks==1)?length/2:index*(length/(_numberOfTickMarks-1)));

   if(_isVertical){
    result.origin.x=_lastRect.origin.x;
    if(_tickMarkPosition==NSTickMarkBelow)
     result.origin.x+=_lastRect.size.width-TICKHEIGHT;
    result.origin.y=floor(_lastRect.origin.y+PIXELINSET+position);
    result.size.width=TICKHEIGHT;
    result.size.height=1;
   }
   else {
    result.origin.x=floor(_lastRect.origin.x+PIXELINSET+position);
    result.origin.y=_lastRect.origin.y;
    if(_tickMarkPosition==NSTickMarkAbove)
     result.origin.y+=_lastRect.size.height-TICKHEIGHT;
    result.size.width=1;
    result.size.height=TICKHEIGHT;
   }

   return result;
}


-(void)drawBarInside:(NSRect)frame flipped:(BOOL)isFlipped {
   [[_controlView graphicsStyle] drawSliderTrackInRect:frame vertical:[self isVertical] hasTickMarks:(_numberOfTickMarks>0)?YES:NO];
}


-(NSRect)_sliderRect {
   NSRect result=_lastRect;

   if(_numberOfTickMarks>0){
    if([self isVertical]){
     result.size.width-=TICKHEIGHT;
     if(_tickMarkPosition==NSTickMarkLeft)
      result.origin.x+=TICKHEIGHT;
    }
    else {
     result.size.height-=TICKHEIGHT;
     if(_tickMarkPosition==NSTickMarkBelow)
      result.origin.y+=TICKHEIGHT;
    }
   }

   return result;
}

-(NSRect)knobRectFlipped:(BOOL)flipped {
   double value=[self doubleValue];
   double percent=(value-_minValue)/(_maxValue-_minValue);
   NSRect sliderRect=[self _sliderRect];
   NSRect knobRect;
   NSSize knobSize=[[_controlView graphicsStyle] sliderKnobSize];
   
   if ([self isVertical]) {
    knobRect.size.height=knobSize.width;
    knobRect.size.width=knobSize.height;
    knobRect.origin.x=floor(sliderRect.origin.x+(sliderRect.size.width-knobSize.height)/2);
    knobRect.origin.y=floor(sliderRect.origin.y+PIXELINSET+percent*(sliderRect.size.height-(PIXELINSET*2))-knobSize.width/2);
   }
   else {
    knobRect.size.width=knobSize.width;
    knobRect.size.height=knobSize.height;
    knobRect.origin.x=floor(sliderRect.origin.x+PIXELINSET+percent*(sliderRect.size.width-(PIXELINSET*2))-knobSize.width/2);
    knobRect.origin.y=floor(sliderRect.origin.y+(sliderRect.size.height-knobSize.height)/2);
   }

   return knobRect;
}

-(void)drawKnob {
   [self drawKnob:[self knobRectFlipped:[[self controlView] isFlipped]]];
}

-(void)drawKnob:(NSRect)rect {
   [[_controlView graphicsStyle] drawSliderKnobInRect:rect vertical:[self isVertical] highlighted:[self isHighlighted] hasTickMarks:(_numberOfTickMarks>0)?YES:NO tickMarkPosition:_tickMarkPosition];
}

-(void)drawTickMarks {
   NSGraphicsStyle *style=[_controlView graphicsStyle];
   int i;

   for(i=0;i<_numberOfTickMarks;i++)
    [style drawSliderTickInRect:[self rectOfTickMarkAtIndex:i]];
}

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)controlView
{
    BOOL drawDottedRect=NO;

    _controlView=controlView;
    _lastRect = frame;
    
    _isVertical = (frame.size.height>frame.size.width)?1:0;

    [self drawBarInside:[self _sliderRect] flipped:[controlView isFlipped]];
    [self drawTickMarks];
    [self drawKnob];

    // would be nice to put this code in some superclass
    if([[controlView window] firstResponder]==controlView){
        if([controlView isKindOfClass:[NSMatrix class]]){
            NSMatrix *matrix=(NSMatrix *)controlView;

            drawDottedRect=([matrix keyCell]==self)?YES:NO;
        }
        else if([controlView isKindOfClass:[NSControl class]]){
            NSControl *control=(NSControl *)controlView;

            drawDottedRect=([control selectedCell]==self)?YES:NO;
        }
    }

    if(drawDottedRect)
        NSDottedFrameRect(NSInsetRect(frame,1,1)); // fugly
}

// just a guess, but we'll try moving it 10% of its total range of values...
- (void)_incrementByPercentageAndConstrain:(CGFloat)percentage decrement:(BOOL)decrement {
    double originalValue = [self doubleValue];

    if (decrement)
        originalValue -= (_maxValue - _minValue) * percentage;
    else
        originalValue += (_maxValue - _minValue) * percentage;        
    
    if (originalValue > _maxValue)
        originalValue = _maxValue;
    else if (originalValue < _minValue)
        originalValue = _minValue;

    [self setDoubleValue:originalValue];
}

- (void)moveUp:(id)sender {
    if ([self isVertical])
        [self _incrementByPercentageAndConstrain:0.10 decrement:NO];
}

- (void)moveDown:(id)sender {
    if ([self isVertical])
        [self _incrementByPercentageAndConstrain:0.10 decrement:YES];
}

- (void)moveLeft:(id)sender {
    if ([self isVertical] == NO)
        [self _incrementByPercentageAndConstrain:0.10 decrement:YES];
}

- (void)moveRight:(id)sender {
    if ([self isVertical] == NO)
        [self _incrementByPercentageAndConstrain:0.10 decrement:NO];
}

// sliderCell behavior:
// 	1. test hit in knob.. if so, go on to 3
//	2. test hit in bar. if hit, move knob to click location
//	3. track knob.
-(void)_setDoubleValueFromPoint:(NSPoint)point
{
    // ((pointX-cellX)/cellW)*((max-min)+min)!
    double length,position;
    double percentPixels;

    if(_isVertical){
     length=(_lastRect.size.height-(2*PIXELINSET));
     position=point.y-(_lastRect.origin.y+PIXELINSET);
    }
    else {
     length=(_lastRect.size.width-(2*PIXELINSET));
     position=point.x-(_lastRect.origin.x+PIXELINSET);
    }

    percentPixels=position/length;

#if 0
    NSLog(@"percentPixels is %g; max-min is %g", percentPixels, _maxValue - _minValue);
    NSLog(@"doubleValue should be %g", (percentPixels*(_maxValue-_minValue))+_minValue);
#endif
    if (percentPixels > 1.0)
        percentPixels = 1.0;
    if (percentPixels < 0.0)
        percentPixels = 0.0;

    [self setDoubleValue:(percentPixels*(_maxValue-_minValue))+_minValue];
}

-(BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
    NSPoint localPoint = [controlView convertPoint:startPoint fromView:nil];

    if (NSMouseInRect(localPoint,[self knobRectFlipped:[controlView isFlipped]],[controlView isFlipped])) {
        [self highlight:YES withFrame:_lastRect inView:controlView];
    }
    else if (NSMouseInRect(localPoint, _lastRect,[controlView isFlipped])) {
        [self _setDoubleValueFromPoint:localPoint];
        //NSLog(@"bar click; new doubleValue is %g", [self doubleValue]);
        return YES;
    }

    return YES;		// what happened here?    
}

-(BOOL)continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView *)controlView
{
    NSPoint localPoint = [controlView convertPoint:currentPoint fromView:nil];

    [self _setDoubleValueFromPoint:localPoint];
    [self drawWithFrame:_lastRect inView:controlView];
//    NSLog(@"tracking; new doubleValue is %g", [self doubleValue]);

    return YES;
}

-(void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
    [self highlight:NO withFrame:_lastRect inView:controlView];
}

@end
