//
//  DlibWrapper.m
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 16.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

#import "DlibWrapper.h"
#import <UIKit/UIKit.h>

#include <dlib/image_processing.h>
#include <dlib/image_io.h>

#import "Draw.h"

@interface DlibWrapper ()

@property (assign) BOOL prepared;
@property (strong, nonatomic) Draw *drawTool;
@property (strong, nonatomic) ImageTransform *imageTransform;

+ (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects;

@end
@implementation DlibWrapper {
  dlib::shape_predictor sp;
}


- (instancetype)init {
  self = [super init];
  if (self) {
    _prepared = NO;
    _drawTool = [Draw new];
    _imageTransform = [ImageTransform new];
  }
  return self;
}

- (void)prepare {
  NSString *modelFileName = [[NSBundle mainBundle] pathForResource:@"shape_predictor_68_face_landmarks" ofType:@"dat"];
  std::string modelFileNameCString = [modelFileName UTF8String];

  dlib::deserialize(modelFileNameCString) >> sp;

  // FIXME: test this stuff for memory leaks (cpp object destruction)
  self.prepared = YES;
}

- (void)doWorkOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects {

  if (!self.prepared) {
    [self prepare];
  }

  dlib::array2d<dlib::bgr_pixel> img;

  // MARK: magic
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);
  char *baseBuffer = (char *)CVPixelBufferGetBaseAddress(imageBuffer);

  // set_size expects rows, cols format
  img.set_size(height, width);

  // copy samplebuffer image data into dlib image format
  img.reset();
  long position = 0;
  while (img.move_next()) {
    dlib::bgr_pixel& pixel = img.element();

    // assuming bgra format here
    long bufferLocation = position * 4; //(row * width + column) * 4;
    char b = baseBuffer[bufferLocation];
    char g = baseBuffer[bufferLocation + 1];
    char r = baseBuffer[bufferLocation + 2];
    //        we do not need this
    //        char a = baseBuffer[bufferLocation + 3];

    dlib::bgr_pixel newpixel(b, g, r);
    pixel = newpixel;

    position++;
  }

  // unlock buffer again until we need it again
  CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

  // convert the face bounds list to dlib format
  std::vector<dlib::rectangle> convertedRectangles = [DlibWrapper convertCGRectValueArray:rects];

  // for every detected face
  for (unsigned long j = 0; j < convertedRectangles.size(); ++j)
  {
    dlib::rectangle oneFaceRect = convertedRectangles[j];

    // detect all landmarks
    dlib::full_object_detection shape = sp(img, oneFaceRect);

    // define landmarks
    dlib::array<std::vector<dlib::point>> landmarks;

    // and draw them into the image (samplebuffer)
    for (unsigned long k = 0; k < shape.num_parts(); k++) {
      dlib::point p = shape.part(k);
      if (k == 19 || k == 24 || k == 27 || k == 33 || k == 66 || k == 57) {
        draw_solid_circle(img, p, 3, dlib::rgb_pixel(255, 0, 0));
        continue;
      }
      
      draw_solid_circle(img, p, 3, dlib::rgb_pixel(0, 255, 255));
    }
  }

  // lets put everything back where it belongs
  CVPixelBufferLockBaseAddress(imageBuffer, 0);

  // copy dlib image data back into samplebuffer
  img.reset();
  position = 0;
  while (img.move_next()) {
    dlib::bgr_pixel& pixel = img.element();

    // assuming bgra format here
    long bufferLocation = position * 4; //(row * width + column) * 4;
    baseBuffer[bufferLocation] = pixel.blue;
    baseBuffer[bufferLocation + 1] = pixel.green;
    baseBuffer[bufferLocation + 2] = pixel.red;
    //        we do not need this
    //        char a = baseBuffer[bufferLocation + 3];

    position++;
  }
  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

- (void)drawOnSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects {
  if (!self.prepared) {
    [self prepare];
  }
  NSArray<NSValue *> *points = [self fetchFaceLandmarksWithSampleBuffer:sampleBuffer inRects:rects];
  if (points == nil || [points count] == 0) {
    return;
  }
  [self drawFaceLandmarkInSampleBuffer:sampleBuffer points:points];
}

- (NSArray<NSValue *> *)fetchFaceLandmarksWithSampleBuffer:(CMSampleBufferRef)sampleBuffer inRects:(NSArray<NSValue *> *)rects {
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

  dlib::array2d<dlib::bgr_pixel> img;

  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);
  img.set_size(width, height);

  img.reset();

  // fill data to img
  char *baseBuffer = (char *)CVPixelBufferGetBaseAddress(imageBuffer);
  long position = 0;
  while (img.move_next()) {
    dlib::bgr_pixel& pixel = img.element();
    long bufferLocation = position * 4;
    char b = baseBuffer[bufferLocation];
    char g = baseBuffer[bufferLocation + 1];
    char r = baseBuffer[bufferLocation + 2];

    dlib::bgr_pixel newpixel(b, g, r);
    pixel = newpixel;

    position++;
  }

  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

  // sp
  std::vector<dlib::rectangle> convertedRectangles = [DlibWrapper convertCGRectValueArray:rects];
  if (convertedRectangles.size() < 1) {
    return nil;
  }
  dlib::rectangle oneFaceRect = convertedRectangles[0];
  dlib::full_object_detection shape = sp(img, oneFaceRect);
  NSMutableArray *mutablePoints = [[NSMutableArray alloc] init];
  for (unsigned long k = 0; k < shape.num_parts(); k++) {
    dlib::point p = shape.part(k);
    [mutablePoints addObject:[NSValue valueWithCGPoint:CGPointMake(p.x(), -(p.y() - height))]];
  }
  return [mutablePoints mutableCopy];
}

