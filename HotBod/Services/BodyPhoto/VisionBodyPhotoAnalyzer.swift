import Foundation
import UIKit
import Vision

enum BodyPhotoVisionMetrics {
    static let minimumPoseConfidence = 0.35
    static let minimumFramingScore = 0.45
    static let limitations = ["Visual trend analysis only. Not medical body composition."]

    static func shoulderWaistRatio(shoulderWidth: Double, waistWidth: Double) -> Double? {
        guard waistWidth > 0.01 else { return nil }
        return shoulderWidth / waistWidth
    }

    static func comparisonSummary(
        currentRatio: Double?,
        previousRatio: Double?,
        hasPrevious: Bool
    ) -> String {
        guard hasPrevious else { return "Baseline photo captured." }
        guard let currentRatio, let previousRatio else {
            return "Visual trend inconclusive. Retake with consistent pose and lighting."
        }
        let delta = currentRatio - previousRatio
        let percentChange = abs(delta / previousRatio) * 100
        if percentChange < 2 {
            return "Visual trend stable. Shoulder-to-waist ratio unchanged."
        }
        if delta > 0 {
            return String(format: "Visual trend: shoulder-to-waist ratio slightly wider (%.1f%%).", percentChange)
        }
        return String(format: "Visual trend: shoulder-to-waist ratio slightly narrower (%.1f%%).", percentChange)
    }
}

