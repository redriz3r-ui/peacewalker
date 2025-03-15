//
//  UserProfile.swift
//  MapWalker
//
//  Created by Robe on 2/22/25.
//

import Foundation
import SwiftData

@Model
class UserProfile: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var username: String = "Walker"
    @Attribute var steps: Int = 0
    @Attribute var milesWalked: Double = 0.0
    @Attribute var pinsCollected: Int = 0

    required init() {
    }
}
