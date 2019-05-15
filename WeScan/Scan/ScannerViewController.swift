//
//  ScannerViewController.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit
import AVFoundation

/// The `ScannerViewController` offers an interface to give feedback to the user regarding quadrilaterals that are detected. It also gives the user the opportunity to capture an image with a detected rectangle.
final class ScannerViewController: UIViewController {
    
    var captureSessionManager: CaptureSessionManager?
    private let videoPreviewLayer = AVCaptureVideoPreviewLayer()
    
    /// The view that shows the focus rectangle (when the user taps to focus, similar to the Camera app)
    private var focusRectangle: FocusRectangleView!
    
    /// The view that draws the detected rectangles.
    private let quadView = QuadrilateralView()
    
    /// The visual effect (blur) view used on the navigation bar
    private let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    /// Whether flash is enabled
    private var flashEnabled = false
    
    /// The original bar style that was set by the host app
    private var originalBarStyle: UIBarStyle?
    
    /// Check if the screen used for retake or just scanning for the first time
    private var isRetake: Bool = false
    
    lazy private var shutterButton: ShutterButton = {
        let button = ShutterButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        return button
    }()
    
    lazy private var cancelButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("wescan.scanning.cancel", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Cancel", comment: "The cancel button"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(cancelImageScannerController), for: .touchUpInside)
        return button
    }()
    
