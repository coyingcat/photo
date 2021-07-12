//
//  ZLClipImageViewController.swift
//  ZLPhotoBrowser
//
//  Created by long on 2020/8/27.
//
//  Copyright (c) 2020 Long Zhang <495181165@qq.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

class ZLClipImageViewController: UIViewController {

    static let bottomToolViewH: CGFloat = 90
    
    static let clipRatioItemSize: CGSize = CGSize(width: 60, height: 70)
    
    /// 用作进入裁剪界面首次动画frame
    var presentAnimateFrame: CGRect?
    
    /// 用作进入裁剪界面首次动画和取消裁剪时动画的image
    var presentAnimateImage: UIImage?
    
    /// 取消裁剪时动画frame
    var cancelClipAnimateFrame: CGRect = .zero
    
    var viewDidAppearCount = 0
    
    let clipRatios: ZLImageClipRatio
    
    var editImage: UIImage
    
    /// 初次进入界面时候，裁剪范围
    var editRect: CGRect
    
    var scrollView: UIScrollView!
    
    var containerView: UIView!
    
    var imageView: UIImageView!
    
    var bottomToolView: UIView!
    
    var bottomShadowLayer: CAGradientLayer!
    
    var bottomToolLineView: UIView!
    
    var cancelBtn: UIButton!
    
    var doneBtn: UIButton!
    
    var rotateBtn: UIButton!
    
    var shouldLayout = true
    
    
    var clipBoxFrame: CGRect = .zero
    
    var clipOriginFrame: CGRect = .zero
    
    var isRotating = false
    
    var angle: CGFloat = 0
    
    var selectedRatio: ZLImageClipRatio
    
    lazy var maxClipFrame: CGRect = {
        var insets = deviceSafeAreaInsets()
        insets.top +=  20
        var rect = CGRect.zero
        rect.origin.x = 15
        rect.origin.y = insets.top
        rect.size.width = UIScreen.main.bounds.width - 15 * 2
        rect.size.height = UIScreen.main.bounds.height - insets.top - ZLClipImageViewController.bottomToolViewH - ZLClipImageViewController.clipRatioItemSize.height - 25
        return rect
    }()
    
    var minClipSize = CGSize(width: 45, height: 45)
    
    var dismissAnimateFromRect: CGRect = .zero
    
    var dismissAnimateImage: UIImage? = nil
    
    /// 传回旋转角度，图片编辑区域的rect
    var clipDoneBlock: ( (CGFloat, CGRect) -> Void )?
    
    var cancelClipBlock: ( () -> Void )?
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    
    init(image: UIImage, editRect: CGRect?, angle: CGFloat = 0) {
        self.clipRatios = ZLPhotoConfiguration.default().editImageClipRatios
        self.editRect = editRect ?? .zero
        self.angle = angle
        if angle == -90 {
            self.editImage = image.rotate(orientation: .left)
        } else if self.angle == -180 {
            self.editImage = image.rotate(orientation: .down)
        } else if self.angle == -270 {
            self.editImage = image.rotate(orientation: .right)
        } else {
            self.editImage = image
        }
      
        self.selectedRatio = ZLPhotoConfiguration.default().editImageClipRatios
        
        super.init(nibName: nil, bundle: nil)

            self.calculateClipRect()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.viewDidAppearCount += 1
        if self.presentingViewController is ZLEditImageViewController {
            self.transitioningDelegate = self
        }
        
        guard self.viewDidAppearCount == 1 else {
            return
        }
        
        if let frame = self.presentAnimateFrame, let image = self.presentAnimateImage {
            let animateImageView = UIImageView(image: image)
            animateImageView.contentMode = .scaleAspectFill
            animateImageView.clipsToBounds = true
            animateImageView.frame = frame
            self.view.addSubview(animateImageView)
            
            self.cancelClipAnimateFrame = self.clipBoxFrame
            UIView.animate(withDuration: 0.25, animations: {
                animateImageView.frame = self.clipBoxFrame
                self.bottomToolView.alpha = 1
                self.rotateBtn.alpha = 1
            }) { (_) in
                UIView.animate(withDuration: 0.1, animations: {
                    self.scrollView.alpha = 1
                }) { (_) in
                    animateImageView.removeFromSuperview()
                }
            }
        } else {
            self.bottomToolView.alpha = 1
            self.rotateBtn.alpha = 1
            self.scrollView.alpha = 1
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard self.shouldLayout else {
            return
        }
        self.shouldLayout = false
        
        self.scrollView.frame = self.view.bounds
        
        self.layoutInitialImage()
        
        self.bottomToolView.frame = CGRect(x: 0, y: self.view.bounds.height-ZLClipImageViewController.bottomToolViewH, width: self.view.bounds.width, height: ZLClipImageViewController.bottomToolViewH)
        self.bottomShadowLayer.frame = self.bottomToolView.bounds
        
        self.bottomToolLineView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 1/UIScreen.main.scale)
        let toolBtnH: CGFloat = 25
        let toolBtnY = (ZLClipImageViewController.bottomToolViewH - toolBtnH) / 2 - 10
        self.cancelBtn.frame = CGRect(x: 30, y: toolBtnY, width: toolBtnH, height: toolBtnH)
      
        self.doneBtn.frame = CGRect(x: self.view.bounds.width-30-toolBtnH, y: toolBtnY, width: toolBtnH, height: toolBtnH)
        
        let ratioColViewY = self.bottomToolView.frame.minY - ZLClipImageViewController.clipRatioItemSize.height - 5
        self.rotateBtn.frame = CGRect(x: 30, y: ratioColViewY + (ZLClipImageViewController.clipRatioItemSize.height-25)/2, width: 25, height: 25)
      
    }
    
