//
//  Journey.swift
//  MapWalker
//
//  Created by Robe on 2/22/25.
//

import Foundation
import SwiftData

@Model
class Journey: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var startDistance: Double = 0.0
    @Attribute var startDate: Date = Date()
    @Attribute var stepCount: Int = 0
    @Relationship var walkSessions: [WalkSession] = []
    
    required init() {}
}
