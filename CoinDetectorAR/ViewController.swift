//
//  ViewController.swift
//  CoinDetectorAR
//
//  Created by YUKITO on 2022/06/16.
//

import UIKit
import RealityKit
import Vision

import PencilKit
import ARKit

class ViewController: UIViewController {
    
    /// Main AR View
    @IBOutlet var arView: ARView!
    
    /// PencilKit Canvas
    let canvasContainer = UIView()
    
    let canvasView = PKCanvasView()
    
    let pencilButton = UIButton()
    
    let cancelButton = UIButton()
    
    let clearButton = UIButton()
    
    @objc let submitButton = UIButton()
    
    /// Predictions of the CoinDetector
    var predictions = [Int]()
    
    /// Prediction bounds
    var predictionBounds = [CGRect]()
    
    /// The number of storing elements of prediction
    let keepLast = 15
    
    /// CanvasView input
    var didEnterInput = false
    
    /// Root layer which is the layer of the arView
    var rootLayer: CALayer!
    
    /// Overlay view for the bounding boxes
    var detectionOverlay: CALayer! = nil

    /// Whether the current frame should be skipped (in terms of model predictions)
    var shouldSkipFrame = 0
    /// How often (in terms of camera frames) should the app run predictions
#if DEBUG
    let predictEvery = 12
#else
    let predictEvery = 2
#endif
    /// Concurrent queue to be used for model predictions
    let predictionQueue = DispatchQueue(label: "predictionQueue",
                                        qos: .userInitiated,
                                        attributes: [],
                                        autoreleaseFrequency: .inherit,
                                        target: nil)
    
    /// The last known image orientation
    /// When the image orientation changes, the buffer size used for rendering boxes needs to be adjusted
    var lastOrientation: CGImagePropertyOrientation = .right

    /// Size of the camera image buffer (used for overlaying boxes)
    var bufferSize: CGSize! {
        didSet {
            if bufferSize != nil {
                if oldValue == nil {
                    // setupLayers()
                } else if oldValue != bufferSize {
                    updateFrames()
                    updateDetectionOverlaySize()
                }
            }
        }
    }
    
    // Vision request tasks
    var requests = [VNRequest]()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpVision()
        
        arView.session.delegate = self
        
        // Show statistics
        // arView.inputView.showStatistics
        arView.debugOptions.insert(.showStatistics)
        // arView.debugOptions.insert(.showWorldOrigin)
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        rootLayer = arView.layer
        
        setupLayers()
        setupViews()
        