    func setupUI() {
        self.view.backgroundColor = .black
        
        self.scrollView = UIScrollView()
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.alwaysBounceHorizontal = true
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        self.scrollView.delegate = self
        self.view.addSubview(self.scrollView)
        
        self.containerView = UIView()
        self.scrollView.addSubview(self.containerView)
        
        self.imageView = UIImageView(image: self.editImage)
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.clipsToBounds = true
        self.containerView.addSubview(self.imageView)
        
        self.bottomToolView = UIView()
        self.view.addSubview(self.bottomToolView)
        
        let color1 = UIColor.black.withAlphaComponent(0.15).cgColor
        let color2 = UIColor.black.withAlphaComponent(0.35).cgColor
        
        self.bottomShadowLayer = CAGradientLayer()
        self.bottomShadowLayer.colors = [color1, color2]
        self.bottomShadowLayer.locations = [0, 1]
        self.bottomToolView.layer.addSublayer(self.bottomShadowLayer)
        
        self.bottomToolLineView = UIView()
        self.bottomToolLineView.backgroundColor = zlRGB(240, 240, 240)
        self.bottomToolView.addSubview(self.bottomToolLineView)
        
        self.cancelBtn = UIButton(type: .custom)
        self.cancelBtn.setImage(getImage("zl_close"), for: .normal)
        self.cancelBtn.adjustsImageWhenHighlighted = false
        self.cancelBtn.zl_enlargeValidTouchArea(inset: 20)
        self.cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        self.bottomToolView.addSubview(self.cancelBtn)
        
        
        self.doneBtn = UIButton(type: .custom)
        self.doneBtn.setImage(getImage("zl_right"), for: .normal)
        self.doneBtn.adjustsImageWhenHighlighted = false
        self.doneBtn.zl_enlargeValidTouchArea(inset: 20)
        self.doneBtn.addTarget(self, action: #selector(doneBtnClick), for: .touchUpInside)
        self.bottomToolView.addSubview(self.doneBtn)
        
        self.rotateBtn = UIButton(type: .custom)
        self.rotateBtn.setImage(getImage("zl_rotateimage"), for: .normal)
        self.rotateBtn.adjustsImageWhenHighlighted = false
        self.rotateBtn.zl_enlargeValidTouchArea(inset: 20)
        self.rotateBtn.addTarget(self, action: #selector(rotateBtnClick), for: .touchUpInside)
        self.view.addSubview(self.rotateBtn)
        
        self.scrollView.alpha = 0
        self.bottomToolView.alpha = 0
        self.rotateBtn.alpha = 0
    }
    
    
    func calculateClipRect() {
        if self.selectedRatio.whRatio == 0 {
            self.editRect = CGRect(origin: .zero, size: self.editImage.size)
        } else {
            let imageSize = self.editImage.size
            let imageWHRatio = imageSize.width / imageSize.height
            
            var w: CGFloat = 0, h: CGFloat = 0
            if self.selectedRatio.whRatio >= imageWHRatio {
                w = imageSize.width
                h = w / self.selectedRatio.whRatio
            } else {
                h = imageSize.height
                w = h * self.selectedRatio.whRatio
            }
            
            self.editRect = CGRect(x: (imageSize.width - w) / 2, y: (imageSize.height - h) / 2, width: w, height: h)
        }
    }
    
    func layoutInitialImage() {
        self.scrollView.minimumZoomScale = 1
        self.scrollView.maximumZoomScale = 1
        self.scrollView.zoomScale = 1
        
        let editSize = self.editRect.size
        self.scrollView.contentSize = editSize
        let maxClipRect = self.maxClipFrame
        
        self.containerView.frame = CGRect(origin: .zero, size: self.editImage.size)
        self.imageView.frame = self.containerView.bounds
        
        // editRect比例，计算editRect所占frame
        let editScale = min(maxClipRect.width/editSize.width, maxClipRect.height/editSize.height)
        let scaledSize = CGSize(width: floor(editSize.width * editScale), height: floor(editSize.height * editScale))
        
        var frame = CGRect.zero
        frame.size = scaledSize
        frame.origin.x = maxClipRect.minX + floor((maxClipRect.width-frame.width) / 2)
        frame.origin.y = maxClipRect.minY + floor((maxClipRect.height-frame.height) / 2)
        
        // 按照edit image进行计算最小缩放比例
        let originalScale = min(maxClipRect.width/self.editImage.size.width, maxClipRect.height/self.editImage.size.height)
        // 将 edit rect 相对 originalScale 进行缩放，缩放到图片未放大时候的clip rect
        let scaleEditSize = CGSize(width: self.editRect.width * originalScale, height: self.editRect.height * originalScale)
        // 计算缩放后的clip rect相对maxClipRect的比例
        let clipRectZoomScale = min(maxClipRect.width/scaleEditSize.width, maxClipRect.height/scaleEditSize.height)
        
        self.scrollView.minimumZoomScale = originalScale
        self.scrollView.maximumZoomScale = 10
        // 设置当前zoom scale
        let zoomScale = (clipRectZoomScale * originalScale)
        self.scrollView.zoomScale = zoomScale
        self.scrollView.contentSize = CGSize(width: self.editImage.size.width * zoomScale, height: self.editImage.size.height * zoomScale)
        
        self.changeClipBoxFrame(newFrame: frame)
        
        if (frame.size.width < scaledSize.width - CGFloat.ulpOfOne) || (frame.size.height < scaledSize.height - CGFloat.ulpOfOne) {
            var offset = CGPoint.zero
            offset.x = -floor((self.scrollView.frame.width - scaledSize.width) / 2)
            offset.y = -floor((self.scrollView.frame.height - scaledSize.height) / 2)
            self.scrollView.contentOffset = offset
        }
        
        // edit rect 相对 image size 的 偏移量
        let diffX = self.editRect.origin.x / self.editImage.size.width * self.scrollView.contentSize.width
        let diffY = self.editRect.origin.y / self.editImage.size.height * self.scrollView.contentSize.height
        self.scrollView.contentOffset = CGPoint(x: -self.scrollView.contentInset.left+diffX, y: -self.scrollView.contentInset.top+diffY)
    }
    
    func changeClipBoxFrame(newFrame: CGRect) {
        guard self.clipBoxFrame != newFrame else {
            return
        }
        if newFrame.width < CGFloat.ulpOfOne || newFrame.height < CGFloat.ulpOfOne {
            return
        }
        var frame = newFrame
        let originX = ceil(self.maxClipFrame.minX)
        let diffX = frame.minX - originX
        frame.origin.x = max(frame.minX, originX)
        if diffX < -CGFloat.ulpOfOne {
            frame.size.width += diffX
        }
        let originY = ceil(self.maxClipFrame.minY)
        let diffY = frame.minY - originY
        frame.origin.y = max(frame.minY, originY)
        if diffY < -CGFloat.ulpOfOne {
            frame.size.height += diffY
        }
        let maxW = self.maxClipFrame.width + self.maxClipFrame.minX - frame.minX
        frame.size.width = max(self.minClipSize.width, min(frame.width, maxW))

        
        let maxH = self.maxClipFrame.height + self.maxClipFrame.minY - frame.minY
        frame.size.height = max(self.minClipSize.height, min(frame.height, maxH))

        
        self.clipBoxFrame = frame

        self.scrollView.contentInset = UIEdgeInsets(top: frame.minY, left: frame.minX, bottom: self.scrollView.frame.maxY-frame.maxY, right: self.scrollView.frame.maxX-frame.maxX)
        
        let scale = max(frame.height/self.editImage.size.height, frame.width/self.editImage.size.width)
        self.scrollView.minimumZoomScale = scale
        

        
        self.scrollView.zoomScale = self.scrollView.zoomScale
    }
    
    @objc func cancelBtnClick() {
        self.dismissAnimateFromRect = self.cancelClipAnimateFrame
        self.dismissAnimateImage = self.presentAnimateImage
        self.cancelClipBlock?()
        self.dismiss(animated: true, completion: nil)
    }
    

    
    @objc func doneBtnClick() {
        let image = self.clipImage()
        self.dismissAnimateFromRect = self.clipBoxFrame
        self.dismissAnimateImage = image.clipImage
        self.clipDoneBlock?(self.angle, image.editRect)
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func rotateBtnClick() {
        guard !self.isRotating else {
            return
        }
        self.angle -= 90
        if self.angle == -360 {
            self.angle = 0
        }
        
        self.isRotating = true
        
        let animateImageView = UIImageView(image: self.editImage)
        animateImageView.contentMode = .scaleAspectFit
        animateImageView.clipsToBounds = true
        let originFrame = self.view.convert(self.containerView.frame, from: self.scrollView)
        animateImageView.frame = originFrame
        self.view.addSubview(animateImageView)
        
        if self.selectedRatio.whRatio == 0 || self.selectedRatio.whRatio == 1 {
            // 自由比例和1:1比例，进行edit rect转换
            
            // 将edit rect转换为相对edit image的rect
            let rect = self.convertClipRectToEditImageRect()
            // 旋转图片
            self.editImage = self.editImage.rotate(orientation: .left)
            // 将rect进行旋转，转换到相对于旋转后的edit image的rect
            self.editRect = CGRect(x: rect.minY, y: self.editImage.size.height-rect.minX-rect.width, width: rect.height, height: rect.width)
        } else {
            // 其他比例的裁剪框，旋转后都重置edit rect
            
            // 旋转图片
            self.editImage = self.editImage.rotate(orientation: .left)
            self.calculateClipRect()
        }
        
        self.imageView.image = self.editImage
        self.layoutInitialImage()
        
        let toFrame = self.view.convert(self.containerView.frame, from: self.scrollView)
        let transform = CGAffineTransform(rotationAngle: -CGFloat.pi/2)

        self.containerView.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            animateImageView.transform = transform
            animateImageView.frame = toFrame
        }) { (_) in
            animateImageView.removeFromSuperview()

            self.containerView.alpha = 1
            self.isRotating = false
        }
    }

    func clipImage() -> (clipImage: UIImage, editRect: CGRect) {
        let frame = self.convertClipRectToEditImageRect()
        
        let origin = CGPoint(x: -frame.minX, y: -frame.minY)
        UIGraphicsBeginImageContextWithOptions(frame.size, false, self.editImage.scale)
        self.editImage.draw(at: origin)
        let temp = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgi = temp?.cgImage else {
            return (self.editImage, CGRect(origin: .zero, size: self.editImage.size))
        }
        let newImage = UIImage(cgImage: cgi, scale: self.editImage.scale, orientation: .up)
        return (newImage, frame)
    }
    
    func convertClipRectToEditImageRect() -> CGRect {
        let imageSize = self.editImage.size
        let contentSize = self.scrollView.contentSize
        let offset = self.scrollView.contentOffset
        let insets = self.scrollView.contentInset
        
        var frame = CGRect.zero
        frame.origin.x = floor((offset.x + insets.left) * (imageSize.width / contentSize.width))
        frame.origin.x = max(0, frame.origin.x)
        
        frame.origin.y = floor((offset.y + insets.top) * (imageSize.height / contentSize.height))
        frame.origin.y = max(0, frame.origin.y)
        
        frame.size.width = ceil(self.clipBoxFrame.width * (imageSize.width / contentSize.width))
        frame.size.width = min(imageSize.width, frame.width)
        
        frame.size.height = ceil(self.clipBoxFrame.height * (imageSize.height / contentSize.height))
        frame.size.height = min(imageSize.height, frame.height)
        
        return frame
    }
    
}






extension ZLClipImageViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.containerView
    }
    
  
    
}


extension ZLClipImageViewController: UIViewControllerTransitioningDelegate {
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ZLClipImageDismissAnimatedTransition()
    }
    
}
