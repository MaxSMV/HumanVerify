//
//  Emotion.swift
//  HumanVerify IOS APP
//
//  Created by Max Stefankiv on 18.04.2023.
//

import Foundation

struct EmotionResponse: Decodable {
    let x: Int?
    let y: Int?
    let w: Int?
    let h: Int?
    let emotion: String?
    let error: String?
}


