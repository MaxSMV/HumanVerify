//
//  CameraCaptureHelper.swift
//  HumanVerify IOS APP
//
//  Created by Max Stefankiv on 18.04.2023.
//

import AVFoundation
import CoreMedia
import CoreImage
import UIKit

class CameraCaptureHelper: NSObject {
    let captureSession = AVCaptureSession()
    let cameraPosition: AVCaptureDevice.Position
    
    weak var delegate: CameraCaptureHelperDelegate?
    
    required init(cameraPosition: AVCaptureDevice.Position) {
        self.cameraPosition = cameraPosition
        
        super.init()
        
        initialiseCaptureSession()
    }
    
    fileprivate func initialiseCaptureSession() {
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: cameraPosition)
        
        guard let camera = discoverySession.devices.first else {
            fatalError("Unable to access camera")
        }
        print("Camera is accessible")

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            captureSession.addInput(input)
            print("Camera input added successfully")
        } catch {
            fatalError("Unable to access back camera")
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.setSampleBufferDelegate(self,
            queue: DispatchQueue(label: "sample buffer delegate", attributes: []))
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            print("Camera output added successfully")
        }
        captureSession.startRunning()
        print("Camera session started running")
    }
}

extension CameraCaptureHelper: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var orientation: AVCaptureVideoOrientation = .portrait
        DispatchQueue.main.sync {
            orientation = .portrait
        }

        
        connection.videoOrientation = orientation
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        DispatchQueue.main.async {
            self.delegate?.newCameraImage(self,
                image: CIImage(cvPixelBuffer: pixelBuffer))
        }
    }
}

protocol CameraCaptureHelperDelegate: AnyObject {
    func newCameraImage(_ cameraCaptureHelper: CameraCaptureHelper, image: CIImage)
}
