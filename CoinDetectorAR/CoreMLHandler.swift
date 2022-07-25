//
//  CoreMLHandler.swift
//  CoinDetectorAR
//
//  Created by YUKITO on 2022/06/16.
//

import Foundation
import UIKit
import Vision

extension ViewController {
    
    /// Update the size of the overlay layer if the sceneView size changed
    func updateDetectionOverlaySize() {
        DispatchQueue.main.async {
            self.detectionOverlay.bounds = CGRect(x: 0.0, y: 0.0, width: self.arView.frame.width, height: self.arView.frame.height)
        }
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / arView.frame.height
        let yScale: CGFloat = bounds.size.height / arView.frame.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
    }
    
    func detectionRequestHandler(_ results: [VNObservation]) {
        var sum = 0
        
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // remove all the old recognized objects
        detectionOverlay.sublayers = nil
        predictionBounds = []
        
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            
            // Select only the label with the highest confidence.
            let topLabelObservation = objectObservation.labels[0]
            
            // Create Coin object and add sum
            let coin = Coin(topLabelObservation.identifier)
            sum += coin.price
            
            let objectBounds = bounds(for: objectObservation)
            let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
            predictionBounds.append(objectBounds)
            
            let textLayer = self.createTextSubLayerInBounds(objectBounds, coinType: coin, confidence: topLabelObservation.confidence)
            
            #if DEBUG
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
            #endif
        }
        
        self.updateLayerGeometry()
        CATransaction.commit()
        
        // print(sum)
        
        predictions.append(sum, keep: keepLast)
    }
    
    func bounds(for observation: VNRecognizedObjectObservation) -> CGRect {
        let boundingBox = observation.boundingBox
        // Coordinate system is like macOS, origin is on bottom-left and not top-left

        // The resulting bounding box from the prediction is a normalized bounding box with coordinates from bottom left
        // It needs to be flipped along the y axis
        let fixedBoundingBox = CGRect(x: boundingBox.origin.x,
                                      y: 1.0 - boundingBox.origin.y - boundingBox.height,
                                      width: boundingBox.width,
                                      height: boundingBox.height)

        // Return a flipped and scaled rectangle corresponding to the coordinates in the arView
        return VNImageRectForNormalizedRect(fixedBoundingBox, Int(arView.frame.width), Int(arView.frame.height))
    }
    
    func createTextSubLayerInBounds(_ bounds: CGRect, coinType: Coin, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let price = String(coinType.price)
        let formattedString = NSMutableAttributedString(string: String(format: "\(price)\n%.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 32.0)!
        let smallFont = UIFont(name: "Helvetica", size: 16.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: price.count))
        formattedString.addAttributes([NSAttributedString.Key.font: smallFont], range: NSRange(location: price.count, length: formattedString.length - price.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        return textLayer
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.2, 0.8, 1.0, 0.4])
        shapeLayer.cornerRadius = 21
        return shapeLayer
    }
}
