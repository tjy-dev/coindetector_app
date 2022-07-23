//
//  PencilKitView.swift
//  CoinDetectorAR
//
//  Created by YUKITO on 2022/06/16.
//

import Foundation
import UIKit
import PencilKit
import Vision

extension InputViewController {
    
    func submit() {
        var rects = [CGRect]()
        
        rects = canvasView.drawing.strokes.map { $0.renderBounds }
        
        if rects.isEmpty {
            submitUiHandler(isCorrect: false)
            return
        }
        
        var intersections = findIntersections(rects: rects)
        
        // Combining the CGRects
        for j in 0..<intersections.count {
            if intersections[j].0 != intersections[j].1 {
                rects[intersections[j].0] = combine(rects[intersections[j].0], rects[intersections[j].1])
                rects[intersections[j].1] = .zero
            }
            for i in j+1..<intersections.count {
                if intersections[i].0 == intersections[j].1 {
                    intersections[i] = (intersections[j].0, intersections[i].1)
                } else if intersections[i].1 == intersections[j].1 {
                    intersections[i] = (intersections[i].0, intersections[j].0)
                }
            }
        }
        
        let answer = obtainFullInput(rects: rects)
        submitted?(answer)
    }
    
    func obtainFullInput(rects: [CGRect]) -> Int {
        let model = try! VNCoreMLModel(for: MNISTClassifier(configuration: MLModelConfiguration()).model)
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFit
        
        // Obtain the answer from canvas
        let answer = rects
            .filter { $0 != .zero }
            // Sort from the right (134 → [4,3,1])
            .sorted { $0.minX > $1.minX }
            .map { canvasView.drawing.image(from: $0, scale: 1) }
            // Observe the valus
            .map { observe(request: request, image: $0) ?? 0 }
            // Comute the answer
            .enumerated()
            .reduce(0) {
                $0 + 10.pow(min($1.0, 9)) * $1.1
            }
        
        return answer
    }
    
    func combine(_ a: CGRect, _ b: CGRect) -> CGRect {
        let width: CGFloat = max(a.maxX - b.minX, b.maxX - a.minX, a.width, b.width)
        let height: CGFloat = max(a.maxY - b.minY, b.maxY - a.minY, a.height, b.height)
        return CGRect(x: min(a.minX, b.minX), y: min(a.minY, b.minY), width: width, height: height)
    }
    
    func intersects(_ a: CGRect, _ b: CGRect) -> Bool {
        if a.maxX - b.minX <= 0 || b.maxX - a.minX <= 0 {
            return false
        }
        if a.maxY - b.minY <= 0 || b.maxY - a.minY <= 0 {
            return false
        }
        
        let diffX = min(a.maxX - b.minX, b.maxX - a.minX)
        let diffY = min(a.maxY - b.minY, b.maxY - a.minY)
        
        let ratioA = (diffX * diffY) / (a.width * a.height)
        let ratioB = (diffX * diffY) / (b.width * b.height)
        let ratio = max(ratioA, ratioB)
        
        return ratio > 0.1
    }
    
    func findIntersections(rects: [CGRect]) -> [(Int, Int)] {
        var pairs: [(Int, Int)] = []
        for i in 0..<rects.count {
            for j in i+1..<rects.count {
                if i != j, intersects(rects[i], rects[j]) {
                    pairs.append((i, j))
                }
            }
        }
        return pairs
    }
    
    func observe(request: VNCoreMLRequest, image: UIImage) -> Int? {
        let image = UITraitCollection.isDarkMode ? image.cgImage : image.invertColor()
        
        guard let cgImage = image else {
            return nil
        }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try! requestHandler.perform([request])
        let results = request.results
        
        guard let observations = results as? [VNClassificationObservation] else {
            // Image classifiers, like MobileNet, only produce classification observations.
            // However, other Core ML model types can produce other observations.
            // For example, a style transfer model produces `VNPixelBufferObservation` instances.
            print("VNRequest produced the wrong result type: \(type(of: request.results)).")
            return nil
        }
        return Int(observations[0].identifier) ?? 0
    }
}
