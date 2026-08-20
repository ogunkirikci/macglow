import Foundation

public struct RGBColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }
}

public enum DominantColorExtractor {
    public static func palette(from pixels: [RGBColor], count: Int = 4) -> [RGBColor] {
        guard count > 0 else { return [] }
        var buckets: [Int: (red: Double, green: Double, blue: Double, count: Int)] = [:]

        for pixel in pixels {
            let brightness = max(pixel.red, pixel.green, pixel.blue)
            let minimum = min(pixel.red, pixel.green, pixel.blue)
            guard brightness > 0.08, !(brightness > 0.96 && minimum > 0.90) else { continue }

            let r = min(Int(pixel.red * 8), 7)
            let g = min(Int(pixel.green * 8), 7)
            let b = min(Int(pixel.blue * 8), 7)
            let key = (r << 6) | (g << 3) | b
            var bucket = buckets[key] ?? (0, 0, 0, 0)
            bucket.red += pixel.red
            bucket.green += pixel.green
            bucket.blue += pixel.blue
            bucket.count += 1
            buckets[key] = bucket
        }

        let candidates = buckets.values.sorted { lhs, rhs in
            let lhsSaturation = saturation(red: lhs.red / Double(lhs.count), green: lhs.green / Double(lhs.count), blue: lhs.blue / Double(lhs.count))
            let rhsSaturation = saturation(red: rhs.red / Double(rhs.count), green: rhs.green / Double(rhs.count), blue: rhs.blue / Double(rhs.count))
            return Double(lhs.count) * (0.7 + lhsSaturation) > Double(rhs.count) * (0.7 + rhsSaturation)
        }

        var result: [RGBColor] = []
        for bucket in candidates {
            let divisor = Double(bucket.count)
            let color = RGBColor(red: bucket.red / divisor, green: bucket.green / divisor, blue: bucket.blue / divisor)
            guard result.allSatisfy({ distance($0, color) > 0.16 }) else { continue }
            result.append(color)
            if result.count == count { break }
        }
        return result
    }

    private static func saturation(red: Double, green: Double, blue: Double) -> Double {
        let maximum = max(red, green, blue)
        guard maximum > 0 else { return 0 }
        return (maximum - min(red, green, blue)) / maximum
    }

    private static func distance(_ lhs: RGBColor, _ rhs: RGBColor) -> Double {
        let red = lhs.red - rhs.red
        let green = lhs.green - rhs.green
        let blue = lhs.blue - rhs.blue
        return sqrt(red * red + green * green + blue * blue)
    }
}
