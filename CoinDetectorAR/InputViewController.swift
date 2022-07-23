//
//  InputViewController.swift
//  CoinDetectorAR
//
//  Created by Tajima Yukito on 2022/07/23.
//

import Foundation
import UIKit
import PencilKit
import Vision

class InputViewController: UIViewController, PKCanvasViewDelegate {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }
    
    // MARK: PK Canvas
    let canvasContainer = UIView()
    let canvasView = PKCanvasView()
    let pencilButton = UIButton()
    let cancelButton = UIButton()
    let clearButton = UIButton()
    @objc let submitButton = UIButton()
    /// CanvasView input
    var didEnterInput = false
    var submitted: ((Int) -> ())?
    
    override func viewDidLoad() {
        setupViews()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        openCanvas()
    }
    
    func updateFrames() {
        DispatchQueue.main.async {
            self.canvasView.frame = self.view.frame
        }
    }
    
    func openCanvas() {
        canvasContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        canvasContainer.alpha = 0
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: .curveEaseInOut) { [self] in
            canvasContainer.transform = CGAffineTransform(scaleX: 1, y: 1)
            canvasContainer.alpha = 1
            pencilButton.alpha = 0
        } completion: { bool in }
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
            self.dismiss(animated: false)
        }
    }
    
    func clearCanvas() {
        canvasView.drawing = PKDrawing()
        didEnterInput = false
    }
    
    @objc
    func clearCanvasAction(sender: UIButton) {
        clearCanvas()
    }
    
    @objc
    func submitAction(sender: UIButton) {
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
                self.dismiss(animated: false)
            }
        } else {
            canvasContainer.shakeHorizontal(duration: 0.8)
        }
    }
}

extension InputViewController {
    func setupViews() {
        view.backgroundColor = .clear
        
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
}
