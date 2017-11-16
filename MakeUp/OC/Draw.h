//
//  Draw.h
//  MakeUp
//
//  Created by Jian Zhang  on 16/11/2017.
//  Copyright © 2017 REAio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

@interface Draw : NSObject

- (void)setFillColor:(UIColor *)color intoContext:(CGContextRef)context;
- (void)setStrokeColor:(UIColor *)color intoContext:(CGContextRef)context;
- (void)drawLine:(NSArray<NSValue *> *)points withLineWidth:(CGFloat)width intoContext:(CGContextRef)context;
- (void)drawPolygon:(NSArray<NSValue *> *)points withLineWidth:(CGFloat)width shouldFill:(BOOL)fill shouldStroke:(BOOL)stroke intoContext:(CGContextRef)context;
- (void)drawCircle:(CGPoint)point intoContext:(CGContextRef)context;

@end

@interface ImageTransform: NSObject

- (CGContextRef)contextByCVPixelBuffer:(CVPixelBufferRef)cvPixelBuffer;

@end