    lazy private var saveButton: UIButton = {
        let button = UIButton()
        button.setTitle(NSLocalizedString("wescan.scanning.save", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Save", comment: "The Save button"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(saveScannedDocumentsButtonAction), for: .touchUpInside)
        button.backgroundColor = .white
        button.setTitleColor(.black, for: .normal)
        button.layer.cornerRadius = 15
        button.titleLabel?.textAlignment = .left
        return button
    }()
    
    lazy private var autoScanButton: UIBarButtonItem = {
        let title = NSLocalizedString("wescan.scanning.auto", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Auto", comment: "The auto button state")
        let button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(toggleAutoScan))
        button.tintColor = .white
        
        return button
    }()
    
    lazy private var flashButton: UIBarButtonItem = {
        let image = UIImage(named: "flash", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(toggleFlash))
        button.tintColor = .white
        
        return button
    }()
    
    lazy private var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .gray)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()
    
    var buffredScanImageView: UIImageView!
    private var documents: [ImageScannerResults] = []
    
    // MARK: - Init
    
    init(isRetake: Bool? = false) {
        self.isRetake = isRetake!
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let imageScanerViewController = navigationController as? ImageScannerController {
            imageScanerViewController.imageScannerDelegate = self
        }
        
        title = nil
        
        setupViews()
        setupNavigationBar()
        setupConstraints()
        
        captureSessionManager = CaptureSessionManager(videoPreviewLayer: videoPreviewLayer)
        captureSessionManager?.delegate = self
        
        originalBarStyle = navigationController?.navigationBar.barStyle
        
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
        
        CaptureSession.current.isEditing = false
        quadView.removeQuadrilateral()
        self.captureSessionManager?.start()
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.addSubview(self.visualEffectView)
        self.navigationController?.navigationBar.sendSubviewToBack(self.visualEffectView)
        
        self.navigationController?.navigationBar.barStyle = .blackTranslucent
        self.navigationController?.setToolbarHidden(true, animated: true)
        if self.documents.count > 0 && !self.isRetake {
            self.buffredScanImageView.isHidden = false
            self.saveButton.isHidden = false
        }
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        videoPreviewLayer.frame = view.layer.bounds
        
        let statusBarHeight = UIApplication.shared.statusBarFrame.size.height
        let visualEffectRect = self.navigationController?.navigationBar.bounds.insetBy(dx: 0, dy: -(statusBarHeight)).offsetBy(dx: 0, dy: -statusBarHeight)
        
        visualEffectView.frame = visualEffectRect ?? CGRect.zero
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CaptureSession.current.isEditing = true
        UIApplication.shared.isIdleTimerDisabled = false
        
        visualEffectView.removeFromSuperview()
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barStyle = originalBarStyle ?? .default
        
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        if device.torchMode == .on {
            toggleFlash()
        }
    }
    
    // MARK: - Setups
    
    private func setupViews() {
        view.layer.addSublayer(videoPreviewLayer)
        quadView.translatesAutoresizingMaskIntoConstraints = false
        quadView.editable = false
        view.addSubview(quadView)
        //        view.addSubview(cancelButton)
        view.addSubview(shutterButton)
        view.addSubview(activityIndicator)
        view.addSubview(saveButton)
        saveButton.isHidden = true
        if !isRetake {
            scannedImages()
        }
    }
    
    private func scannedImages() {
        buffredScanImageView = UIImageView(frame: CGRect(x: 20, y: Int(view.frame.height - 100), width: 60, height: 60))
        buffredScanImageView.contentMode = .scaleAspectFit
        let imageViewTapGesture = UITapGestureRecognizer(target: self, action: #selector(scannedImagesAction))
        buffredScanImageView.addGestureRecognizer(imageViewTapGesture)
        buffredScanImageView.isUserInteractionEnabled = true
        view.addSubview(buffredScanImageView)
        buffredScanImageView.isHidden = true
    }
    
    @objc private func scannedImagesAction() {
        print("scannedImagesAction")
        let editScannedViewController = EditScannedViewController(documents: documents)
        editScannedViewController.delegate = self
        let nv = UINavigationController(rootViewController: editScannedViewController)
        navigationController?.present(nv, animated: true) {
            
        }
    }
    
    private func setupNavigationBar() {
        //        navigationItem.setLeftBarButton(flashButton, animated: false)
        let cancelButtonItem = UIBarButtonItem(customView: cancelButton)
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        navigationItem.setRightBarButton(autoScanButton, animated: false)
        navigationItem.leftBarButtonItems = [cancelButtonItem, fixedSpace, fixedSpace, fixedSpace, flashButton]
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Retake", style: UIBarButtonItem.Style.plain, target: self, action: nil)
        
        if UIImagePickerController.isFlashAvailable(for: .rear) == false {
            let flashOffImage = UIImage(named: "flashUnavailable", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
            flashButton.image = flashOffImage
            flashButton.tintColor = UIColor.lightGray
        }
    }
    
    private func setupConstraints() {
        var quadViewConstraints = [NSLayoutConstraint]()
        //        var cancelButtonConstraints = [NSLayoutConstraint]()
        var shutterButtonConstraints = [NSLayoutConstraint]()
        var activityIndicatorConstraints = [NSLayoutConstraint]()
        var saveButtonConstraints = [NSLayoutConstraint]()
        
        quadViewConstraints = [
            quadView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: quadView.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: quadView.trailingAnchor),
            quadView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ]
        
        shutterButtonConstraints = [
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 65.0),
            shutterButton.heightAnchor.constraint(equalToConstant: 65.0)
        ]
        
        saveButtonConstraints = [
            saveButton.widthAnchor.constraint(equalToConstant: 100),
            saveButton.heightAnchor.constraint(equalToConstant: 30),
            saveButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
            saveButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor)
            
        ]
        
        activityIndicatorConstraints = [
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]
        
        if #available(iOS 11.0, *) {
            //            cancelButtonConstraints = [
            //                cancelButton.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 24.0),
            //                view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: (65.0 / 2) - 10.0)
            //            ]
            
            let shutterButtonBottomConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
            shutterButtonConstraints.append(shutterButtonBottomConstraint)
        } else {
            //            cancelButtonConstraints = [
            //                cancelButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 24.0),
            //                view.bottomAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: (65.0 / 2) - 10.0)
            //            ]
            
            let shutterButtonBottomConstraint = view.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
            shutterButtonConstraints.append(shutterButtonBottomConstraint)
        }
        
