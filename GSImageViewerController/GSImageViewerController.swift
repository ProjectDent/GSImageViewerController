//
//  GSImageViewerController.swift
//  GSImageViewerControllerExample
//
//  Created by Gesen on 15/12/22.
//  Copyright © 2015年 Gesen. All rights reserved.
//

import UIKit

public struct GSImageInfo {
    
    public enum ImageMode : Int {
        case AspectFit  = 1
        case AspectFill = 2
    }
    
    public let image     : UIImage
    public let imageMode : ImageMode
    public var imageHD   : NSURL?
    
    public var contentMode : UIViewContentMode {
        return UIViewContentMode(rawValue: imageMode.rawValue)!
    }
    
    public init(image: UIImage, imageMode: ImageMode) {
        self.image     = image
        self.imageMode = imageMode
    }
    
    public init(image: UIImage, imageMode: ImageMode, imageHD: NSURL?) {
        self.init(image: image, imageMode: imageMode)
        self.imageHD = imageHD
    }
    
    func calculateRect(size: CGSize) -> CGRect {
        
        let widthRatio  = size.width  / image.size.width
        let heightRatio = size.height / image.size.height
        
        switch imageMode {
            
        case .AspectFit:
            
            return CGRect(origin: CGPointZero, size: size)
            
        case .AspectFill:
            
            return CGRect(
                x      : 0,
                y      : 0,
                width  : image.size.width  * max(widthRatio, heightRatio),
                height : image.size.height * max(widthRatio, heightRatio)
            )
            
        }
    }
    
    func calculateMaximumZoomScale(size: CGSize) -> CGFloat {
        return max(2, max(
            image.size.width  / size.width,
            image.size.height / size.height
        ))
    }
    
}

public class GSTransitionInfo {
    
    public var duration: NSTimeInterval = 0.35
    public var canSwipe: Bool           = true
    
    public init(fromView: UIView) {
        self.fromView = fromView
    }
    
    weak var fromView : UIView?
    
    private var convertedRect : CGRect?
    
}

public class GSImageViewerController: UIViewController {
    
    public let imageInfo      : GSImageInfo
    public var transitionInfo : GSTransitionInfo?
    
    private let imageView  = UIImageView()
    private let scrollView = UIScrollView()
    
    private lazy var session: NSURLSession = {
        let configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
        return NSURLSession(configuration: configuration, delegate: nil, delegateQueue: NSOperationQueue.mainQueue())
    }()
    
    // MARK: Initialization
    
    public init(imageInfo: GSImageInfo) {
        self.imageInfo = imageInfo
        super.init(nibName: nil, bundle: nil)
    }
    
    public convenience init(imageInfo: GSImageInfo, transitionInfo: GSTransitionInfo) {
        self.init(imageInfo: imageInfo)
        self.transitionInfo = transitionInfo
        if let fromView = transitionInfo.fromView, let referenceView = fromView.superview {
            self.transitioningDelegate = self
            self.modalPresentationStyle = .Custom
            transitionInfo.convertedRect = referenceView.convertRect(fromView.frame, toView: nil)
        }
    }
    
    public convenience init(image: UIImage, imageMode: UIViewContentMode, imageHD: NSURL?, fromView: UIView?) {
        let imageInfo = GSImageInfo(image: image, imageMode: GSImageInfo.ImageMode(rawValue: imageMode.rawValue)!, imageHD: imageHD)
        if let fromView = fromView {
            self.init(imageInfo: imageInfo, transitionInfo: GSTransitionInfo(fromView: fromView))
        } else {
            self.init(imageInfo: imageInfo)
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Override
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupScrollView()
        setupImageView()
        setupGesture()
        setupImageHD()
        
        edgesForExtendedLayout = .None
        automaticallyAdjustsScrollViewInsets = false
    }
    
    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        imageView.frame = imageInfo.calculateRect(view.bounds.size)
        
        scrollView.frame = view.bounds
        scrollView.contentSize = imageView.bounds.size
        scrollView.maximumZoomScale = imageInfo.calculateMaximumZoomScale(scrollView.bounds.size)
    }
    
    // MARK: Setups
    
