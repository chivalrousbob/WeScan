//
//  Helpers.swift
//  WeScan
//
//  Created by Ayoub Nouri on 10/05/2019.
//  Copyright © 2019 WeTransfer. All rights reserved.
//


class Rotation {
    
    // MARK: - Params
    
    private var rotationAngle = Measurement<UnitAngle>(value: 0, unit: .degrees)
    private var enhancedImageIsAvailable = false
    private var isCurrentlyDisplayingEnhancedImage = false
    var image: UIImage!
    private let results: ImageScannerResults
    
    // MARK: - Init
    
    init(results: ImageScannerResults) {
        self.image = results.scannedImage
        self.results = results
    }
    
    // MARK: -  Methods
    
    @objc private func reloadImage() {
        print("reloadImage")
        if enhancedImageIsAvailable, isCurrentlyDisplayingEnhancedImage {
            image = results.enhancedImage?.rotated(by: rotationAngle) ?? results.enhancedImage
        } else {
            image = results.scannedImage.rotated(by: rotationAngle) ?? results.scannedImage
        }
//        image = results.scannedImage.rotated(by: rotationAngle)
    }
    
    @objc func rotateImage() {
        print("rotateImage")
        rotationAngle.value += 90
        
        if rotationAngle.value == 360 {
            rotationAngle.value = 0
        }
        print("rotateImage \(rotationAngle)")
        reloadImage()
    }
    
}
