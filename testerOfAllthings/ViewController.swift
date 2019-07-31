//
//  ViewController.swift
//  testerOfAllthings
//
//  Created by Marisa Lu on 3/28/19.
//  Copyright © 2019 Marisa Lu. All rights reserved.
//

import UIKit
//import SwiftOSC
import Starscream
import AVFoundation

import CoreGraphics
import CoreMedia
import Foundation

//  var socket = WebSocket(url: URL(string: "ws://localhost:1337/")!, protocols: ["chat"])
var socket = WebSocket(url: URL(string: "ws://172.20.10.4:1337")!, protocols: ["chat"])

//var socket = WebSocket(url: URL(string: "ws://1ce651c6.ngrok.io:1337")!, protocols: ["chat"])

var username = "newUser"
//var partnerName: String? = nil
var partnerName = "nada"
//var client = OSCClient(address: "", port: 54321) //54321 recieving and address needs to be the other phone's IP on the same shared network

var hasStarted = false
var fingerOn = false

//class ViewController: UIViewController, OSCServerDelegate {
class ViewController: UIViewController, UITextFieldDelegate, AVCaptureVideoDataOutputSampleBufferDelegate{
    @IBOutlet weak var heartContainer:UIView!
    @IBOutlet weak var connectorView:UIView!
    @IBOutlet weak var fingerPicture:UIImageView!
    @IBOutlet weak var fingerInstructions:UILabel!
    let scaleAnimation:CABasicAnimation = CABasicAnimation(keyPath: "transform.scale")
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    let captureSession = AVCaptureSession()
    
    private lazy var partnerHeartView: GradientView = {
        let view = GradientView()
        view.topColor = UIColor(hex: 0xFF5B50)
        view.bottomColor = UIColor(hex: 0xFFC950)
        return view
    }()
    override func viewDidLoad() {
        print("viewDidLoad()")
        super.viewDidLoad()
        socket.delegate = self
        //socket.connect()
        
        //making the heart shadowed and rounded
        //heartContainer.layer.cornerRadius = 38.0
//        heartContainer.layer.shadowColor = UIColor.black.cgColor
//        heartContainer.layer.shadowOffset = CGSize(width:0, height: 0)
//        heartContainer.layer.shadowOpacity = 0.4
//        heartContainer.layer.shadowRadius = 30.0
//        heartContainer.layer.shadowPath = UIBezierPath(rect: heartContainer.bounds).cgPath
        //heartContainer.layer.shouldRasterize = true
        
        self.connectorView.layer.opacity = Float(0.0)
        
        //heartContainer.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(heartToggle)))
        
        //server.start()
        //server.delegate =  OSCHandler()
        // Do any additional setup after loading the view.
        heartContainer.addSubview(partnerHeartView)
        partnerHeartView.center(in: heartContainer)
        partnerHeartView.bounds = CGRect(x: 0, y: 0, width: self.heartContainer.bounds.width, height: self.heartContainer.bounds.height)
partnerHeartView.widthAnchor.constraint(equalToConstant:self.heartContainer.bounds.width).isActive = true
partnerHeartView.heightAnchor.constraint(equalToConstant:self.heartContainer.bounds.height).isActive = true
        partnerHeartView.isHidden = true
        setupForHeartCapture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        //make the connection name input stuff animate in
        connectorView.center.y = self.view.bounds.height/CGFloat(5)//set the y further away
        UIView.animate(withDuration: 1.1, delay: 0.5, usingSpringWithDamping: 0.2, initialSpringVelocity: 0, options: .curveEaseInOut, animations: {
            self.connectorView.center.y -= self.view.bounds.height/CGFloat(12)
            self.connectorView.layer.opacity = Float(1.0)
        },
            completion: nil
        )
        //add in the preview layer from the camera
        //heartContainer.layer.addSublayer(previewLayer)
        connectorView.layer.addSublayer(previewLayer)
        if(!fingerOn){//if the finger isn;t on, the preview should be off too
            self.previewLayer.opacity = 0.0
        }
        
    }
    deinit {
        socket.disconnect(forceTimeout: 0)
        socket.delegate = nil
    }
    func heartbeatAnimation(){
        scaleAnimation.duration = 0.15
        scaleAnimation.repeatCount = 1.0
        scaleAnimation.autoreverses = true
        scaleAnimation.fromValue = 0.86;
        scaleAnimation.toValue = 0.92;
        self.partnerHeartView.layer.add(scaleAnimation, forKey: "scale")
        //self.heartContainer.layer.add(scaleAnimation, forKey: "scale")
    }
    @objc func heartToggle(){
        if(!hasStarted){
            UIView.animate(withDuration: 0.3){
                let transformNum = CGFloat(0.9)
                self.heartContainer.transform = CGAffineTransform(scaleX: transformNum, y: transformNum)
            }
            setupForHeartCapture()
            captureSession.startRunning()
            feedbackGenerator.impactOccurred()
            hasStarted = true
            
            heartbeatAnimation()
            return
        }else if (captureSession.isRunning){
            toggleTorch(on: false)
            captureSession.stopRunning()
            UIView.animate(withDuration: 0.1){
                let transformNum = CGFloat(1.0)
                self.heartContainer.transform = CGAffineTransform(scaleX: transformNum, y: transformNum)
                self.previewLayer.opacity = 0.2
            }
            feedbackGenerator.impactOccurred()
            socket.write(string:"stopped")
        }else if (!captureSession.isRunning){
            UIView.animate(withDuration: 0.1){
                let transformNum = CGFloat(0.9)
                self.heartContainer.transform = CGAffineTransform(scaleX: transformNum, y: transformNum)
                self.previewLayer.opacity = 1.0
            }
            feedbackGenerator.impactOccurred()
            captureSession.startRunning()
            toggleTorch(on: true)//the device in the capture session has to be up and running before we can toggle on or off the torch
        }

    }
    @IBAction func handleTap(recognizer: UITapGestureRecognizer){//get rid of keyboards
        self.resignFirstResponder()
    }
    @IBOutlet weak var nameOfPartner: UITextField!
    @IBAction func setPartnerName(_ sender: UITextField) {
        partnerName = nameOfPartner?.text ?? "Nada"
        partnerName = partnerName.lowercased()
        print("partnerName: \(String(describing: nameOfPartner))")
        
        //check if partner is on the network
    }
    
