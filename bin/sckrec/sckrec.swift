// sckrec - screen + system audio recorder for macOS, no virtual audio driver.
//
// Video: ScreenCaptureKit. Audio: CoreAudio process tap (macOS 14.4+), because
// ScreenCaptureKit's capturesAudio delivers silence for terminal-spawned
// processes on macOS 26 even when kTCCServiceAudioCapture is granted.
// Both are muxed into one .mov/.mp4 via AVAssetWriter on the host-time clock.
//
// build: swiftc -O -o sckrec sckrec.swift \
//          -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist
//
// The embedded Info.plist gives this unbundled CLI a bundle identity, so the
// macOS privacy indicator attributes captures to "sckrec" instead of
// "unknown" (anonymous attributions have no lifecycle and linger).

import AppKit
import Foundation
import AVFoundation
import CoreAudio
import CoreMedia
import ScreenCaptureKit

func err(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

func usage() -> Never {
    err("""
    usage: sckrec [-t seconds] [-o output.mov] [--fps N] [--bitrate Mbps] [--display N] [--no-audio] [--meter] [--list]
      -t seconds     stop automatically after N seconds (default: run until Ctrl+C)
      -o path        output file, .mov or .mp4 (default: sckrec-YYYYmmdd-HHMMSS.mov)
      --fps N        frame rate (default 30)
      --bitrate M    video bitrate in Mbit/s (default 8)
      --display N    capture display N (default 0, see --list)
      --no-audio     video only
      --meter        report captured audio peak on exit
      --list         list displays and exit
    """)
    exit(64)
}

var duration: Double? = nil
var outPath: String? = nil
var fps = 30
var bitrateMbps = 8.0
var displayIndex = 0
var captureAudio = true
var meterOn = false
var listOnly = false

var args = CommandLine.arguments.dropFirst().makeIterator()
while let a = args.next() {
    switch a {
    case "-t":         guard let v = args.next(), let d = Double(v), d > 0 else { usage() }; duration = d
    case "-o":         guard let v = args.next() else { usage() }; outPath = v
    case "--fps":      guard let v = args.next(), let f = Int(v), f > 0 else { usage() }; fps = f
    case "--bitrate":  guard let v = args.next(), let b = Double(v), b > 0 else { usage() }; bitrateMbps = b
    case "--display":  guard let v = args.next(), let i = Int(v), i >= 0 else { usage() }; displayIndex = i
    case "--no-audio": captureAudio = false
    case "--meter":    meterOn = true
    case "--list":     listOnly = true
    case "-h", "--help": usage()
    default:
        if outPath == nil && !a.hasPrefix("-") { outPath = a } else { usage() }
    }
}

// MARK: - Shared recording state

let writeQueue = DispatchQueue(label: "sckrec.write")
var writer: AVAssetWriter!
var videoInput: AVAssetWriterInput!
var audioInput: AVAssetWriterInput?
var sessionStarted = false
var videoFrames = 0
var audioPeak: Float = 0
var audioBuffers = 0
var pendingAudio: [CMSampleBuffer] = []

// Written from the realtime IO thread, read from writeQueue.
var audioFormatDesc: CMAudioFormatDescription?
var audioASBD = AudioStreamBasicDescription()

// MARK: - CoreAudio process tap (system audio)

var tapID = AudioObjectID(kAudioObjectUnknown)
var aggID = AudioObjectID(kAudioObjectUnknown)
var ioProcID: AudioDeviceIOProcID?

func startAudioTap() -> Bool {
    let desc = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
    desc.name = "sckrec-tap"
    desc.isPrivate = true
    desc.muteBehavior = .unmuted
    guard AudioHardwareCreateProcessTap(desc, &tapID) == noErr else {
        err("warning: could not create system audio tap"); return false
    }
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioTapPropertyFormat,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    guard AudioObjectGetPropertyData(tapID, &addr, 0, nil, &size, &audioASBD) == noErr,
          CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &audioASBD,
                                         layoutSize: 0, layout: nil, magicCookieSize: 0,
                                         magicCookie: nil, extensions: nil,
                                         formatDescriptionOut: &audioFormatDesc) == noErr else {
        err("warning: could not read tap format"); return false
    }
    let aggDesc: [String: Any] = [
        kAudioAggregateDeviceNameKey as String: "sckrec-agg",
        kAudioAggregateDeviceUIDKey as String: UUID().uuidString,
        kAudioAggregateDeviceIsPrivateKey as String: true,
        kAudioAggregateDeviceTapAutoStartKey as String: true,
        kAudioAggregateDeviceTapListKey as String: [
            [kAudioSubTapUIDKey as String: desc.uuid.uuidString]
        ],
    ]
    guard AudioHardwareCreateAggregateDevice(aggDesc as CFDictionary, &aggID) == noErr else {
        err("warning: could not create aggregate device"); return false
    }
    guard AudioDeviceCreateIOProcID(aggID, { _, _, inData, inTime, _, _, _ in
        let srcABL = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData))
        var totalBytes = 0
        for buf in srcABL { totalBytes += Int(buf.mDataByteSize) }
        guard totalBytes > 0, let fmt = audioFormatDesc else { return noErr }

        // Deep-copy the buffer list; the source memory is only valid during this callback.
        let staged = AudioBufferList.allocate(maximumBuffers: srcABL.count)
        for (i, buf) in srcABL.enumerated() {
            let bytes = Int(buf.mDataByteSize)
            let mem = UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: MemoryLayout<Float>.alignment)
            if let src = buf.mData { mem.copyMemory(from: src, byteCount: bytes) }
            staged[i] = AudioBuffer(mNumberChannels: buf.mNumberChannels,
                                    mDataByteSize: buf.mDataByteSize, mData: mem)
        }
        let pts: CMTime = inTime.pointee.mFlags.contains(.hostTimeValid)
            ? CMClockMakeHostTimeFromSystemUnits(inTime.pointee.mHostTime)
            : CMClockGetTime(CMClockGetHostTimeClock())
        let bytesPerFrame = Int(audioASBD.mBytesPerFrame)
        let frames = bytesPerFrame > 0 ? Int(staged[0].mDataByteSize) / bytesPerFrame : 0

        writeQueue.async {
            defer {
                for buf in staged where buf.mData != nil { buf.mData!.deallocate() }
                free(staged.unsafeMutablePointer)
            }
            audioBuffers += 1
            for buf in staged {
                let n = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
                guard let p = buf.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for i in 0..<n { audioPeak = max(audioPeak, abs(p[i])) }
            }
            guard frames > 0, let input = audioInput else { return }
            var timing = CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: CMTimeScale(audioASBD.mSampleRate)),
                presentationTimeStamp: pts, decodeTimeStamp: .invalid)
            var sbuf: CMSampleBuffer?
            guard CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil,
                                       dataReady: false, makeDataReadyCallback: nil, refcon: nil,
                                       formatDescription: fmt, sampleCount: frames,
                                       sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                       sampleSizeEntryCount: 0, sampleSizeArray: nil,
                                       sampleBufferOut: &sbuf) == noErr, let sbuf else { return }
            guard CMSampleBufferSetDataBufferFromAudioBufferList(
                sbuf, blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0,
                bufferList: staged.unsafePointer) == noErr else { return }
            // The writer session opens with the first video frame; queue audio
            // captured before then (and during input backpressure) so the head
            // of the recording keeps its sound.
            pendingAudio.append(sbuf)
            if pendingAudio.count > 400 { pendingAudio.removeFirst() }
            guard sessionStarted else { return }
            while let next = pendingAudio.first, input.isReadyForMoreMediaData {
                input.append(next)
                pendingAudio.removeFirst()
            }
        }
        return noErr
    }, nil, &ioProcID) == noErr, ioProcID != nil else {
        err("warning: could not create audio IO proc"); return false
    }
    guard AudioDeviceStart(aggID, ioProcID) == noErr else {
        err("warning: could not start audio device"); return false
    }
    return true
}