- (void)drawFaceLandmarkInSampleBuffer:(CMSampleBufferRef)sampleBuffer points:(NSArray<NSValue *> *)points {
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
  CGContextRef context = [self.imageTransform contextByCVPixelBuffer:imageBuffer];
  NSArray<NSValue *> *leftEyes = [points subarrayWithRange:NSMakeRange(36, 42-36)];
  NSArray<NSValue *> *rightEyes = [points subarrayWithRange:NSMakeRange(42, 48-42)];
  NSArray<NSValue *> *topLip = [[points subarrayWithRange:NSMakeRange(48, 55-48)] arrayByAddingObjectsFromArray:@[points[64], points[63], points[62], points[61], points[60]]];
  NSArray<NSValue *> *bottomLip = [[points subarrayWithRange:NSMakeRange(54, 60-54)] arrayByAddingObjectsFromArray:@[points[48], points[60], points[67], points[66], points[65], points[64]]];
  NSArray<NSValue *> *leftEyebrow = [points subarrayWithRange:NSMakeRange(17, 22-17)];
  NSArray<NSValue *> *rightEyebrow = [points subarrayWithRange:NSMakeRange(22, 27-22)];
  [self.drawTool drawPolygon:leftEyes withLineWidth:1 shouldFill:YES shouldStroke:YES intoContext:context];
  [self.drawTool drawPolygon:rightEyes withLineWidth:1 shouldFill:YES shouldStroke:YES intoContext:context];
  [self.drawTool drawPolygon:topLip withLineWidth:1 shouldFill:YES shouldStroke:YES intoContext:context];
  [self.drawTool drawPolygon:bottomLip withLineWidth:1 shouldFill:YES shouldStroke:YES intoContext:context];
  [self.drawTool drawLine:leftEyebrow withLineWidth:1.0 intoContext:context];
  [self.drawTool drawLine:rightEyebrow withLineWidth:1.0 intoContext:context];
  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

+ (std::vector<dlib::rectangle>)convertCGRectValueArray:(NSArray<NSValue *> *)rects {
  std::vector<dlib::rectangle> myConvertedRects;
  for (NSValue *rectValue in rects) {
    CGRect rect = [rectValue CGRectValue];
    long left = rect.origin.x;
    long top = rect.origin.y;
    long right = left + rect.size.width;
    long bottom = top + rect.size.height;
    dlib::rectangle dlibRect(left, top, right, bottom);

    myConvertedRects.push_back(dlibRect);
  }
  return myConvertedRects;
}

@end