        NSLayoutConstraint.activate(quadViewConstraints + shutterButtonConstraints + activityIndicatorConstraints + saveButtonConstraints)
    }
    
    // MARK: - Tap to Focus
    
    /// Called when the AVCaptureDevice detects that the subject area has changed significantly. When it's called, we reset the focus so the camera is no longer out of focus.
    @objc private func subjectAreaDidChange() {
        /// Reset the focus and exposure back to automatic
        do {
            try CaptureSession.current.resetFocusToAuto()
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager = captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }
        
        /// Remove the focus rectangle if one exists
        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: true)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard  let touch = touches.first else { return }
        let touchPoint = touch.location(in: view)
        let convertedTouchPoint: CGPoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        
        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: false)
        
        //        focusRectangle = FocusRectangleView(touchPoint: touchPoint)
        //        view.addSubview(focusRectangle)
        
        do {
            try CaptureSession.current.setFocusPointToTapPoint(convertedTouchPoint)
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager = captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }
    }
    
    // MARK: - Actions
    
    @objc private func captureImage(_ sender: UIButton) {
        (navigationController as? ImageScannerController)?.flashToBlack()
        shutterButton.isUserInteractionEnabled = false
        captureSessionManager?.capturePhoto()
    }
    
    @objc private func toggleAutoScan() {
        if CaptureSession.current.isAutoScanEnabled {
            CaptureSession.current.isAutoScanEnabled = false
            autoScanButton.title = NSLocalizedString("wescan.scanning.manual", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Manual", comment: "The manual button state")
        } else {
            CaptureSession.current.isAutoScanEnabled = true
            autoScanButton.title = NSLocalizedString("wescan.scanning.auto", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Auto", comment: "The auto button state")
        }
    }
    
    @objc private func toggleFlash() {
        let state = CaptureSession.current.toggleFlash()
        
        let flashImage = UIImage(named: "flash", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        let flashOffImage = UIImage(named: "flashUnavailable", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        
        switch state {
        case .on:
            flashEnabled = true
            flashButton.image = flashImage
            flashButton.tintColor = .yellow
        case .off:
            flashEnabled = false
            flashButton.image = flashImage
            flashButton.tintColor = .white
        case .unknown, .unavailable:
            flashEnabled = false
            flashButton.image = flashOffImage
            flashButton.tintColor = UIColor.lightGray
        }
    }
    
    @objc private func cancelImageScannerController() {
        if isRetake {
            scannedImagesAction()
        } else {
            dismiss(animated: true, completion: nil)
        }
        
        //        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        //        imageScannerController.imageScannerDelegate?.imageScannerControllerDidCancel(imageScannerController)
    }
    
    @objc private func saveScannedDocumentsButtonAction() {
        
    }
    
}

extension ScannerViewController: RectangleDetectionDelegateProtocol {
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {
        
        activityIndicator.stopAnimating()
        shutterButton.isUserInteractionEnabled = true
        
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
    }
    
    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {
        activityIndicator.startAnimating()
        shutterButton.isUserInteractionEnabled = false
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withQuad quad: Quadrilateral?) {
        activityIndicator.stopAnimating()
        
        let editVC = EditScanViewController(image: picture, quad: quad)
        navigationController?.pushViewController(editVC, animated: false)
        
        shutterButton.isUserInteractionEnabled = true
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize) {
        guard let quad = quad else {
            // If no quad has been detected, we remove the currently displayed on on the quadView.
            quadView.removeQuadrilateral()
            return
        }
        
        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)
        
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: portraitImageSize, aspectFillInSize: quadView.bounds.size)
        let scaledImageSize = imageSize.applying(scaleTransform)
        
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)
        
        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)
        
        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds, toCenterOfRect: quadView.bounds)
        
        let transforms = [scaleTransform, rotationTransform, translationTransform]
        
        let transformedQuad = quad.applyTransforms(transforms)
        
        quadView.drawQuadrilateral(quad: transformedQuad, animated: true)
    }
    
}

//public protocol ScannerViewControllerDelegate {
//
//     func scannerViewController(_ scanner: ImageScannerController, didFinishScanningWithResults results: ImageScannerResults)
//
//}

extension ScannerViewController: ImageScannerControllerDelegate {
    
    func imageScannerController(_ scanner: ImageScannerController, didFinishScanningWithResults results: ImageScannerResults) {
        print("didFinishScanningWithResults")
        documents.append(results)
        buffredScanImageView.image = results.scannedImage
    }
    
    func imageScannerControllerDidCancel(_ scanner: ImageScannerController) {
        
    }
    
    func imageScannerController(_ scanner: ImageScannerController, didFailWithError error: Error) {
        
    }
    
}

protocol EditScannedViewControllerDelegate: class {
    func doneButtonResponse(result: [ImageScannerResults])
    func retakeButtonResponse(index: Int)
}

extension ScannerViewController: EditScannedViewControllerDelegate {
    
    func doneButtonResponse(result: [ImageScannerResults]) {
        documents = result
        isRetake = false
        buffredScanImageView.isHidden = false
        saveButton.isHidden = false
        if documents.count == 0 {
            buffredScanImageView.isHidden = true
            buffredScanImageView.image = nil
            saveButton.isHidden = true
        }
        if let document = documents.last {
            buffredScanImageView.image = document.scannedImage
        }
        
    }
    
    func retakeButtonResponse(index: Int) {
        isRetake = true
        buffredScanImageView.isHidden = true
        saveButton.isHidden = true
    }
    
}


