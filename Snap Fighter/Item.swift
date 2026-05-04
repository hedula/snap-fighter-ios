//
//  Item.swift
//  Snap Fighter
//
//  Created by Hedula Lee on 2026/5/4.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
