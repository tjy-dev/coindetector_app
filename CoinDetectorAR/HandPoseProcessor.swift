//
//  HandPoseProcessor.swift
//  CoinDetectorAR
//
//  Created by Tajima Yukito on 2022/07/13.
//

import Foundation
import Metal
import UIKit

class HandPoseProcessor {
    enum State {
        case possiblePinch
        case beginPinch
        case pinched
        case possibleApart
        case beginApart
        case apart
        case unknown
    }
    
    typealias PointsPair = (thumbTip: CGPoint, indexTip: CGPoint)
    
    var didChangeState: ((State) -> Void)?
    
    private let pinchDistanceThreshold: CGFloat
    private let evidenceCounterStateTrigger: Int

    init(pinchDistanceThreshold: CGFloat = 100, evidenceCounterStateTrigger: Int = 3) {
        self.pinchDistanceThreshold = pinchDistanceThreshold
        self.evidenceCounterStateTrigger = evidenceCounterStateTrigger
    }
    
    var state: State = .unknown {
        didSet {
            didChangeState?(state)
        }
    }
    
    func processPoints(_ pairs: PointsPair) {
        let thumbPoint = pairs.thumbTip
        let indexPoint = pairs.indexTip
        let distance = thumbPoint.distance(from: indexPoint)
        if distance < pinchDistanceThreshold {
            if state == .pinched || state == .beginPinch {
                state = .pinched
            } else {
                state = .beginPinch
            }
        } else {
            if state == .apart || state == .beginApart {
                state = .apart
            } else {
                state = .beginApart
            }
        }
    }
    
    
}
