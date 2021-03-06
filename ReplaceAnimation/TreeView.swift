//
//  TreeView.swift
//  ReplaceAnimation
//
//  Created by Alexander Hüllmandel on 05/03/16.
//  Copyright © 2016 Alexander Hüllmandel. All rights reserved.
//

import UIKit

@IBDesignable class TreeView : UIView {
  internal var treeLayer : TreeLayer {
    return layer as! TreeLayer
  }
  
  override class func layerClass() -> AnyClass {
    return TreeLayer.self
  }
  
  // @IBInspectable works with computed properties? whaaat
  @IBInspectable var currentBending : CGFloat {
    set {
      treeLayer.setBending(newValue)
      treeLayer.updatePaths()
    }
    get {
      return treeLayer.bending
    }
  }
  
  @IBInspectable var leafColor : UIColor {
    get {
      return UIColor(CGColor: treeLayer.leafColor)
    }
    set {
      treeLayer.leafColor = newValue.CGColor
    }
  }
  
  @IBInspectable var trunkColor : UIColor {
    get {
      return UIColor(CGColor: treeLayer.trunkColor)
    }
    set {
      treeLayer.trunkColor = newValue.CGColor
    }
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  convenience init(frame: CGRect, bending : CGFloat) {
    self.init(frame: frame)
    setup(bending)
  }
  
  override func awakeFromNib() {
    setup()
  }
  
  // might not be needed since tree layer is used as backing layer
  override func layoutSubviews() {
    treeLayer.updatePaths()
  }
  
  func setup(bending : CGFloat = 0.0) {
    treeLayer.setup(bounds, leafColor: nil, trunkColor: nil, bending: 0.0)
    treeLayer.contentsScale = UIScreen.mainScreen().scale
  }

  func startWiggle(completion : (()->())? = nil) {
    treeLayer.startWiggling(completion)
  }
  
  func stopWiggle() { treeLayer.stopWiggling() }
}

class TreeLayer : CALayer {
  private let trunk : CAShapeLayer
  private let leaf : CAShapeLayer

  /// Value from -1.0 (left-most beninding) to 1.0 (right-most bending). Default is 0.0 (no bending)
  private(set) var bending : CGFloat = 0.0
  private(set) var totalHeight : CGFloat = 0 {
    didSet {
      totalHeight = (totalHeight)
    }
  }
  
  private struct AnimationKeys {
    private struct BendingPath {
      static let leaf = "AnimationKeyBendingLeafPath"
      static let trunk = "AnimationKeBendingTrunkPath"
    }
    
    private struct Wiggle {
      static let leaf = "AnimationKeyWiggleLeaf"
      static let trunk = "AnimationKeyWiggleTrunk"
    }
  }
  
  // MARK: - Superclass overrides
  
  override init(layer: AnyObject) {
    if let layer = layer as? TreeLayer {
      bending = layer.bending
    } else {
      bending = CGFloat(0.0)
    }
    trunk = CAShapeLayer()
    leaf = CAShapeLayer()
    
    super.init(layer: layer)
  }
  
  required init?(coder aDecoder: NSCoder) {
    trunk = CAShapeLayer()
    leaf = CAShapeLayer()
    
    super.init(coder: aDecoder)
  }
  
  override init() {
    trunk = CAShapeLayer()
    leaf = CAShapeLayer()
    
    super.init()
  }
  
  // MARK: - Public interface
  var leafColor : CGColorRef = UIColor(red: 0.207, green: 0.344, blue: 0.415, alpha: 1.0).CGColor {
    didSet {
      leaf.fillColor = leafColor
    }
  }
  
  var trunkColor : CGColorRef = UIColor(red: 0.155, green: 0.258, blue: 0.311, alpha: 1.0).CGColor {
    didSet {
      trunk.fillColor = trunkColor
    }
  }
  
  func setBending(bending : CGFloat, animated : Bool = false, duration : CFTimeInterval = 0.0) {
    let limitedBending = TreeLayer.limitedBending(bending)
    self.bending = limitedBending
    
    if (animated) {
      let animationDuration = min(0.25, duration);
      
      let leafAnimation = CABasicAnimation(keyPath: "path")
      leafAnimation.toValue = TreeLayer.leafPathForBending(limitedBending, totalHeight: totalHeight)
      leafAnimation.duration = animationDuration
      
      leaf.addAnimation(leafAnimation, forKey: "bodyAnimation")
      
      let trunkAnimation = CABasicAnimation(keyPath: "path")
      trunkAnimation.toValue = TreeLayer.trunkPathForBending(limitedBending, totalHeight: totalHeight)
      trunkAnimation.duration = animationDuration
      
      trunk.addAnimation(trunkAnimation, forKey: "trunkAnimation")
    } else {
      updatePaths()
    }
  }
  
