//
//  Extension.swift
//  CoinDetectorAR
//
//  Created by YUKITO on 2022/06/16.
//

import Foundation
import ImageIO
import UIKit
import ARKit
import RealityKit

struct Coin {
    init(_ name: String) {
        self.name = name
        setValues(name: name)
    }
    
    var name: String! {
        didSet {
            setValues(name: name)
        }
    }
    
    mutating func setValues(name: String) {
        type = types(rawValue: name)
        switch type {
        case .one: price = 1
        case .five: price = 5
        case .ten: price = 10
        case .fifty: price = 50
        case .hundred: price = 100
        case .fivehundred: price = 500
        case .none:
            fatalError()
        }
    }
    
    var price: Int = 0
    var type: types! = .none
    
    enum types: String {
        case one = "one"
        case five = "five"
        case ten = "ten"
        case fifty = "fifty"
        case hundred = "hundred"
        case fivehundred = "fivehundred"
    }
}

extension Int {
    func pow(_ int: Int) -> Int {
        var res = 1
        if int > 0 {
            for _ in 0..<int {
                res *= self
            }
        }
        return res
    }
}

extension UIColor {
    static var random: UIColor {
        return UIColor(red: .random(in: 0.8...1), green: .random(in: 0.8...1), blue: .random(in: 0.8...1), alpha: 1)
    }
}

extension Array {
    mutating func append(_ newElement: Element, keep: Int) {
        self.append(newElement)
        if self.count > keep {
            self = Array<Element>(self.dropFirst())
        }
    }
}

extension Array where Element: Hashable {
    func mostFrequent() -> (mostFrequent: [Element], count: Int)? {
        var counts: [Element: Int] = [:]
        
        self.forEach { counts[$0] = (counts[$0] ?? 0) + 1 }
        if let count = counts.max(by: {$0.value < $1.value})?.value {
            return (counts.compactMap { $0.value == count ? $0.key : nil }, count)
        }
        return nil
    }
    
    func mostFrequent() -> Element? {
        var counts: [Element: Int] = [:]
        
        self.forEach { counts[$0] = (counts[$0] ?? 0) + 1 }
        if let count = counts.max(by: {$0.value < $1.value})?.value {
            return (counts.compactMap { $0.value == count ? $0.key : nil }).first
        }
        return nil
    }
}

extension UIImage {
    
    // Inverts image to cgImage
    func invertColor() -> CGImage? {
        let image = CIImage(image: self)!
        if let filter = CIFilter(name: "CIColorInvert") {
            filter.setDefaults()
            filter.setValue(image, forKey: kCIInputImageKey)
            
            let context = CIContext(options: nil)
            let imageRef = context.createCGImage(filter.outputImage!, from: image.extent)
            return imageRef
        }
        return UIImage().cgImage
    }
}

extension UITraitCollection {

    public static var isDarkMode: Bool {
        if #available(iOS 13, *), current.userInterfaceStyle == .dark {
            return true
        }
        return false
    }
}

extension UIView {
    func shake(duration: CFTimeInterval) {
        let translation = CAKeyframeAnimation(keyPath: "transform.translation.x");
        translation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        translation.values = [-5, 5, -5, 5, -3, 3, -2, 2, 0]
        
        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotation.values = [-5, 5, -5, 5, -3, 3, -2, 2, 0].map {
            ( degrees: Double) -> Double in
            let radians: Double = (.pi * degrees) / 180.0
            return radians
        }
        
        let shakeGroup: CAAnimationGroup = CAAnimationGroup()
        shakeGroup.animations = [translation, rotation]
        shakeGroup.duration = duration
        self.layer.add(shakeGroup, forKey: "shakeIt")
    }
    
    func shakeHorizontal(duration: CFTimeInterval) {
        let translation = CAKeyframeAnimation(keyPath: "transform.translation.x");
        translation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        translation.values = [-10, 10, -10, 10, -6, 6, -3, 3, 0]
        
        let shakeGroup: CAAnimationGroup = CAAnimationGroup()
        shakeGroup.animations = [translation]
        shakeGroup.duration = duration
        self.layer.add(shakeGroup, forKey: "shakeHz")
    }
}

extension CGPoint {

    static func midPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        return CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
    }
    
    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - x, point.y - y)
    }
}

extension Scene {
    // Add an anchor and remove it from the scene after the specified number of seconds.
/// - Tag: AddAnchorExtension
    func addAnchor(_ anchor: HasAnchoring, removeAfter seconds: TimeInterval) {
        guard let model = anchor.children.first as? HasPhysics else {
            return
        }
        
        // Set up model to participate in physics simulation
        if model.collision == nil {
            model.generateCollisionShapes(recursive: true)
            model.physicsBody = .init()
        }
        // ... but prevent it from being affected by simulation forces for now.
        model.physicsBody?.mode = .kinematic
        
        addAnchor(anchor)
        
        if seconds != 0 {
            // Making the physics body dynamic at this time will let the model be affected by forces.
            Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { (timer) in
                model.physicsBody?.mode = .dynamic
            }
            Timer.scheduledTimer(withTimeInterval: seconds + 3, repeats: false) { (timer) in
                self.removeAnchor(anchor)
            }
        }
    }
}