// Idempotent, and registered via atexit once the tap exists: macOS does not
// reliably reap tap/stream registrations when the owner exits without
// destroying them, which leaves the menu bar recording indicator stuck.
func stopAudioTap() {
    if let p = ioProcID, aggID != kAudioObjectUnknown {
        AudioDeviceStop(aggID, p)
        if AudioDeviceDestroyIOProcID(aggID, p) != noErr { err("warning: IO proc teardown failed") }
        ioProcID = nil
    }
    if aggID != kAudioObjectUnknown {
        if AudioHardwareDestroyAggregateDevice(aggID) != noErr { err("warning: aggregate teardown failed") }
        aggID = AudioObjectID(kAudioObjectUnknown)
    }
    if tapID != kAudioObjectUnknown {
        if AudioHardwareDestroyProcessTap(tapID) != noErr { err("warning: tap teardown failed") }
        tapID = AudioObjectID(kAudioObjectUnknown)
    }
}

// Best-effort synchronous stream stop for abnormal exit paths; normal stops
// go through stopAndExit, which also drains the writer.
func teardownCapture() {
    stopAudioTap()
    if let stream = gStream {
        gStream = nil
        let stopped = DispatchSemaphore(value: 0)
        stream.stopCapture { _ in stopped.signal() }
        _ = stopped.wait(timeout: .now() + 3)
    }
}

// MARK: - ScreenCaptureKit video

