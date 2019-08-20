//
//  ProgressLineChartView.swift
//  Charts
//
//  Created by Johnny on 2019/8/20.
//

import Foundation

open class ProgressLineChartView: BarLineChartViewBase, LineChartDataProvider {
    
    open var progress: Double {
        get {
            return (renderer as? ProgressLineChartRenderer)?.progress ?? 0
        }
        set(newValue) {
            (renderer as? ProgressLineChartRenderer)?.progress = newValue
        }

    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    internal override func initialize()
    {
        super.initialize()
        applyStyle()
        renderer = ProgressLineChartRenderer(dataProvider: self, animator: _animator, viewPortHandler: _viewPortHandler)
    }
    
    func applyStyle() {
        drawGridBackgroundEnabled = false
        chartDescription?.enabled = false
        drawBordersEnabled = false
        xAxis.enabled = false
        leftAxis.enabled = false
        rightAxis.enabled = false
        dragEnabled = false
        scaleXEnabled = false
        scaleYEnabled = false
        pinchZoomEnabled = false
        legend.enabled = false
    }
    
    // MARK: - LineChartDataProvider
    
    open var lineData: LineChartData? { return _data as? LineChartData }
    
}
