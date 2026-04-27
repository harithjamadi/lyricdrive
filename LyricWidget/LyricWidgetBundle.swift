//
//  LyricWidgetBundle.swift
//  LyricWidget
//
//  Created by Abdullah Harith Jamadi on 27/04/2026.
//

import WidgetKit
import SwiftUI

@main
struct LyricWidgetBundle: WidgetBundle {
    var body: some Widget {
        LyricWidget()
        LyricWidgetControl()
        LyricWidgetLiveActivity()
    }
}