    @IBOutlet weak var nameOfUser: UITextField!
    @IBAction func setUser(_ sender: UITextField) {
        username = nameOfUser?.text ?? ""
        if (!(username == "")){
            socket.connect()
            print("hello, pls connecttttt")
        }
        
    }
    
    //ensure the keyboardd coming up pushes content
    /*
    @IBOutlet var ScrollView: UIScrollView!
    func textFieldDidBeginEditing(_ textField: UITextField) {
        ScrollView.setContentOffset(CGPoint(x:0.0,y:250.0), animated: true)
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
     ScrollView.setContentOffset(CGPoint(x:0.0,y:0.0), animated: true)
    }
     */
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
 
    func setupForHeartCapture(){
        // Prepare the generator when the finger is on.
        feedbackGenerator.prepare()
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = AVCaptureSession.Preset.low
        
        //specifying device
        let videoDevice = AVCaptureDevice.default(for: .video)
        
        guard
            let deviceInput = try? AVCaptureDeviceInput(device: videoDevice!),
            captureSession.canAddInput(deviceInput)
            else { return }
        captureSession.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as
            AnyHashable: Int(kCVPixelFormatType_32BGRA)] as! [String : Any]
        //dataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)] as [String : Any]
        //^video settings have all the different compression settings keys or the pixel buffer attributes so...cuz i really only need the image's overall luminance we're getting a RBGA signal turned into a gray level one that is done directly in hardware
        dataOutput.alwaysDiscardsLateVideoFrames = true
        
        guard captureSession.canAddOutput(dataOutput) else { return }
        captureSession.addOutput(dataOutput)
        
        captureSession.commitConfiguration()
        
