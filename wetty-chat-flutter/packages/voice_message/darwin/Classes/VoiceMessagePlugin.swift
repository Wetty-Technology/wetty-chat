#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

/// Flutter plugin exposing OGG/Opus transcoding and waveform extraction.
public class VoiceMessagePlugin: NSObject, FlutterPlugin {
    private static let backgroundQueue = DispatchQueue(
        label: "app.chahua.chat.voice_message",
        qos: .userInitiated
    )

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        #else
        let messenger = registrar.messenger
        #endif
        let channel = FlutterMethodChannel(
            name: "voice_message",
            binaryMessenger: messenger
        )
        let instance = VoiceMessagePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "convertOggToM4a":
            handleConvertOggToM4a(call: call, result: result)
        case "convertM4aToOgg":
            handleConvertM4aToOgg(call: call, result: result)
        case "extractWaveform":
            handleExtractWaveform(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Convert OGG → M4A

    private func handleConvertOggToM4a(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let srcPath = args["srcPath"] as? String,
              let destPath = args["destPath"] as? String
        else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "srcPath and destPath required", details: nil))
            return
        }
        Self.backgroundQueue.async {
            do {
                try OGGConverter.convertOpusOGGToM4aFile(
                    src: URL(fileURLWithPath: srcPath),
                    dest: URL(fileURLWithPath: destPath)
                )
                DispatchQueue.main.async { result(nil) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "CONVERSION_FAILED",
                        message: "OGG to M4A conversion failed: \(error.localizedDescription)",
                        details: "\(error)"
                    ))
                }
            }
        }
    }

    // MARK: - Convert M4A → OGG

    private func handleConvertM4aToOgg(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let srcPath = args["srcPath"] as? String,
              let destPath = args["destPath"] as? String
        else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "srcPath and destPath required", details: nil))
            return
        }
        Self.backgroundQueue.async {
            do {
                try OGGConverter.convertM4aFileToOpusOGG(
                    src: URL(fileURLWithPath: srcPath),
                    dest: URL(fileURLWithPath: destPath)
                )
                DispatchQueue.main.async { result(nil) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "CONVERSION_FAILED",
                        message: "M4A to OGG conversion failed: \(error.localizedDescription)",
                        details: "\(error)"
                    ))
                }
            }
        }
    }

    // MARK: - Extract Waveform

    private func handleExtractWaveform(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String,
              let samplesCount = args["samplesCount"] as? Int
        else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "path and samplesCount required", details: nil))
            return
        }
        Self.backgroundQueue.async {
            do {
                let waveform = try WaveformExtractor.extract(
                    path: path,
                    samplesCount: samplesCount
                )
                DispatchQueue.main.async { result(waveform) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "WAVEFORM_FAILED",
                        message: "Waveform extraction failed: \(error.localizedDescription)",
                        details: "\(error)"
                    ))
                }
            }
        }
    }
}