    private func setupView() {
        view.backgroundColor = UIColor.blackColor()
    }
    
    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
    }
    
    private func setupImageView() {
        imageView.image = imageInfo.image
        imageView.contentMode = .ScaleAspectFit
        scrollView.addSubview(imageView)
    }
    
    private func setupGesture() {
        let single = UITapGestureRecognizer(target: self, action: #selector(singleTap))
        let double = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        double.numberOfTapsRequired = 2
        single.requireGestureRecognizerToFail(double)
        scrollView.addGestureRecognizer(single)
        scrollView.addGestureRecognizer(double)
        
        if transitionInfo?.canSwipe == true {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
            pan.delegate = self
            scrollView.addGestureRecognizer(pan)
        }
    }
    
    private func setupImageHD() {
        guard let imageHD = imageInfo.imageHD else { return }
            
        let request = NSMutableURLRequest(URL: imageHD, cachePolicy: .ReloadIgnoringLocalCacheData, timeoutInterval: 15)
        let task = session.dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
            guard let data = data else { return }
            guard let image = UIImage(data: data) else { return }
            self.imageView.image = image
            self.view.layoutIfNeeded()
        })
        task.resume()
    }
    
    // MARK: Gesture
    
    @objc private func singleTap() {
        if navigationController == nil || (presentingViewController != nil && navigationController!.viewControllers.count <= 1) {
            dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    @objc private func doubleTap(gesture: UITapGestureRecognizer) {
        let point = gesture.locationInView(scrollView)
        
        if scrollView.zoomScale == 1.0 {
            scrollView.zoomToRect(CGRectMake(point.x-40, point.y-40, 80, 80), animated: true)
        } else {
            scrollView.setZoomScale(1.0, animated: true)
        }
    }
    
    private var panViewOrigin : CGPoint?
    private var panViewAlpha  : CGFloat = 1
    
    @objc private func pan(gesture: UIPanGestureRecognizer) {
        
        func getProgress() -> CGFloat {
            let origin = panViewOrigin!
            let changeX = abs(scrollView.center.x - origin.x)
            let changeY = abs(scrollView.center.y - origin.y)
            let progressX = changeX / CGRectGetWidth(view.bounds)
            let progressY = changeY / CGRectGetHeight(view.bounds)
            return max(progressX, progressY)
        }
        
        func getChanged() -> CGPoint {
            let origin = scrollView.center
            let change = gesture.translationInView(view)
            return CGPoint(x: origin.x + change.x, y: origin.y + change.y)
        }

        switch gesture.state {

        case .Began:
            
            panViewOrigin = scrollView.center
            
        case .Changed:
            
            scrollView.center = getChanged()
            panViewAlpha = 1 - getProgress()
            view.backgroundColor = UIColor(white: 0.0, alpha: panViewAlpha)
            gesture.setTranslation(CGPointZero, inView: nil)

        case .Ended:
            
            if getProgress() > 0.25 {
                dismissViewControllerAnimated(true, completion: nil)
            } else {
                fallthrough
            }
            
        default:
            
            UIView.animateWithDuration(0.3,
                animations: {
                    self.scrollView.center = self.panViewOrigin!
                    self.view.backgroundColor = UIColor(white: 0.0, alpha: 1.0)
                },
                completion: { _ in
                    self.panViewOrigin = nil
                    self.panViewAlpha  = 1.0
                }
            )
            
        }
    }
    
}

extension GSImageViewerController: UIScrollViewDelegate {
    
    public func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    public func scrollViewDidZoom(scrollView: UIScrollView) {
        imageView.frame = imageInfo.calculateRect(scrollView.contentSize)
    }
    
}

extension GSImageViewerController: UIViewControllerTransitioningDelegate {
    
    public func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return GSImageViewerTransition(imageInfo: imageInfo, transitionInfo: transitionInfo!, transitionMode: .Present)
    }
    
    public func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return GSImageViewerTransition(imageInfo: imageInfo, transitionInfo: transitionInfo!, transitionMode: .Dismiss)
    }
    
}

class GSImageViewerTransition: NSObject, UIViewControllerAnimatedTransitioning {
    
    let imageInfo      : GSImageInfo
    let transitionInfo : GSTransitionInfo
    var transitionMode : TransitionMode
    
    enum TransitionMode {
        case Present
        case Dismiss
    }
    
    init(imageInfo: GSImageInfo, transitionInfo: GSTransitionInfo, transitionMode: TransitionMode) {
        self.imageInfo = imageInfo
        self.transitionInfo = transitionInfo
        self.transitionMode = transitionMode
        super.init()
    }
    
    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return transitionInfo.duration
    }
    
    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView()
        
        let tempMask = UIView()
            tempMask.backgroundColor = UIColor.blackColor()
        
        let tempImage = UIImageView(image: imageInfo.image)
            tempImage.layer.cornerRadius = transitionInfo.fromView!.layer.cornerRadius
            tempImage.layer.masksToBounds = true
            tempImage.contentMode = imageInfo.contentMode
        
        containerView.addSubview(tempMask)
        containerView.addSubview(tempImage)
        
        if transitionMode == .Present {
            
            let imageViewer = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey) as! GSImageViewerController
                imageViewer.view.layoutIfNeeded()
            
                tempMask.alpha = 0
                tempMask.frame = imageViewer.view.bounds
                tempImage.frame = transitionInfo.convertedRect!
            
            UIView.animateWithDuration(transitionInfo.duration,
                animations: {
                    tempMask.alpha  = 1
                    tempImage.frame = imageViewer.imageView.frame
                },
                completion: { _ in
                    tempMask.removeFromSuperview()
                    tempImage.removeFromSuperview()
                    containerView.addSubview(imageViewer.view)
                    transitionContext.completeTransition(true)
                }
            )
            
        }
        
        if transitionMode == .Dismiss {
            
            let imageViewer = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey) as! GSImageViewerController
                imageViewer.view.removeFromSuperview()
            
                tempMask.alpha = imageViewer.panViewAlpha
                tempMask.frame = imageViewer.view.bounds
                tempImage.frame = imageViewer.scrollView.frame
            
            UIView.animateWithDuration(transitionInfo.duration,
                animations: {
                    tempMask.alpha  = 0
                    tempImage.frame = self.transitionInfo.convertedRect!
                },
                completion: { _ in
                    tempMask.removeFromSuperview()
                    imageViewer.view.removeFromSuperview()
                    transitionContext.completeTransition(true)
                }
            )
            
        }
        
    }
    
}

extension GSImageViewerController: UIGestureRecognizerDelegate {
    
    public func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            if scrollView.zoomScale != 1.0 {
                return false
            }
            if imageInfo.imageMode == .AspectFill && (scrollView.contentOffset.x > 0 || pan.translationInView(view).x <= 0) {
                return false
            }
        }
        return true
    }
    
}
