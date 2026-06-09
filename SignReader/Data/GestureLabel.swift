//
//  GestureLabel.swift
//  SignReader
//
//  Created by Viranaiken Jessy on 09/06/2026.
//

import Foundation

// All the possible signs the ML model can recognize.
// The text inside the quotes (e.g. "A") must match exactly the labels saved in the model file.
// The 26 letters of the alphabet plus three special tokens (space, delete, nothing)
// and one "unknown" used by the UI when confidence is too low.
nonisolated enum GestureLabel: String, CaseIterable, Identifiable, Codable, Sendable {
    case a = "A", b = "B", c = "C", d = "D", e = "E", f = "F", g = "G"
    case h = "H", i = "I", j = "J", k = "K", l = "L", m = "M", n = "N"
    case o = "O", p = "P", q = "Q", r = "R", s = "S", t = "T", u = "U"
    case v = "V", w = "W", x = "X", y = "Y", z = "Z"
    case space   = "space"
    case del     = "del"
    case nothing = "nothing"
    case unknown

    // Unique id used by SwiftUI lists.
    var id: String { rawValue }

    // Human-readable name shown in the UI.
    var displayName: String {
        switch self {
        case .space:   return NSLocalizedString("Space", comment: "space token")
        case .del:     return NSLocalizedString("Delete", comment: "delete token")
        case .nothing: return NSLocalizedString("Nothing", comment: "no sign detected")
        case .unknown: return NSLocalizedString("Unknown", comment: "low-confidence prediction")
        default:       return rawValue
        }
    }

    // Small character used to represent the sign visually (used in lists).
    var emoji: String {
        switch self {
        case .space:   return "␣"
        case .del:     return "⌫"
        case .nothing: return "·"
        case .unknown: return "?"
        default:       return rawValue
        }
    }

    // The list of signs the user can record training samples for.
    // We hide "unknown" (UI only) and "nothing" (predicted but not signed by the user).
    static var trainableCases: [GestureLabel] {
        allCases.filter { $0 != .unknown && $0 != .nothing }
    }
}