        captureSession.startRunning()
        
        //toggleTorch(on: true)//turn that flashlight on!
        
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        //dataOutput.setSampleBufferDelegate(self, queue: dispatch_get_main_queue())
        //have this function create timer or loop, and have the loop sleep for 16 miliseconds and access the frames — a concurrent queue to access that camera buffer and pull those frames (if there's a way to have a callback run on the main thread) set dispatch queue that executes a delegate on teh main thread

        feedbackGenerator.impactOccurred()
        
    }
    var previousBrightness: Float = 0.0
    var previousChange: Float = 0.0
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("captureOutput")
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        //let bitsPerComponent = 8
        //let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)!
        let byteBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var totalR = 0
        var totalG = 0
        var totalB = 0
        var totalSamples = 0
        for row in stride(from:0, to: height, by:10){
            for col in stride(from:0, to: width, by:10){
                let index = (row * width + col) * 4
                let b = byteBuffer[index]
                let g = byteBuffer[index+1]
                let r = byteBuffer[index+2]
                totalR = totalR + Int(r)
                totalG = totalG + Int(g)
                totalB = totalB + Int(b)
                totalSamples += 1
                //                if r > UInt8(128)
            }
        }
//        for row in 0...height {
//            for col in 0...width {
//
//        }
//        let avgG = Float(totalG)/Float(height*width/100)
//        let avgB = Float(totalB)/Float(height*width/100)
//        print("RGB: \(avgR), \(avgG), \(avgB)")
        if(!fingerOn && totalR*2 - (totalG + totalB) > totalR && totalR/totalSamples > 50){
            fingerOn = true;
            toggleTorch(on: true)
            DispatchQueue.main.async {
                self.previewLayer.opacity = 1.0
                self.feedbackGenerator.impactOccurred()
                socket.write(string:"started")
                self.fingerInstructions.text = "Great! Your beats will send, now we wait for the other party"
                UIView.animate(withDuration: 1){
                    self.fingerPicture.alpha = 0
                }
            }
        }else if (fingerOn && totalR > height*width) {//if sufficiently red, and therefore finger, we go ahead and start recording those values
//            let avgBrightness = (avgR + avgG + avgB) * 1000.0
            //let avgBrightness = avgR * 1000.0
            //let changeInBrightness = avgBrightness - previousBrightness
            

            let changeInBrightness = Float(totalR) - previousBrightness
            print("changeInBrightness: \(changeInBrightness)")
            if(changeInBrightness < 0 && previousChange > 0){ //peaked
                socket.write(string: "intoTheVoid")
            }else if(changeInBrightness > 0 && previousChange < 0){
                //dipped
                
            }else{
               
            }
            previousChange = changeInBrightness;
            previousBrightness = Float(totalR);
        }else if (fingerOn){
            fingerOn = false
            toggleTorch(on: false)
            DispatchQueue.main.async {
                socket.write(string:"stopped")
                self.previewLayer.opacity = 0.0
                self.feedbackGenerator.impactOccurred()
                self.fingerInstructions.text = "Put finger on back-camera to capture your heartbeat"
                UIView.animate(withDuration: 1){
                    self.fingerPicture.alpha = 1.0
                }
            }
        }
    }

    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview =  AVCaptureVideoPreviewLayer(session: self.captureSession)
        preview.bounds = CGRect(x: 0, y: 0, width: self.nameOfUser.bounds.height * 0.5, height: self.nameOfUser.bounds.height * 0.5)
        preview.position = CGPoint(x: self.nameOfUser.bounds.height * 0.75, y: self.connectorView.bounds.maxY - 21.33 - self.nameOfUser.bounds.height * 0.5)
        preview.cornerRadius = self.nameOfUser.bounds.height * 0.25
