//
//  ARView.swift
//  CoinDetectorAR
//
//  Created by YUKITO on 2022/06/16.
//

import Foundation
import ARKit
import RealityKit

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        shouldSkipFrame = (shouldSkipFrame + 1) % predictEvery
        
        if shouldSkipFrame > 0 { return }
        
        predictionQueue.async {
            /// - Tag: MappingOrientation
            // The frame is always oriented based on the camera sensor,
            // so in most cases Vision needs to rotate it for the model to work as expected.
            let orientation = UIDevice.current.orientation

            // The image captured by the camera
            let image = frame.capturedImage

            let imageOrientation: CGImagePropertyOrientation
            switch orientation {
            case .portrait:
                imageOrientation = .right
            case .portraitUpsideDown:
                imageOrientation = .left
            case .landscapeLeft:
                imageOrientation = .up
            case .landscapeRight:
                imageOrientation = .down
            case .unknown:
                print("The device orientation is unknown, the predictions may be affected")
                fallthrough
            default:
                // By default keep the last orientation
                // This applies for faceUp and faceDown
                imageOrientation = self.lastOrientation
            }

            // For object detection, keeping track of the image buffer size
            // to know how to draw bounding boxes based on relative values.
            if self.bufferSize == nil || self.lastOrientation != imageOrientation {
                self.lastOrientation = imageOrientation
                let pixelBufferWidth = CVPixelBufferGetWidth(image)
                let pixelBufferHeight = CVPixelBufferGetHeight(image)
                if [.up, .down].contains(imageOrientation) {
                    self.bufferSize = CGSize(width: pixelBufferWidth,
                                             height: pixelBufferHeight)
                } else {
                    self.bufferSize = CGSize(width: pixelBufferHeight,
                                             height: pixelBufferWidth)
                }
            }
            
            /// - Tag: PassingFramesToVision

            // Invoke a VNRequestHandler with that image
            let handler = VNImageRequestHandler(cvPixelBuffer: image, orientation: imageOrientation, options: [:])
            do {
                try handler.perform(self.requests)
            } catch {
                print("CoreML request failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func placeAnswer(_ int: Int) {
        // Load the "Box" scene from the "Experience" Reality File
        // let boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
        // arView.scene.anchors.append(boxAnchor)
        generateTextObject(String(int))
    }
    
    func generateTextObject(_ str: String, to target: ARRaycastResult? = nil) {
        let text = MeshResource.generateText(
            str,
            extrusionDepth: 0.005,
            font: .systemFont(ofSize: 0.05, weight: .bold)
        )
        
        let color: UIColor = .random
        let shader = SimpleMaterial(color: color, roughness: 4, isMetallic: false)
        let textEntity = ModelEntity(mesh: text, materials: [shader])
        textEntity.name = str
        
        if let target = target {
            let anchor = AnchorEntity(world: target.worldTransform)
            anchor.addChild(textEntity)
            arView.scene.addAnchor(anchor, removeAfter: 0)
        } else {
            var location = arView.center
            
            if !predictionBounds.isEmpty {
                location = CGPoint(x: predictionBounds.first!.minX, y: predictionBounds.first!.minY)
            }
            
            guard let raycastResult = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any).first else {
                return
            }
            
            let anchor = AnchorEntity(world: raycastResult.worldTransform)
            anchor.addChild(textEntity)
            arView.scene.addAnchor(anchor, removeAfter: 0)
        }
    }
    
    func processPoint(_ points: (index: CGPoint, thumb: CGPoint)) {
        let indexPointConverted = points.index
        let thumbPointConverted = points.thumb
        handPoseProcessor.processPoints((indexPointConverted, thumbPointConverted))
        let midPoint = CGPoint.midPoint(p1: indexPointConverted, p2: thumbPointConverted)
        let hitResults = arView.hitTest(midPoint)
        
        if handPoseProcessor.state == .beginPinch {
            guard let first = hitResults.first else { return }
            movingObject = first.entity
        } else if handPoseProcessor.state == .pinched {
            if let first = hitResults.first {
                movingObject = first.entity
            }
            guard let obj = movingObject else { return }
            guard let raycastResult = arView.raycast(from: midPoint, allowing: .estimatedPlane, alignment: .any).first else { return }
            obj.move(to: raycastResult.worldTransform, relativeTo: nil, duration: 0.3)
        } else if handPoseProcessor.state == .beginApart {
            if !hitResults.isEmpty {
                guard let obj = movingObject else { return }
                
                var value = Int(obj.name) ?? 0
                obj.removeFromParent()
                
                for hitResult in hitResults where hitResult.entity != obj {
                    hitResult.entity.removeFromParent()
                    value += Int(hitResult.entity.name) ?? 0
                }
                
                guard let raycastResult = arView.raycast(from: midPoint, allowing: .estimatedPlane, alignment: .any).first else {
                    return
                }
                generateTextObject(String(value), to: raycastResult)
            }
            movingObject = nil
        }
    }
    
    @objc
    func handleTap(_ sender: UITapGestureRecognizer) {
        /*
        let hitResult = arView.hitTest(sender.location(in: arView))
        print(sender.location(in: arView))
        if let first = hitResult.first {
            print(first.entity)
            first.entity.position = SIMD3(x: first.entity.position.x + 0.1,
                                          y: first.entity.position.y + 0.1,
                                          z: first.entity.position.z)
        }
        
        // 1. Perform a ray cast against the mesh.
        // Note: Ray-cast option ".estimatedPlane" with alignment ".any" also takes the mesh into account.
        let tapLocation = sender.location(in: arView)
        if let result = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .any).first {
            // ...
            // 2. Visualize the intersection point of the ray with the real-world surface.
            let resultAnchor = AnchorEntity(world: result.worldTransform)
            resultAnchor.addChild(sphere(radius: 0.01, color: .lightGray))
            arView.scene.addAnchor(resultAnchor, removeAfter: 60)
        }
        */
    }
    
    func sphere(radius: Float, color: UIColor) -> ModelEntity {
        let sphere = ModelEntity(mesh: .generateSphere(radius: radius), materials: [SimpleMaterial(color: color, isMetallic: false)])
        // Move sphere up by half its diameter so that it does not intersect with the mesh
        sphere.position.y = radius
        return sphere
    }
    
    /*
    @objc
    func handlePan(panGesture: UIPanGestureRecognizer) {
        var panStartZ: CGFloat
        // var lastPanLocation:
        
        guard let view = view as? SCNView else { return }
        let location = panGesture.location(in: self.view)
        switch panGesture.state {
        case .began:
            // existing logic from previous approach. Keep this.
            guard let hitNodeResult = arView.hitTest(location, types: nil).first else { return }
            
            panStartZ = CGFloat(view.projectPoint(lastPanLocation!).z)
            // lastPanLocation is new
            lastPanLocation = hitNodeResult.worldCoordinates
        case .changed:
            // This entire case has been replaced
            let worldTouchPosition = view.unprojectPoint(SCNVector3(location.x, location.y, panStartZ!))
            let movementVector = SCNVector3(
              worldTouchPosition.x - lastPanLocation!.x,
              worldTouchPosition.y - lastPanLocation!.y,
              worldTouchPosition.z - lastPanLocation!.z)
            geometryNode.localTranslate(by: movementVector)
            self.lastPanLocation = worldTouchPosition
        default:
            break
        }
    }
    */
}
