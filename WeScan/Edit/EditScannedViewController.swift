//
//  EditScannedViewController.swift
//  WeScan
//
//  Created by Ayoub Nouri on 08/05/2019.
//  Copyright © 2019 WeTransfer. All rights reserved.
//

import UIKit

class EditScannedViewController: UIViewController {

    // MARK: - Params
    
    private let cellIdentifier = "collectionCellIdentifier"
    private var indexPath = IndexPath(item: 0, section: 0)
    private var rotationAngle = Measurement<UnitAngle>(value: 90, unit: .degrees)
    
    lazy private var collectionView: UICollectionView = {
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.itemSize = view.frame.size
        layout.scrollDirection =  .horizontal
        
        let collectionView = UICollectionView(frame: view.frame, collectionViewLayout: layout)
        collectionView.isPagingEnabled = true
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(EditScannedCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        
        collectionView.backgroundColor = .gray
        collectionView.bounces = false
        if #available(iOS 11.0, *) {
            collectionView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
            self.automaticallyAdjustsScrollViewInsets = false
        }
        return collectionView
    }()
    
    private var documents: [ImageScannerResults]
    
    weak var delegate: EditScannedViewControllerDelegate?
    
    // MARK: - Init
    
    init(documents: [ImageScannerResults]) {
        self.documents = documents
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavaigationBar()
        setupViews()
       
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
         setupToolBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let indexPath = IndexPath(item: documents.count-1,section: 0)
//        DispatchQueue.main.async {
          collectionView.selectItem(at: indexPath, animated: false, scrollPosition: UICollectionView.ScrollPosition.right)
//        }
        
    }
    
    // MARK: - Methods
    
    private func setupNavaigationBar() {
        title = "1 of \(documents.count)"
        let doneButton = UIBarButtonItem(title: "Done", style: UIBarButtonItem.Style.done, target: self, action: #selector(doneButtonAction))
        
        let retakeButton = UIBarButtonItem(title: "Retake", style: UIBarButtonItem.Style.plain, target: self, action: #selector(retakeButtonAction))
        
        navigationItem.leftBarButtonItem = doneButton
        navigationItem.rightBarButtonItem = retakeButton
    }
    
    private func setupToolBar() {
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let rotateButton = UIBarButtonItem(image: UIImage(named: "rotate", in: Bundle(for: EditScanCornerView.self), compatibleWith: nil), style: .plain, target: self, action: #selector(rotateButtonAction))
        let cropButton = UIBarButtonItem(image: UIImage(named: "crop", in: Bundle(for: EditScanCornerView.self), compatibleWith: nil), style: .plain, target: self, action: #selector(cropButtonAction))
        let deleteButton = UIBarButtonItem(image: UIImage(named: "delete", in: Bundle(for: EditScanCornerView.self), compatibleWith: nil), style: .plain, target: self, action: #selector(deleteButtonAction))
        navigationController!.setToolbarHidden(false, animated: false)
        navigationController!.toolbar.items = [cropButton,flexibleSpace,rotateButton,flexibleSpace,deleteButton]
    }
    
    
    private func setupViews() {
        view.addSubview(collectionView)
    }
    
    // MARK: - Action
    
    @objc private func doneButtonAction() {
        delegate?.doneButtonResponse(result: documents)
        dismiss(animated: true)
    }
    
    @objc private func retakeButtonAction() {
//        let scannerViewController = ScannerViewController(isRetake: true)
//        let nc = UINavigationController(rootViewController: scannerViewController)
//        navigationController?.present(nc, animated: true, completion: nil)
//        navigationController?.popViewController(animated: true)
        delegate?.retakeButtonResponse(index: indexPath.item)
        dismiss(animated: false, completion: nil)
        
    }
    
    @objc private func rotateButtonAction() {
        print("rotateButtonAction")

        
        DispatchQueue.main.async {
            
            var document = self.documents[self.indexPath.item]
            let rotation = Rotation(results: document)
            rotation.rotateImage()
            document.scannedImage = rotation.image//.rotated(by: self.rotationAngle) ?? UIImage()
            self.documents[self.indexPath.item] = document
            self.collectionView.reloadData()
        }
    }
    
    @objc private func cropButtonAction() {
        let document = self.documents[self.indexPath.item]
        let quad = document.detectedRectangle
        let editScanViewController = EditScanViewController(image: document.originalImage, quad: quad, rotateImage: false, isCropScanScreen: true)
        editScanViewController.delegate = self
        navigationController?.pushViewController(editScanViewController, animated: false)
    }
    
    @objc private func deleteButtonAction() {
        if documents.count > 0 && documents.count >= indexPath.item {
            documents.remove(at: indexPath.item)
            if documents.count > 0 {
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            } else {
               doneButtonAction()
            }
            
        }
    }
    
}

extension EditScannedViewController: UICollectionViewDelegate, UICollectionViewDataSource {
   
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return documents.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! EditScannedCollectionViewCell
        let document = documents[indexPath.item]
        cell.configure(document: document)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        var visibleRect = CGRect()
        
        visibleRect.origin = collectionView.contentOffset
        visibleRect.size = collectionView.bounds.size
        
        let visiblePoint = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        
        guard let indexPath = collectionView.indexPathForItem(at: visiblePoint) else { return }
        
        print(indexPath)
        self.indexPath = indexPath
        title = "\(indexPath.item+1) of \(documents.count)"
    }
    
}

extension EditScannedViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        print("self.view.frame.size \(self.view.frame.size)")
        return self.view.frame.size
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
//
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
//        return 0
//    }
    
}

protocol EditScanViewControllerDelegate {
    
    func doneButtonResponse(result: ImageScannerResults)
    
}

extension EditScannedViewController: EditScanViewControllerDelegate {
   
    func doneButtonResponse(result: ImageScannerResults) {
        print(doneButtonResponse)
        documents[indexPath.item] = result
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
}