//        preview.bounds = CGRect(x: 0, y: 0, width: self.heartContainer.bounds.width, height: self.heartContainer.bounds.height)
//        preview.position = CGPoint(x: self.heartContainer.bounds.midX, y: self.heartContainer.bounds.midY)
//        preview.cornerRadius = 38.0
//        preview.cornerRadius = 38.0
//        preview.shadowColor = UIColor.black.cgColor
//        preview.shadowOffset = CGSize(width:0, height: 0)
//        preview.shadowOpacity = 0.4
//        preview.shadowRadius = 30.0
//        preview.shadowPath = UIBezierPath(rect: heartContainer.bounds).cgPath
        
        preview.videoGravity = AVLayerVideoGravity.resize
        
        return preview
    }()
}

func toggleTorch(on: Bool) {
    guard let device = AVCaptureDevice.default(for: .video) else { return }
    
    if device.hasTorch {
        do {
            try device.lockForConfiguration()
            
            if on == true {
                device.torchMode = .on
            } else {
                device.torchMode = .off
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used")
        }
    } else {
        print("Torch is not available")
    }
}
// MARK: - WebSocketDelegate
extension ViewController : WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient) {
        print("websocket connection for \(username)")
        socket.write(string:username)
        
        let alert = UIAlertController(title: "You are on the network!", message: "Now just specify who you want to exchange heart beats with in real time", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true)
        feedbackGenerator.impactOccurred()
        
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        
        print("websocketDidDisconnect")
        //this should pop the user back to the username screen if the socket disconnects for whatever reason...tbh idk
        //GOT AN ERROR FOR no segue with identifier
        //performSegue(withIdentifier: "websocketDisconnected", sender: self)
        
        let alert = UIAlertController(title: "Disconnected from Network", message: "marisa needs to run stuff on her laptop", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true)
        feedbackGenerator.impactOccurred()
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        
        print("text: \(text)")
        //so the text is revcieved quite literally as plain text, but formatted like JSON, so we gotta convert it into a colelction of objects
        
        // 1. Convert the string to NSData and 2. then pass it into JSON serialization, and 3. check that the important keys are there and there the data is valid
        guard let data = text.data(using: .utf16),
            let jsonData = try? JSONSerialization.jsonObject(with: data),
            let jsonDict = jsonData as? [String: Any],
            let messageType = jsonDict["type"] as? String else {
                return
        }
//        print("data or text.data is  \(data)")
//        print("jsonData  \(jsonData)")
//        print("jsonDict  \(jsonDict)")
        // 2. yeah, so then we filter through the message type to extract what we want, in this case, "message"
        if messageType == "message",
            let messageData = jsonDict["data"] as? [String: Any],
            let messageAuthor = messageData["author"] as? String,
            let messageText = messageData["text"] as? String {
            
            messageReceived(messageText, senderName: messageAuthor)
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("data:  \(data)")
    }
}

extension UITextField{
    @IBInspectable var placeHolderColor: UIColor? {
        get {
            return self.placeHolderColor
        }
        set {
            self.attributedPlaceholder = NSAttributedString(string:self.placeholder != nil ? self.placeholder! : "", attributes:[NSAttributedStringKey.foregroundColor: newValue!])
        }
    }
}

fileprivate extension ViewController {
    
    func sendMessage(_ message: String) {
        print("socket writing: \(message)")
        socket.write(string: message)
        //feedbackGenerator.impactOccurred()
    }
    func messageReceived(_ message: String, senderName: String){
        print("message: \(message) from \(senderName)")
        let sender = senderName.lowercased()
        if(sender == partnerName || sender.contains(partnerName) || partnerName.contains(sender)){
            if(message == "stopped"){
                self.partnerHeartView.isHidden = true
            }else if(message == "started"){
                self.partnerHeartView.isHidden = false
            }
            else{
                feedbackGenerator.impactOccurred()
                //self.partnerHeartView.isHidden = false
                heartbeatAnimation()
            }
        }
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    /// Convenience wrapper to get layer as its statically known type.
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

/*
 class OSCHandler: OSCServerDelegate {
 func didReceive(_ message: OSCMessage) {
 if let integer = measure.arguments[0] as? Int {
 print("Recieve int \(integer)")
 } else {
 print(message)
 }
 <#code#>
 }
 }
 */

