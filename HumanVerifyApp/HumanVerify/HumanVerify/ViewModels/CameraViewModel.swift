//
//  CameraViewModel.swift
//  HumanVerify IOS APP
//
//  Created by Max Stefankiv on 18.04.2023.
//

import Foundation
import AVFoundation
import Alamofire
import SwiftUI
import Vision

class CameraViewModel: NSObject, ObservableObject, CameraCaptureHelperDelegate {
    @Published var session = AVCaptureSession()
    @Published var detectedFace = CGRect()
    @Published var emotionText = ""
    
    private var output = AVCaptureVideoDataOutput()
    private var faceDetectionRequest = VNDetectFaceRectanglesRequest()
    private let sequenceHandler = VNSequenceRequestHandler()
    private var cameraCaptureHelper: CameraCaptureHelper?
    
    // Add the frame counter property
    private var frameCounter = 0
    
    override init() {
        super.init()
        configureSession()
    }
    
    func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    private func configureSession() {
        checkCameraPermissions { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.setupSession()
            } else {
                print("Camera permission denied")
            }
        }
    }
    
    private var screenOrientation: AVCaptureVideoOrientation {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            switch windowScene.interfaceOrientation {
            case .portrait:
                return .portrait
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            case .portraitUpsideDown:
                return .portraitUpsideDown
            default:
                return .portrait
            }
        }
        return .portrait
    }
    
    private func scale(faceRect: CGRect, imageSize: CGSize, viewSize: CGSize) -> CGRect {
        // faceRect = (295.0, 913.0, 498.0, 498.0)
        // imageSize = (1080.0, 1920.0)
        // viewSize = (390.0, 844.0)
        
        /*
         295.0 = 1080
         x = 390
         
         x = (point * 390)/1080
         x = (point * viewSize.width)/imageSize.width
         x = point * (viewSize.width/imageSize.width)
         widthScale = viewSize.width / imageSize.width
         x = point * widthScale
         
         ----
         
         913 = 1920
         y = 844
         
         y = 913 * 844 / 1920
         heightScale = viewSize.height / imageSize.height
         y = point * heightScale
         
         --
         */
        let faceRectX = imageSize.width - faceRect.minX - faceRect.width
        
        let widthScale = viewSize.width / imageSize.width
        let heightScale = viewSize.height / imageSize.height
        
        print("faceRect.minX: \(faceRect.minX); scaled: \(faceRect.minX * widthScale)")
        
        return CGRect(
            x: faceRectX * widthScale,
            y: (faceRect.minY * heightScale) - (faceRect.height * 0.1),
            width: faceRect.width * widthScale,
            height: faceRect.height * heightScale
        )
    }
    
    
    private func checkCameraPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }
    
    private func setupSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.beginConfiguration()
            
            // Setup camera input
            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                print("Camera initialized")
                do {
                    let input = try AVCaptureDeviceInput(device: camera)
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                    }
                } catch {
                    print("Error: Unable to add camera input to AVCaptureSession")
                }
            } else {
                print("Error: Camera not found")
            }
            
            // Setup video output
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera output"))
            if self.session.canAddOutput(output) {
                self.session.addOutput(output)
            }
            
            self.session.commitConfiguration()
            
            // Initialize and set the CameraCaptureHelper delegate
            self.cameraCaptureHelper = CameraCaptureHelper(cameraPosition: .front)
            self.cameraCaptureHelper?.delegate = self
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
                print("Session started running") // Debug print
            }
        }
    }
    private var exifOrientation: Int32 {
        let orientation = exifOrientationForCurrentDeviceOrientation()
        return Int32(orientation.rawValue)
    }
    
    private func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            switch windowScene.interfaceOrientation {
            case .portrait:
                return .right
            case .landscapeLeft:
                return .up
            case .landscapeRight:
                return .down
            case .portraitUpsideDown:
                return .left
            default:
                return .right
            }
        }
        return .right
    }
    
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        
        // Update the frame counter
        frameCounter += 1
        
        // Send every Nth frame to the server, for example, every 10th frame
        if frameCounter % 8 == 0 {
            DispatchQueue.main.async {
                // to get the correct orientation of the image
                let rotatedImage = ciImage.oriented(forExifOrientation: self.exifOrientation)
                self.cameraCaptureHelper?.delegate?.newCameraImage(self.cameraCaptureHelper!, image: rotatedImage)
            }
        }
    }
}

extension CameraViewModel {
    func newCameraImage(_ cameraCaptureHelper: CameraCaptureHelper, image: CIImage) {
        // Load CIImage into UIImage and convert it to Data for transfer to the server
        if let cgImage = CIContext().createCGImage(image, from: image.extent),
           let imageData = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.5) {
            
            let base64Image = imageData.base64EncodedString()
            
            let parameters: Parameters = [
                "img_data": base64Image
            ]
            
            AF.request("http://192.168.88.142:5001/predict",
                       method: .post,
                       parameters: parameters,
                       encoding: URLEncoding.httpBody,
                       headers: nil).responseDecodable(of: EmotionResponse.self) { [weak self] response in
                
                guard let self = self else { return }
                
                switch response.result {
                case .success(let emotionResponse):
                    if let emotion = emotionResponse.emotion {
                        DispatchQueue.main.async {
                            guard
                                let x = emotionResponse.x,
                                let y = emotionResponse.y,
                                let width = emotionResponse.w,
                                let height = emotionResponse.h
                            else {
                                return
                            }
                            
                            let faceRect = CGRect(x: x, y: y, width: width, height: height)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootView = windowScene.windows.first?.rootViewController?.view {
                                let scaledFaceRect = self.scale(faceRect: faceRect, imageSize: image.extent.size, viewSize: rootView.bounds.size)
                                self.detectedFace = scaledFaceRect
                            }
                            self.emotionText = emotion
                        }
                    } else if let error = emotionResponse.error, error == "No face detected" {
                        DispatchQueue.main.async {
                            self.detectedFace = CGRect()
                            self.emotionText = ""
                        }
                    }
                case .failure(let error):
                    print("Request error: \(error.localizedDescription)")
                    if let data = response.data {
                        let errorMessage = String(data: data, encoding: .utf8)
                        print("Server response: \(errorMessage ?? "No error message")")
                    }
                }
            }
        }
    }
}