  func setup(bounds : CGRect, leafColor : UIColor? = nil, trunkColor : UIColor? = nil, bending : CGFloat = 0.0) {
    
    let totalHeight = bounds.size.height
    self.bending = bending
    self.totalHeight = totalHeight
    
    let paths = TreeLayer.leftAlignedPathsForBending(bending, totalHeight: totalHeight)
    
    leaf.contentsScale = UIScreen.mainScreen().scale
    leaf.drawsAsynchronously = true
    leaf.frame = bounds
    leaf.path = paths.0
    
    trunk.contentsScale = UIScreen.mainScreen().scale
    leaf.drawsAsynchronously = true
    trunk.frame = bounds
    trunk.path = paths.1
    
    // will set the color of the sublayers
    self.leafColor = leafColor?.CGColor ?? self.leafColor
    self.trunkColor = trunkColor?.CGColor ?? self.trunkColor
    
    addSublayer(leaf)
    addSublayer(trunk)
  }
  
  func updatePaths() {
    totalHeight = bounds.size.height
    if let _ = trunk.animationKeys(), _ = leaf.animationKeys() {
      // there is an animation going on
    } else {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      
      let paths = TreeLayer.leftAlignedPathsForBending(bending, totalHeight: totalHeight)
      leaf.path = paths.0
      trunk.path = paths.1
      
      CATransaction.commit()
    }
  }
  
