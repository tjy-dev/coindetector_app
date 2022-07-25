//
//  HandPoseHandler.swift
//  CoinDetectorAR
//
//  Created by Tajima Yukito on 2022/07/13.
//

import Foundation
import CoreML
import Vision
import UIKit

extension ViewController {
    func handPoseRequestHandler(_ results: [VNObservation]) {
        for observation in results where observation is VNHumanHandPoseObservation {
            guard let handObservation = observation as? VNHumanHandPoseObservation else {
                return
            }
            do {
                let thumbPoints = try handObservation.recognizedPoints(.thumb)
                let indexFingerPoints = try handObservation.recognizedPoints(.indexFinger)
                // Look for tip points.
                guard let thumbTipPoint = thumbPoints[.thumbTip], let indexTipPoint = indexFingerPoints[.indexTip] else {
                    return
                }
                // Ignore low confidence points.
                guard thumbTipPoint.confidence > 0.3 && indexTipPoint.confidence > 0.3 else {
                    return
                }
                                
                let thumbPointConverted = CGPoint(x: thumbTipPoint.x * detectionOverlay.bounds.width, y: (1 - thumbTipPoint.y) * detectionOverlay.bounds.height)
                let indexPointConverted = CGPoint(x: indexTipPoint.x * detectionOverlay.bounds.width, y: (1 - indexTipPoint.y) * detectionOverlay.bounds.height)
                
                drawFingerPoints((indexPointConverted, thumbPointConverted))
                
                DispatchQueue.main.async { [self] in
                    processPoint((indexPointConverted, thumbPointConverted))
                }
            } catch {
                
                print("Error: couldn't recognized finger points")
            }
        }
        
    }
    
    func drawFingerPoints(_ points: (index: CGPoint, thumb: CGPoint)) {
        DispatchQueue.main.async { [self] in
            let shapeLayer = CALayer()
            shapeLayer.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)
            shapeLayer.position = points.thumb
            shapeLayer.name = "Found Object"
            shapeLayer.backgroundColor = UIColor.systemBlue.cgColor
            detectionOverlay.addSublayer(shapeLayer)
        }
        
        DispatchQueue.main.async { [self] in
            let shapeLayer = CALayer()
            shapeLayer.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)
            shapeLayer.position = points.index
            shapeLayer.name = "Found Object"
            shapeLayer.backgroundColor = UIColor.systemRed.cgColor
            detectionOverlay.addSublayer(shapeLayer)
        }
    }
    
    func didChangeState(state: HandPoseState.State) {
        
    }
}
