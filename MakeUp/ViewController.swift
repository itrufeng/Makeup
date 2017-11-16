//
//  ViewController.swift
//  VideoCapture
//
//  Created by Jian Zhang  on 15/11/2017.
//  Copyright © 2017 REAio. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {
  var session = AVCaptureSession()
  let layer = AVSampleBufferDisplayLayer()
  let videoQueue = DispatchQueue(label: "com.itrufeng.videocapture.videoframe")
  let faceQueue = DispatchQueue(label: "com.itrufeng.videocapture.faceframe")
  var currentMetadata = [AVMetadataObject]()
  let wrapper = DlibWrapper()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.layer.addSublayer(layer)
    setup()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    layer.frame = view.bounds
    view.layoutIfNeeded()
  }

  // MARK: Delegate

  func captureOutput(_ output: AVCaptureOutput, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    if currentMetadata.isEmpty {
      layer.enqueue(sampleBuffer)
      return
    }

    let bounds = currentMetadata.flatMap { $0 as? AVMetadataFaceObject }.flatMap { faceObject -> NSValue? in
      guard let metadataObject = output.transformedMetadataObject(for: faceObject, connection: connection) else { return nil }
      let toObjC = NSValue(cgRect: metadataObject.bounds)
      return toObjC
    }
    wrapper?.doWork(on: sampleBuffer, inRects: bounds)
    layer.enqueue(sampleBuffer)
  }

  func captureOutput(_ output: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
    guard let metadataObjects = metadataObjects as? [AVMetadataObject] else {
      return
    }
    currentMetadata = metadataObjects
  }

  // MARK: Private

  private func setup() {
    let devices = AVCaptureDevice.devices().filter {($0 as! AVCaptureDevice).position == .front}
    guard let device = devices.first as? AVCaptureDevice,
      let input = try? AVCaptureDeviceInput(device: device) else {
        return
    }
    let output = AVCaptureVideoDataOutput()
    output.setSampleBufferDelegate(self, queue: videoQueue)
    let metaOutput = AVCaptureMetadataOutput()
    metaOutput.setMetadataObjectsDelegate(self, queue: faceQueue)
    session.beginConfiguration()
    if session.canAddInput(input) {
      session.addInput(input)
    }
    if session.canAddOutput(output) {
      session.addOutput(output)
    }
    if session.canAddOutput(metaOutput) {
      session.addOutput(metaOutput)
    }
    session.commitConfiguration()
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
    let connection = output.connection(withMediaType: AVMediaTypeVideo)
    connection?.videoOrientation = .portrait
    metaOutput.metadataObjectTypes = [AVMetadataObjectTypeFace]
    session.startRunning()
  }
}