  func startWiggling(completion : (()->())?) {
    if leaf.animationForKey(AnimationKeys.Wiggle.leaf) != nil || trunk.animationForKey(AnimationKeys.Wiggle.trunk) != nil { return }
    
    CATransaction.begin()
    CATransaction.setCompletionBlock(completion)
    
    let duration = 0.5 // should depend on scroll view offset, to be in synch with bounce animation
    
    let paths0 = TreeLayer.leftAlignedPathsForBending(bending, totalHeight: totalHeight)
    let paths1 = TreeLayer.leftAlignedPathsForBending(-0.8 * bending, totalHeight: totalHeight)
    let paths2 = TreeLayer.leftAlignedPathsForBending(0.8 * bending, totalHeight: totalHeight)
    let paths3 = TreeLayer.leftAlignedPathsForBending(-0.4 * bending, totalHeight: totalHeight)
    let paths4 = TreeLayer.leftAlignedPathsForBending(0.35 * bending, totalHeight: totalHeight)
    let paths5 = TreeLayer.leftAlignedPathsForBending(-0.2 * bending, totalHeight: totalHeight)
    let paths6 = TreeLayer.leftAlignedPathsForBending(0.1 * bending, totalHeight: totalHeight)
    let paths7 = TreeLayer.leftAlignedPathsForBending(-0.05 * bending, totalHeight: totalHeight)
    let paths8 = TreeLayer.leftAlignedPathsForBending(0.0, totalHeight: totalHeight)
    
    let frameAnimation = CAKeyframeAnimation(keyPath: "path")
    frameAnimation.duration = CFTimeInterval(duration)
    frameAnimation.values = [paths0.0, paths1.0, paths1.0, paths2.0, paths3.0, paths4.0, paths5.0, paths6.0, paths7.0, paths8.0]
    frameAnimation.timingFunctions = [
      CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn),
      CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut),
      CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn),
      CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut),
      CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn),
      CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut),
      CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn),
      CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
    ]
    frameAnimation.keyTimes = [0.0, 0.2, 0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 1.0]
    
    leaf.path = paths8.0
    leaf.addAnimation(frameAnimation, forKey: AnimationKeys.Wiggle.leaf)
    
    frameAnimation.values = [paths0.1, paths1.1, paths1.1, paths2.1, paths3.1, paths4.1, paths5.1, paths6.1, paths7.1, paths8.1]
    trunk.path = paths8.1
    trunk.addAnimation(frameAnimation, forKey: AnimationKeys.Wiggle.trunk)
    
    CATransaction.commit()
  }
  
  func stopWiggling() {
    trunk.removeAnimationForKey(AnimationKeys.Wiggle.trunk)
    leaf.removeAnimationForKey(AnimationKeys.Wiggle.leaf)
  }
  
  // MARK: - Private interface
  
  /**
   Limits the bending withing range {-1.0, 1.0}
   
   - parameter bending: The bending value
   
   - returns: If bending < -1.0 -> -1.0, if bending > 1.0 -> 1.0, else bending
   */
  private class func limitedBending(bending : CGFloat) -> CGFloat {
    return max(-1.0, min(1.0, bending))
  }
  
  // Ratio between width and height of the entire tree path
  private static let aspectRatio : CGFloat = 0.13715
  
  // Ratio between the maximum allowed horizontal bending and the total Height, i.e. when the tree is 200points high and this value is 0.5, the control points for the tree's bezier curve would be offset by 100 at maximum bending.
  private static let maxBendingXOffsetToHeightRatio : CGFloat = 0.25
  
  private class func leafPathForBending(bending : CGFloat, totalHeight height : CGFloat) -> UIBezierPath {
    let limitedBending = TreeLayer.limitedBending(bending)
    let controlPointXOffset = limitedBending * TreeLayer.maxBendingXOffsetToHeightRatio * height
    
    let path = UIBezierPath()
    // FLOOR
    let totalHeight = height
    let totalWidth = TreeLayer.aspectRatio*height
    
    path.moveToPoint(CGPoint(x: totalWidth, y: 0.762*totalHeight))
    path.addCurveToPoint(
      CGPoint(x: totalWidth+controlPointXOffset, y: 0),
      controlPoint1: CGPoint(x: 2.643*totalWidth, y: 0.762*totalHeight),
      controlPoint2: CGPoint(x: 1.571*totalWidth, y: 0.381*totalHeight)
    )
    path.addCurveToPoint(
      CGPoint(x: totalWidth, y: 0.762*totalHeight),
      controlPoint1: CGPoint(x: (0.429*totalWidth), y: (0.381*totalHeight)),
      controlPoint2: CGPoint(x: (-0.642*totalWidth), y: (0.762*totalHeight))
    )
    
    return path
  }
  
  private class func trunkPathForBending(bending : CGFloat, totalHeight height : CGFloat) -> UIBezierPath {
    let limitedBending = TreeLayer.limitedBending(bending)
    let controlPointXOffset = limitedBending * TreeLayer.maxBendingXOffsetToHeightRatio * height
    
    let totalHeight = (height)
    let totalWidth = (TreeLayer.aspectRatio*height)
    
    let path = UIBezierPath()
    
    // trunk
    path.moveToPoint(CGPoint(x: (1.143*totalWidth), y: (totalHeight)))
    path.addQuadCurveToPoint(
      CGPoint(x: (totalWidth+controlPointXOffset*0.5), y: (0.238*totalHeight)),
      controlPoint: CGPoint(x: (1.071*totalWidth), y: (0.619*totalHeight))
    )
    
    path.addQuadCurveToPoint(
      CGPoint(x: (0.857*totalWidth), y: (0.988*totalHeight)),
      controlPoint: CGPoint(x: (0.929*totalWidth), y: (0.619*totalHeight))
    )
    
    return path
  }
  
  /**
   Drawing a bezier curve will make it hard to guess where the leftmost point is. So we just create the path and take the leafs bounds.origin.x value to offset the two paths. That way, the tree will be left aligned in the superlayer
   
   - parameter bending: Defines how much the tree is bended. Value between -1 and 1
   - parameter height:  The totalHeight of the tree
   
   - returns: Tuple containing the *leafPath* and the *trunkPath* as `CGPathRef`s
   */
  private class func leftAlignedPathsForBending(bending : CGFloat, totalHeight height : CGFloat) -> (CGPathRef, CGPathRef) {
    let leafPath = leafPathForBending(bending, totalHeight: height)
    let trunkPath = trunkPathForBending(bending, totalHeight: height)
    
    let offset = leafPathForBending(0.0, totalHeight: height).bounds.origin
    
    let translation = CGAffineTransformMakeTranslation(-offset.x, -offset.y);
    leafPath.applyTransform(translation)
    trunkPath.applyTransform(translation)
    
    return (leafPath.CGPath, trunkPath.CGPath)
  }
  
  func animateTest() {
    let paths0 = TreeLayer.leftAlignedPathsForBending(1.0, totalHeight: totalHeight)
    let paths1 = TreeLayer.leftAlignedPathsForBending(-0.3, totalHeight: totalHeight)
    let paths2 = TreeLayer.leftAlignedPathsForBending(1.15, totalHeight: totalHeight)
    let paths3 = TreeLayer.leftAlignedPathsForBending(-0.05, totalHeight: totalHeight)
    let paths4 = TreeLayer.leftAlignedPathsForBending(0.0, totalHeight: totalHeight)
    
    let frameAnimation = CAKeyframeAnimation(keyPath: "path")
    frameAnimation.duration = 1.0
    frameAnimation.values = [paths0.0, paths1.0, paths2.0, paths3.0, paths4.0]
    frameAnimation.timingFunctions = [CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault), CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn), CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut), CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn), CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)]
    frameAnimation.keyTimes = [0.0, 0.2,0.5,0.8,1.0]
    
    leaf.addAnimation(frameAnimation, forKey: nil)
    
    frameAnimation.values = [paths0.1, paths1.1, paths2.1, paths3.1, paths4.1]
    trunk.addAnimation(frameAnimation, forKey: nil)
  }
}
