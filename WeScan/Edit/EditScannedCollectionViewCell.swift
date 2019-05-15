//
//  EditScannedCollectionViewCell.swift
//  WeScan
//
//  Created by Ayoub Nouri on 09/05/2019.
//  Copyright © 2019 WeTransfer. All rights reserved.
//

import UIKit

class EditScannedCollectionViewCell: UICollectionViewCell {
    
    var imageView: UIImageView!
    var document: ImageScannerResults!
    func configure(document: ImageScannerResults) {
        self.document = document
        let image = document.scannedImage
        imageView = UIImageView()
        imageView.image = image
        imageView.clipsToBounds = true
        imageView.isOpaque = true
        imageView.backgroundColor = .gray
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        setupConstarints()
    }
    
    func setupConstarints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        imageView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        imageView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }
    
    
}