actor VisionBodyPhotoAnalyzer: BodyPhotoAnalyzer {
    private let fallback = MockBodyPhotoAnalyzer()

    func analyze(photo: BodyProgressPhoto, previous: BodyProgressPhoto?) async throws -> BodyPhotoAnalysis {
        guard let image = UIImage(contentsOfFile: photo.localImagePath),
              let cgImage = image.cgImage else {
            return try await fallback.analyze(photo: photo, previous: previous)
        }

        guard let pose = try await detectPose(in: cgImage) else {
            return try await fallback.analyze(photo: photo, previous: previous)
        }

        guard pose.poseConfidence >= BodyPhotoVisionMetrics.minimumPoseConfidence,
              pose.framingScore >= BodyPhotoVisionMetrics.minimumFramingScore else {
            return try await fallback.analyze(photo: photo, previous: previous)
        }

        let lightingScore = Self.lightingScore(for: cgImage)
        let previousRatio = previous?.analysis?.shoulderWaistRatio
        let comparisonSummary = BodyPhotoVisionMetrics.comparisonSummary(
            currentRatio: pose.shoulderWaistRatio,
            previousRatio: previousRatio,
            hasPrevious: previous != nil
        )

        return BodyPhotoAnalysis(
            poseConfidence: pose.poseConfidence,
            lightingScore: lightingScore,
            framingScore: pose.framingScore,
            shoulderWidthEstimate: pose.shoulderWidth,
            waistWidthEstimate: pose.waistWidth,
            hipWidthEstimate: pose.hipWidth,
            shoulderWaistRatio: pose.shoulderWaistRatio,
            postureNotes: pose.postureNotes,
            comparisonSummary: comparisonSummary,
            limitations: BodyPhotoVisionMetrics.limitations
        )
    }

    private struct PoseMeasurements: Sendable {
        var poseConfidence: Double
        var framingScore: Double
        var shoulderWidth: Double?
        var waistWidth: Double?
        var hipWidth: Double?
        var shoulderWaistRatio: Double?
        var postureNotes: [String]
    }

    private func detectPose(in cgImage: CGImage) async throws -> PoseMeasurements? {
        try await withCheckedContinuation { (continuation: CheckedContinuation<PoseMeasurements?, Never>) in
            let resumeGuard = ContinuationGuard<PoseMeasurements?>()

            let request = VNDetectHumanBodyPoseRequest { request, error in
                if error != nil {
                    resumeGuard.resume(continuation, returning: nil)
                    return
                }
                guard let observation = (request.results as? [VNHumanBodyPoseObservation])?.first else {
                    resumeGuard.resume(continuation, returning: nil)
                    return
                }
                resumeGuard.resume(continuation, returning: Self.measurements(from: observation))
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumeGuard.resume(continuation, returning: nil)
            }
        }
    }

    private static func measurements(from observation: VNHumanBodyPoseObservation) -> PoseMeasurements? {
        let requiredJoints: [VNHumanBodyPoseObservation.JointName] = [
            .neck, .leftShoulder, .rightShoulder, .leftHip, .rightHip, .root
        ]
        var points: [VNHumanBodyPoseObservation.JointName: (CGPoint, Float)] = [:]
        for joint in requiredJoints {
            guard let recognized = try? observation.recognizedPoint(joint),
                  recognized.confidence > 0.25 else { continue }
            points[joint] = (recognized.location, recognized.confidence)
        }

        guard let neck = points[.neck],
              let leftShoulder = points[.leftShoulder],
              let rightShoulder = points[.rightShoulder],
              let leftHip = points[.leftHip],
              let rightHip = points[.rightHip] else {
            return nil
        }

        let jointConfidences = points.values.map { Double($0.1) }
        let poseConfidence = jointConfidences.reduce(0, +) / Double(jointConfidences.count)
        let framingScore = Double(points.count) / Double(requiredJoints.count)

        let shoulderWidth = Double(abs(leftShoulder.0.x - rightShoulder.0.x))
        let hipWidth = Double(abs(leftHip.0.x - rightHip.0.x))
        let torsoHeight = max(0.05, Double(abs(neck.0.y - ((leftHip.0.y + rightHip.0.y) / 2))))
        let normalizedShoulder = shoulderWidth / torsoHeight
        let normalizedHip = hipWidth / torsoHeight
        let waistWidth = (normalizedShoulder * 0.35) + (normalizedHip * 0.65)
        let ratio = BodyPhotoVisionMetrics.shoulderWaistRatio(
            shoulderWidth: normalizedShoulder,
            waistWidth: waistWidth
        )

        var postureNotes: [String] = []
        let shoulderTilt = abs(leftShoulder.0.y - rightShoulder.0.y)
        if shoulderTilt > 0.04 {
            postureNotes.append("Shoulders appear slightly uneven.")
        } else {
            postureNotes.append("Shoulders appear level.")
        }
        if framingScore >= 0.85 {
            postureNotes.append("Full torso detected for framing.")
        } else {
            postureNotes.append("Partial pose detected — use consistent full-body framing.")
        }

        return PoseMeasurements(
            poseConfidence: poseConfidence,
            framingScore: framingScore,
            shoulderWidth: normalizedShoulder,
            waistWidth: waistWidth,
            hipWidth: normalizedHip,
            shoulderWaistRatio: ratio,
            postureNotes: postureNotes
        )
    }

    private static func lightingScore(for cgImage: CGImage) -> Double {
        let width = min(cgImage.width, 120)
        let height = min(cgImage.height, 160)
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return 0.5
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return 0.5 }

        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var luminances: [Double] = []
        luminances.reserveCapacity(width * height)
        for pixel in stride(from: 0, to: width * height * 4, by: 4) {
            let red = Double(buffer[pixel])
            let green = Double(buffer[pixel + 1])
            let blue = Double(buffer[pixel + 2])
            luminances.append((0.299 * red + 0.587 * green + 0.114 * blue) / 255)
        }

        let mean = luminances.reduce(0, +) / Double(luminances.count)
        let variance = luminances.map { pow($0 - mean, 2) }.reduce(0, +) / Double(luminances.count)
        let stdDev = sqrt(variance)

        let exposureScore: Double
        if mean < 0.15 || mean > 0.92 {
            exposureScore = 0.35
        } else if mean < 0.25 || mean > 0.85 {
            exposureScore = 0.65
        } else {
            exposureScore = 1.0
        }

        let contrastScore = min(1.0, stdDev / 0.18)
        return min(1.0, max(0.2, (exposureScore * 0.6) + (contrastScore * 0.4)))
    }
}

private final class ContinuationGuard<T: Sendable>: @unchecked Sendable {
    private var resumed = false
    private let lock = NSLock()

    func resume(_ continuation: CheckedContinuation<T, Never>, returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        continuation.resume(returning: value)
    }
}