        guard ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) else {
            print("People occlusion is not supported on this device.")
            return
        }
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapRecognizer)
        arView.environment.sceneUnderstanding.options = .occlusion
    }
    
    func setUpVision() {
        // Load the detection models
        /// - Tag: SetupVisionRequest
        guard let mlModel = try? CoinDetector(configuration: .init()).model,
              let detector = try? VNCoreMLModel(for: mlModel) else {
            print("Failed to load detector!")
            return
        }
        
        // Use a threshold provider to specify custom thresholds for the object detector.
        // detector.featureProvider = ThresholdProvider()
        
        let coinDetectionRequest = VNCoreMLRequest(model: detector) { [weak self] request, error in
            if let results = request.results {
                self?.detectionRequestHandler(results)
            }
        }
        
        // .scaleFill results in a slight skew but the model was trained accordingly
        // see https://developer.apple.com/documentation/vision/vnimagecropandscaleoption for more information
        coinDetectionRequest.imageCropAndScaleOption = .scaleFill
        
        self.requests = [coinDetectionRequest]
    }
    
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: arView.frame.width,
                                         height: arView.frame.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }
    
    func setupViews() {
        
        let width = min(view.frame.width, view.frame.height) * 0.8
        
        canvasContainer.addSubview(canvasView)
        canvasView.frame = CGRect(x: 0, y: 0, width: width, height: width * 0.6)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.tool = PKInkingTool(.marker, color: .black, width: 40)
        canvasView.delegate = self
        canvasContainer.layer.cornerCurve = .continuous
        canvasContainer.layer.cornerRadius = 30
        canvasView.drawingPolicy = PKCanvasViewDrawingPolicy.anyInput
        
        // let tap = UITapGestureRecognizer(target: self, action: #selector(clearCanvas))
        // tap.numberOfTapsRequired = 3
        // view.addGestureRecognizer(tap)
        
        let blurEffect = UIBlurEffect(style: .light)
        let visualEffectView = UIVisualEffectView(effect: blurEffect)
        
        visualEffectView.frame = CGRect(x: 30, y: 40, width: 80, height: 80)
        visualEffectView.layer.cornerRadius = 20
        visualEffectView.layer.cornerCurve = .continuous
        visualEffectView.clipsToBounds = true
        // self.view.addSubview(visualEffectView)
        
        view.addSubview(pencilButton)
        pencilButton.backgroundColor = .secondarySystemBackground
        pencilButton.tintColor = .secondaryLabel
        let config1 = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        pencilButton.setImage(UIImage(systemName: "pencil.and.outline", withConfiguration: config1), for: .normal)
        pencilButton.frame = CGRect(x: 30, y: 40, width: 80, height: 80)
        pencilButton.layer.cornerCurve = .continuous
        pencilButton.layer.cornerRadius = 20
        pencilButton.addTarget(self, action: #selector(openCanvas), for: .touchUpInside)
        
        view.addSubview(canvasContainer)
        canvasContainer.frame = CGRect(x: 0, y: 0, width: width, height: 0.6 * width)
        canvasContainer.backgroundColor = .secondarySystemBackground
        canvasContainer.center = view.center
        canvasContainer.layer.cornerCurve = .continuous
        canvasContainer.layer.cornerRadius = 30
        canvasContainer.alpha = 0
        
        canvasContainer.addSubview(cancelButton)
        cancelButton.backgroundColor = .systemGray4
        cancelButton.tintColor = .secondaryLabel
        let config2 = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        cancelButton.setImage(UIImage(systemName: "xmark", withConfiguration: config2), for: .normal)
        cancelButton.frame = CGRect(x: 20, y: 20, width: 40, height: 40)
        cancelButton.layer.cornerCurve = .continuous
        cancelButton.layer.cornerRadius = 20
        cancelButton.addTarget(self, action: #selector(closeCanvas), for: .touchUpInside)
        
        canvasContainer.addSubview(submitButton)
        submitButton.backgroundColor = .systemBlue
        submitButton.tintColor = .white
        submitButton.setImage(UIImage(systemName: "arrow.up", withConfiguration: config2), for: .normal)
        submitButton.frame = CGRect(x: canvasContainer.frame.width - 60, y: 20, width: 40, height: 40)
        submitButton.layer.cornerRadius = 20
        submitButton.addTarget(self, action: #selector(submitAction), for: .touchUpInside)
        
        canvasContainer.addSubview(clearButton)
        clearButton.backgroundColor = .clear
        clearButton.tintColor = .systemRed
        clearButton.setImage(UIImage(systemName: "paintbrush", withConfiguration: config2), for: .normal)
        clearButton.frame = CGRect(x: canvasContainer.frame.width - 120, y: 20, width: 40, height: 40)
        clearButton.layer.cornerRadius = 20
        clearButton.layer.borderColor = UIColor.systemRed.cgColor
        clearButton.layer.borderWidth = 2
        clearButton.addTarget(self, action: #selector(clearCanvasAction), for: .touchUpInside)
    }
    
    @objc
    func closeCanvas(sender: UIButton) {
        canvasContainer.transform = CGAffineTransform(scaleX: 1, y: 1)
        canvasContainer.alpha = 1
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: .curveEaseOut) { [self] in
            canvasContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            canvasContainer.alpha = 0
            pencilButton.alpha = 1
        } completion: { bool in
            self.clearCanvas()
        }
    }
    
    @objc
    func clearCanvasAction(sender: UIButton) {
        clearCanvas()
    }
    
    @objc
    func openCanvas(sender: UIButton) {
        canvasContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        canvasContainer.alpha = 0
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: .curveEaseInOut) { [self] in
            canvasContainer.transform = CGAffineTransform(scaleX: 1, y: 1)
            canvasContainer.alpha = 1
            pencilButton.alpha = 0
        } completion: { bool in
            
        }
    }
    
    @objc func submitAction(sender: UIButton) {
        submit()
    }
    
    func submitUiHandler(isCorrect: Bool) {
        clearCanvas()
        if isCorrect {
            UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .curveEaseIn) { [self] in
                canvasContainer.transform = CGAffineTransform(translationX: 0, y: -1 * view.frame.height / 2 - canvasView.frame.height / 2 - 50)
                canvasContainer.alpha = 1
                pencilButton.alpha = 1
            } completion: { bool in
                self.canvasContainer.transform = CGAffineTransform.identity
                self.canvasContainer.alpha = 0
                self.clearCanvas()
            }
        } else {
            canvasContainer.shakeHorizontal(duration: 0.8)
        }
    }
    
    func updateFrames() {
        DispatchQueue.main.async {
            self.canvasView.frame = self.view.frame
        }
    }
}
