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
    
    // MARK: ARView
    /// Main AR View
    @IBOutlet var arView: ARView!
    /// Root layer which is the layer of the arView
    var rootLayer: CALayer!
    /// Overlay view for the bounding boxes
    var detectionOverlay: CALayer! = nil
    
    // MARK: PK Input
    var inputCanvas = InputViewController()
    var arInputCanvas = InputViewController()

    // MARK: Main Buttons
    let pencilButton = UIButton()
    
    // MARK: Coin Detector
    /// Predictions of the CoinDetector
    var predictions = [Int]()
    /// Prediction bounds of the detected objects
    var predictionBounds = [CGRect]()
    /// The number of storing elements of prediction
    let keepLast = 15
    /// Whether the current frame should be skipped (in terms of model predictions), used globally
    var shouldSkipFrame = 0
    /// How often (in terms of camera frames) should the app run predictions
    #if DEBUG
    let predictEvery = 6
    #else
    let predictEvery = 1
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
    
    // MARK: Hand Pose
    var handPoseProcessor = HandPoseProcessor()
    var movingObject: Entity? = nil

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
    // var handPoseRequests = [VNDetectHumanHandPoseRequest]()
    
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
        
        let handPoseRequest = VNDetectHumanHandPoseRequest() { [weak self] request, error in
            if let results = request.results {
                self?.handPoseRequestHandler(results)
            }
        }
        
        handPoseProcessor.didChangeState = { [weak self] state in
            self?.didChangeState(state: state)
        }
        
        self.requests = [coinDetectionRequest, handPoseRequest]
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
        
        inputCanvas.modalPresentationStyle = .overCurrentContext
        inputCanvas.submitted = { [self] int in
            let isCorrect = validateAnswer(int)
            inputCanvas.submitUiHandler(isCorrect: isCorrect)
            if isCorrect {
                placeAnswer(int)
            }
        }
        
        arInputCanvas.modalPresentationStyle = .overCurrentContext
        arInputCanvas.submitted = { [self] int in
            let isCorrect = validateAnswer(int)
            arInputCanvas.submitUiHandler(isCorrect: isCorrect)
            if isCorrect {
                placeAnswer(int)
            }
        }
        
        view.addSubview(pencilButton)
        pencilButton.backgroundColor = .secondarySystemBackground
        pencilButton.tintColor = .secondaryLabel
        let config1 = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        pencilButton.setImage(UIImage(systemName: "pencil.and.outline", withConfiguration: config1), for: .normal)
        pencilButton.frame = CGRect(x: 30, y: 40, width: 80, height: 80)
        pencilButton.layer.cornerCurve = .continuous
        pencilButton.layer.cornerRadius = 20
        pencilButton.addTarget(self, action: #selector(openCanvas), for: .touchUpInside)
    }
    
    @objc
    func openCanvas(sender: UIButton) {
        self.present(inputCanvas, animated: false)
    }
    
    func updateFrames() {
        inputCanvas.updateFrames()
    }
    
    func validateAnswer(_ input: Int) -> Bool {
        guard let topFrequent = predictions.mostFrequent()?.mostFrequent.last else {
            return false
        }
        return input == topFrequent
    }
}
