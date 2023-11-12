//
//  ContentView.swift
//  HumanVerify IOS APP
//
//  Created by Max Stefankiv on 18.04.2023.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var showCamera = false
    
    var body: some View {
        ZStack {
            if showCamera {
                CameraView(session: cameraViewModel.session)
                    .ignoresSafeArea()
                    .overlay(OverlayShape(rect: cameraViewModel.detectedFace))
                    .onAppear {
                        cameraViewModel.startSession()
                    }
                    .onDisappear {
                        cameraViewModel.stopSession()
                    }
                Text(cameraViewModel.emotionText)
                    .font(.system(size: 24))
                    .bold()
                    .foregroundColor(.red)
                    .position(x: cameraViewModel.detectedFace.midX, y: cameraViewModel.detectedFace.minY - 15)
                    .opacity(cameraViewModel.emotionText.isEmpty ? 0 : 1)
                Button(action: {
                    showCamera = false
                }) {
                    Text("Закрити камеру")
                        .font(.title)
                        .bold()
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .position(x: UIScreen.main.bounds.width - 180, y: 50)
            } else {
                VStack {
                    Text("HumanVerify")
                        .font(.largeTitle)
                        .bold()
                        .padding(.bottom, 50)
                    Button(action: {
                        showCamera.toggle()
                    }) {
                        Text("Відкрити камеру")
                            .font(.title)
                            .bold()
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    let session: AVCaptureSession
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        viewController.view.layer.addSublayer(previewLayer)
        previewLayer.frame = viewController.view.bounds
        viewController.view.layer.masksToBounds = true
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let previewLayer = uiViewController.view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiViewController.view.bounds
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct OverlayShape: View {
    var rect: CGRect

    var body: some View {
        RoundedRectangle(cornerRadius: 50)
            .stroke(Color.red, lineWidth: 4)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .opacity(rect == CGRect() ? 0 : 1)
    }
}
