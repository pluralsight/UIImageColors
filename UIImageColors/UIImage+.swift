//
//  UIImage+.swift
//  UIImageColors
//
//  Created by Dev Team on 2/26/16.
//  Copyright © 2016 Pluralsight. All rights reserved.
//

import Foundation
public extension UIImage {
    
    public func resize(_ newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result!
    }
    
    public func getColors() -> UIImageColors {
        let ratio = size.width / size.height
        let r_width: CGFloat = 250
        return getColors(CGSize(width: r_width, height: r_width/ratio))
    }
    
    public func getColors(_ scaleDownSize: CGSize) -> UIImageColors {
        var result = UIImageColors()
        
        let cgImage = self.resize(scaleDownSize).cgImage!
        let width = cgImage.width
        let height = cgImage.height
        
        let bytesPerPixel: Int = 4
        let bytesPerRow: Int = width * bytesPerPixel
        let bitsPerComponent: Int = 8
        let randomColorsThreshold = Int(CGFloat(height)*0.01)
        let sortedColorComparator: Comparator = { (main, other) -> ComparisonResult in
            let m = main as! PCCountedColor, o = other as! PCCountedColor
            if m.count < o.count {
                return .orderedDescending
            } else if m.count == o.count {
                return .orderedSame
            } else {
                return .orderedAscending
            }
        }
        let blackColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        let whiteColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let raw = malloc(bytesPerRow * height)
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
        let ctx = CGContext(data: raw, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)!
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        let bytes = ctx.data!.assumingMemoryBound(to: UInt8.self)
        let data = UnsafePointer<UInt8>(bytes)
        
        let leftEdgeColors = NSCountedSet(capacity: height)
        let imageColors = NSCountedSet(capacity: width * height)
        
        for x in 0..<width {
            for y in 0..<height {
                let pixel = ((width * y) + x) * bytesPerPixel
                let color = UIColor(
                    red: CGFloat(data[pixel+1])/255,
                    green: CGFloat(data[pixel+2])/255,
                    blue: CGFloat(data[pixel+3])/255,
                    alpha: 1
                )
                
                // A lot of albums have white or black edges from crops, so ignore the first few pixels
                if 5 <= x && x <= 10 {
                    leftEdgeColors.add(color)
                }
                
                imageColors.add(color)
            }
        }
        
        // Get background color
        var enumerator = leftEdgeColors.objectEnumerator()
        var sortedColors = NSMutableArray(capacity: leftEdgeColors.count)
        while let kolor = enumerator.nextObject() as? UIColor {
            let colorCount = leftEdgeColors.count(for: kolor)
            if randomColorsThreshold < colorCount  {
                sortedColors.add(PCCountedColor(color: kolor, count: colorCount))
            }
        }
        sortedColors.sort(comparator: sortedColorComparator)
        
        var proposedEdgeColor: PCCountedColor
        if 0 < sortedColors.count {
            proposedEdgeColor = sortedColors.object(at: 0) as! PCCountedColor
        } else {
            proposedEdgeColor = PCCountedColor(color: blackColor, count: 1)
        }
        
        if proposedEdgeColor.color.isBlackOrWhite && 0 < sortedColors.count {
            for i in 1..<sortedColors.count {
                let nextProposedEdgeColor = sortedColors.object(at: i) as! PCCountedColor
                if (CGFloat(nextProposedEdgeColor.count)/CGFloat(proposedEdgeColor.count)) > 0.3 {
                    if !nextProposedEdgeColor.color.isBlackOrWhite {
                        proposedEdgeColor = nextProposedEdgeColor
                        break
                    }
                } else {
                    break
                }
            }
        }
        result.backgroundColor = proposedEdgeColor.color
        
        // Get foreground colors
        enumerator = imageColors.objectEnumerator()
        sortedColors.removeAllObjects()
        sortedColors = NSMutableArray(capacity: imageColors.count)
        let findDarkTextColor = !result.backgroundColor.isDarkColor
        
        while var kolor = enumerator.nextObject() as? UIColor {
            kolor = kolor.colorWithMinimumSaturation(0.15)
            if kolor.isDarkColor == findDarkTextColor {
                let colorCount = imageColors.count(for: kolor)
                sortedColors.add(PCCountedColor(color: kolor, count: colorCount))
            }
        }
        sortedColors.sort(comparator: sortedColorComparator)
        
        for curContainer in sortedColors {
            let kolor = (curContainer as! PCCountedColor).color
            
            if result.primaryColor == nil {
                if kolor.isContrastingColor(result.backgroundColor) {
                    result.primaryColor = kolor
                }
            } else if result.secondaryColor == nil {
                if !result.primaryColor.isDistinct(kolor) || !kolor.isContrastingColor(result.backgroundColor) {
                    continue
                }
                
                result.secondaryColor = kolor
            } else if result.detailColor == nil {
                if !result.secondaryColor.isDistinct(kolor) || !result.primaryColor.isDistinct(kolor) || !kolor.isContrastingColor(result.backgroundColor) {
                    continue
                }
                
                result.detailColor = kolor
                break
            }
        }
        
        let isDarkBackgound = result.backgroundColor.isDarkColor
        
        if result.primaryColor == nil {
            result.primaryColor = isDarkBackgound ? whiteColor:blackColor
        }
        
        if result.secondaryColor == nil {
            result.secondaryColor = isDarkBackgound ? whiteColor:blackColor
        }
        
        if result.detailColor == nil {
            result.detailColor = isDarkBackgound ? whiteColor:blackColor
        }
        
        // Release the allocated memory
        free(raw)
        
        return result
    }
    
}