final class VideoOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sb.imageBuffer != nil else { return }
        writeQueue.async {
            if !sessionStarted {
                writer.startSession(atSourceTime: sb.presentationTimeStamp)
                sessionStarted = true
            }
            if videoInput.isReadyForMoreMediaData, videoInput.append(sb) { videoFrames += 1 }
        }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        err("stream stopped: \(error.localizedDescription)")
        teardownCapture()
        exit(1)
    }
}

let videoOutput = VideoOutput()
var gStream: SCStream?
var gSignalSource: DispatchSourceSignal?

func stopAndExit(_ path: String) -> Never {
    if let stream = gStream {
        gStream = nil
        let stopped = DispatchSemaphore(value: 0)
        stream.stopCapture { _ in stopped.signal() }
        _ = stopped.wait(timeout: .now() + 3)
    }
    stopAudioTap()
    let finished = DispatchSemaphore(value: 0)
    writeQueue.sync {
        guard sessionStarted else {
            err("no frames captured"); exit(1)
        }
        if let input = audioInput {
            while let next = pendingAudio.first, input.isReadyForMoreMediaData {
                input.append(next)
                pendingAudio.removeFirst()
            }
        }
        videoInput.markAsFinished()
        audioInput?.markAsFinished()
        writer.finishWriting { finished.signal() }
    }
    _ = finished.wait(timeout: .now() + 10)
    if writer.status == .failed {
        err("write failed: \(writer.error?.localizedDescription ?? "unknown")")
        exit(1)
    }
    if meterOn { err("meter: \(videoFrames) video frames, \(audioBuffers) audio buffers, peak \(audioPeak)") }
    err("wrote \(path)")
    exit(0)
}

// MARK: - Main

Task {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        if listOnly {
            for (i, d) in content.displays.enumerated() {
                print("[\(i)] id \(d.displayID)  \(d.width)x\(d.height) points")
            }
            exit(0)
        }
        guard displayIndex < content.displays.count else {
            err("display \(displayIndex) not found (\(content.displays.count) available)")
            exit(1)
        }
        let display = content.displays[displayIndex]
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let cfg = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        cfg.width = Int(filter.contentRect.width * scale)
        cfg.height = Int(filter.contentRect.height * scale)
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        cfg.showsCursor = true
        cfg.capturesAudio = false  // dead on macOS 26 for CLI contexts; see header comment
        cfg.queueDepth = 8

        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let path = outPath ?? "sckrec-\(df.string(from: Date())).mov"
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: url)

        let audioOK = captureAudio ? startAudioTap() : false
        if captureAudio && !audioOK { err("continuing without audio") }

        writer = try AVAssetWriter(outputURL: url, fileType: path.hasSuffix(".mp4") ? .mp4 : .mov)
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: cfg.width,
            AVVideoHeightKey: cfg.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(bitrateMbps * 1_000_000),
                AVVideoExpectedSourceFrameRateKey: fps,
            ],
        ])
        videoInput.expectsMediaDataInRealTime = true
        writer.add(videoInput)
        if audioOK {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: audioASBD.mSampleRate,
                AVNumberOfChannelsKey: Int(audioASBD.mChannelsPerFrame),
                AVEncoderBitRateKey: 192_000,
            ])
            input.expectsMediaDataInRealTime = true
            writer.add(input)
            audioInput = input
        }
        guard writer.startWriting() else {
            err("writer failed: \(writer.error?.localizedDescription ?? "unknown")")
            exit(1)
        }

        let stream = SCStream(filter: filter, configuration: cfg, delegate: videoOutput)
        gStream = stream
        try stream.addStreamOutput(videoOutput, type: .screen, sampleHandlerQueue: DispatchQueue(label: "sckrec.video"))
        try await stream.startCapture()
        atexit { teardownCapture() }
        err("recording \(cfg.width)x\(cfg.height)@\(fps)\(audioOK ? " + system audio" : "") -> \(path)  (Ctrl+C to stop)")

        signal(SIGINT, SIG_IGN)
        let sig = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        sig.setEventHandler { stopAndExit(path) }
        sig.resume()
        gSignalSource = sig

        if let d = duration {
            try await Task.sleep(nanoseconds: UInt64(d * 1_000_000_000))
            stopAndExit(path)
        }
    } catch {
        err("error: \(error.localizedDescription)")
        err("if this is a permissions error: System Settings > Privacy & Security > Screen & System Audio Recording")
        teardownCapture()
        exit(1)
    }
}

// ScreenCaptureKit shows the system recording indicator (an AppKit status
// item) and requires a live main thread with an AppKit-capable run loop;
// dispatchMain() would exit the main thread and crash NSStatusItem creation.
_ = NSApplication.shared
RunLoop.main.run()
