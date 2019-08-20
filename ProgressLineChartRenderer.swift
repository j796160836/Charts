//
//  ProgressLineChartRenderer.swift
//  Charts
//
//  Created by Johnny on 2019/8/20.
//

import Foundation
import CoreGraphics

open class ProgressLineChartRenderer: LineChartRenderer {
    
    var progress: Double = 0
    
    override open func drawDataSet(context: CGContext, dataSet: ILineChartDataSet) {
        if dataSet.entryCount < 1
        {
            return
        }
        
        context.saveGState()
        
        context.setLineWidth(dataSet.lineWidth)
        if dataSet.lineDashLengths != nil
        {
            context.setLineDash(phase: dataSet.lineDashPhase, lengths: dataSet.lineDashLengths!)
        }
        else
        {
            context.setLineDash(phase: 0.0, lengths: [])
        }
        
        context.setLineCap(dataSet.lineCapType)
        
        // if drawing cubic lines is enabled
        switch dataSet.mode
        {
        case .linear: fallthrough
        case .stepped:
            drawLinear(context: context, dataSet: dataSet)
            
        case .cubicBezier:
            drawCubicBezier(context: context, dataSet: dataSet)
            
        case .horizontalBezier:
            drawHorizontalBezier(context: context, dataSet: dataSet)
        case .cubicBezierWithProgress:
            drawProgressCubicBezier(context: context, dataSet: dataSet, progress: self.progress)
        }
        
        context.restoreGState()
    }
    
    @objc open func drawProgressCubicBezier(context: CGContext, dataSet: ILineChartDataSet, progress: Double)
    {
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        // get the color that is specified for this position from the DataSet
        let drawingColor = dataSet.colors.first!
        
        let intensity = dataSet.cubicIntensity
        
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        if _xBounds.range >= 1
        {
            var prevDx: CGFloat = 0.0
            var prevDy: CGFloat = 0.0
            var curDx: CGFloat = 0.0
            var curDy: CGFloat = 0.0
            
            // Take an extra point from the left, and an extra from the right.
            // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
            // So in the starting `prev` and `cur`, go -2, -1
            // And in the `lastIndex`, add +1
            
            let firstIndex = _xBounds.min + 1
            let lastIndex = _xBounds.min + _xBounds.range
            
            var prevPrev: ChartDataEntry! = nil
            var prev: ChartDataEntry! = dataSet.entryForIndex(max(firstIndex - 2, 0))
            var cur: ChartDataEntry! = dataSet.entryForIndex(max(firstIndex - 1, 0))
            var next: ChartDataEntry! = cur
            var nextIndex: Int = -1
            
            if cur == nil { return }
            
            // let the spline start
            cubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
            
            for j in stride(from: firstIndex, through: lastIndex, by: 1)
            {
                prevPrev = prev
                prev = cur
                cur = nextIndex == j ? next : dataSet.entryForIndex(j)
                
                nextIndex = j + 1 < dataSet.entryCount ? j + 1 : j
                next = dataSet.entryForIndex(nextIndex)
                
                if next == nil { break }
                
                prevDx = CGFloat(cur.x - prevPrev.x) * intensity
                prevDy = CGFloat(cur.y - prevPrev.y) * intensity
                curDx = CGFloat(next.x - prev.x) * intensity
                curDy = CGFloat(next.y - prev.y) * intensity
                
                cubicPath.addCurve(
                    to: CGPoint(
                        x: CGFloat(cur.x),
                        y: CGFloat(cur.y) * CGFloat(phaseY)),
                    control1: CGPoint(
                        x: CGFloat(prev.x) + prevDx,
                        y: (CGFloat(prev.y) + prevDy) * CGFloat(phaseY)),
                    control2: CGPoint(
                        x: CGFloat(cur.x) - curDx,
                        y: (CGFloat(cur.y) - curDy) * CGFloat(phaseY)),
                    transform: valueToPixelMatrix)
            }
        }
        
        context.saveGState()
        
        if dataSet.isDrawFilledEnabled
        {
            // Copy this path because we make changes to it
            let fillPath = cubicPath.mutableCopy()
            
            drawProgressCubicFill(context: context, dataSet: dataSet, spline: fillPath!, matrix: valueToPixelMatrix, bounds: _xBounds, progress: progress)
        }
        
        context.beginPath()
        context.addPath(cubicPath)
        context.setStrokeColor(drawingColor.cgColor)
        context.strokePath()
        
        context.restoreGState()
    }
    
    open func drawProgressCubicFill(
        context: CGContext,
        dataSet: ILineChartDataSet,
        spline: CGMutablePath,
        matrix: CGAffineTransform,
        bounds: XBounds,
        progress: Double)
    {
        guard
            let dataProvider = dataProvider
            else { return }
        
        if bounds.range <= 0
        {
            return
        }
        
        let fillMin = dataSet.fillFormatter?.getFillLinePosition(dataSet: dataSet, dataProvider: dataProvider) ?? 0.0
        
        var pt1 = CGPoint(x: CGFloat(dataSet.entryForIndex(bounds.min + bounds.range )?.x ?? 0.0), y: fillMin)
        var pt2 = CGPoint(x: CGFloat(dataSet.entryForIndex(bounds.min)?.x ?? 0.0), y: fillMin)
        pt1 = pt1.applying(matrix)
        pt2 = pt2.applying(matrix)
    
        spline.addLine(to: pt1)
        spline.addLine(to: pt2)
        spline.closeSubpath()
        
        if dataSet.fill != nil
        {
            drawProgressFilledPath(context: context, path: spline, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha, progress: progress)
        }
        else
        {
            drawProgressFilledPath(context: context, path: spline, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha, progress: progress)
        }
    }
    
    /// Draws the provided path in filled mode with the provided drawable.
    @objc open func drawProgressFilledPath(context: CGContext, path: CGPath, fill: Fill, fillAlpha: CGFloat, progress: Double)
    {
        
        context.saveGState()
        
        context.clip(to: CGRect(x: viewPortHandler.contentLeft, y: 0, width: viewPortHandler.contentWidth * CGFloat(progress), height: viewPortHandler.contentHeight))
        
        context.beginPath()
        context.addPath(path)
        
        // filled is usually drawn with less alpha
        context.setAlpha(fillAlpha)
        
        fill.fillPath(context: context, rect: viewPortHandler.contentRect)
        
        context.restoreGState()
    }
    
    /// Draws the provided path in filled mode with the provided color and alpha.
    @objc open func drawProgressFilledPath(context: CGContext, path: CGPath, fillColor: NSUIColor, fillAlpha: CGFloat, progress: Double)
    {
        context.saveGState()
        
        context.clip(to: CGRect(x: viewPortHandler.contentLeft, y: 0, width: viewPortHandler.contentWidth * CGFloat(progress), height: viewPortHandler.contentHeight))
        
        context.beginPath()
        context.addPath(path)
        
        // filled is usually drawn with less alpha
        context.setAlpha(fillAlpha)
        
        context.setFillColor(fillColor.cgColor)
        context.fillPath()
        
        context.restoreGState()
    }
    
}
