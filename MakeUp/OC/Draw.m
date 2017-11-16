//
//  Draw.m
//  MakeUp
//
//  Created by Jian Zhang  on 16/11/2017.
//  Copyright © 2017 REAio. All rights reserved.
//

#import "Draw.h"

@implementation Draw

- (void)setFillColor:(UIColor *)color intoContext:(CGContextRef)context {
  CGContextSetFillColor(context, CGColorGetComponents(color.CGColor));
}

- (void)setStrokeColor:(UIColor *)color intoContext:(CGContextRef)context {
  CGContextSetStrokeColor(context, CGColorGetComponents(color.CGColor));
}

- (void)drawLine:(NSArray<NSValue *> *)points withLineWidth:(CGFloat)width intoContext:(CGContextRef)context {
  CGContextSetLineWidth(context, width);
  CGPoint firstPoint = [[points firstObject] CGPointValue];
  CGContextMoveToPoint(context, firstPoint.x, firstPoint.y);
  for (int i = 1; i < [points count]; i++) {
    CGPoint point = [[points objectAtIndex:i] CGPointValue];
    CGContextAddLineToPoint(context, point.x, point.y);
  }
  CGContextStrokePath(context);
}

- (void)drawPolygon:(NSArray<NSValue *> *)points withLineWidth:(CGFloat)width shouldFill:(BOOL)fill shouldStroke:(BOOL)stroke intoContext:(CGContextRef)context {
  UIBezierPath *polygonPath = [self polygonPathByPoints:points];
  polygonPath.lineWidth = width;
  CGContextAddPath(context, polygonPath.CGPath);
  if (fill && stroke) {
    CGContextDrawPath(context, kCGPathFillStroke);
    return;
  }
  if (fill) {
    CGContextDrawPath(context, kCGPathFill);
    return;
  }
  if (stroke) {
    CGContextDrawPath(context, kCGPathStroke);
    return;
  }
}

- (void)drawCircle:(CGPoint)point intoContext:(CGContextRef)context {
  CGContextSetLineWidth(context, 1.0);
  CGContextAddRect(context, CGRectMake(point.x, point.y, 20, 20));
  CGContextStrokePath(context);
}

- (UIBezierPath *)polygonPathByPoints:(NSArray<NSValue *> *)points {
  CGPoint firstPoint = [[points firstObject] CGPointValue];
  UIBezierPath *path = [UIBezierPath bezierPath];
  [path moveToPoint:firstPoint];
  for (int i = 1; i < [points count]; i++) {
    CGPoint point = [[points objectAtIndex:i] CGPointValue];
    [path addLineToPoint:point];
  }
  [path closePath];
  return path;
}

@end

@implementation ImageTransform

- (CGContextRef)contextByCVPixelBuffer:(CVPixelBufferRef)cvPixelBuffer {
  CGColorSpaceRef deviceColors = CGColorSpaceCreateDeviceRGB();
  return CGBitmapContextCreate(CVPixelBufferGetBaseAddress(cvPixelBuffer), CVPixelBufferGetWidth(cvPixelBuffer), CVPixelBufferGetHeight(cvPixelBuffer), 8, CVPixelBufferGetBytesPerRow(cvPixelBuffer), deviceColors, kCGImageAlphaPremultipliedFirst);
}

@end

