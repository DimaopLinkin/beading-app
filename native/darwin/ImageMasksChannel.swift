import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Vision

#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif

/// Маски и лица на фото через Apple Vision (T48). Один файл на iOS и macOS: в обоих проектах Xcode он подключён
/// как `native/darwin/ImageMasksChannel.swift`.
///
/// Канал `app.beading/image_masks`. Dart → платформа: `analyze` с аргументами
/// `image` (байты PNG или JPEG), `width`, `height` (размер масок на выходе).
/// Ответ — словарь; любой ключ может отсутствовать, если запрос не удался или ничего не нашёл:
/// - `subject`, `person`, `saliency`: байты `width × height`, ряды сверху вниз (0 — нет, до 255);
/// - `faces`: список словарей `bounds` (`[left, top, right, bottom]` в долях картинки, y сверху вниз) и
///   `landmarks` (имя ориентира → плоский список `[x0, y0, x1, y1, …]` в тех же долях).
/// Все запросы работают на устройстве, без сети. Маски объекта не работают в симуляторе («Could not create
/// inference context»): запрос тогда просто пропускается, остальные идут как обычно.
final class ImageMasksChannel {
  static let name = "app.beading/image_masks"

  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "analyze" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
        let image = args["image"] as? FlutterStandardTypedData,
        let width = args["width"] as? Int,
        let height = args["height"] as? Int,
        width > 0, height > 0
      else {
        result(FlutterError(code: "bad_arguments", message: "image, width and height are required", details: nil))
        return
      }
      // Vision тяжёлый: считаем вне главного потока.
      DispatchQueue.global(qos: .userInitiated).async {
        let reply = ImageMasksAnalyzer.analyze(data: image.data, width: width, height: height)
        DispatchQueue.main.async {
          switch reply {
          case .success(let map): result(map)
          case .failure(let error): result(FlutterError(code: "analysis_failed", message: error.message, details: nil))
          }
        }
      }
    }
  }
}

struct ImageMasksError: Error {
  let message: String
}

enum ImageMasksAnalyzer {
  static func analyze(data: Data, width: Int, height: Int) -> Result<[String: Any], ImageMasksError> {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
      return .failure(ImageMasksError(message: "image cannot be decoded"))
    }
    let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
    var reply: [String: Any] = [:]

    if let subject = subjectMask(handler: handler, width: width, height: height) {
      reply["subject"] = FlutterStandardTypedData(bytes: subject)
    }
    if let person = personMask(handler: handler, width: width, height: height) {
      reply["person"] = FlutterStandardTypedData(bytes: person)
    }
    let faces = detectFaces(handler: handler)
    if !faces.isEmpty {
      reply["faces"] = faces
    }
    // Значимость нужна, когда нет ни лиц, ни объекта; иначе лишний запрос не делаем.
    if faces.isEmpty && reply["subject"] == nil && reply["person"] == nil,
      let saliency = saliencyMask(handler: handler, width: width, height: height)
    {
      reply["saliency"] = FlutterStandardTypedData(bytes: saliency)
    }
    return .success(reply)
  }

  // MARK: Объект

  private static func subjectMask(handler: VNImageRequestHandler, width: Int, height: Int) -> Data? {
    let request = VNGenerateForegroundInstanceMaskRequest()
    do {
      try handler.perform([request])
      guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
      let buffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
      return resample(buffer, width: width, height: height, normalize: false)
    } catch {
      // В симуляторе и на старом железе запрос недоступен: работаем без маски объекта.
      return nil
    }
  }

  // MARK: Человек (запасной вариант для портретов)

  private static func personMask(handler: VNImageRequestHandler, width: Int, height: Int) -> Data? {
    let request = VNGeneratePersonSegmentationRequest()
    request.qualityLevel = .balanced
    request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    do {
      try handler.perform([request])
      guard let buffer = request.results?.first?.pixelBuffer else { return nil }
      let mask = resample(buffer, width: width, height: height, normalize: false)
      // Пустая маска (на фото нет людей) не нужна.
      return mask?.contains(where: { $0 != 0 }) == true ? mask : nil
    } catch {
      return nil
    }
  }

  // MARK: Лица

  private static func detectFaces(handler: VNImageRequestHandler) -> [[String: Any]] {
    let request = VNDetectFaceLandmarksRequest()
    do {
      try handler.perform([request])
    } catch {
      return []
    }
    return (request.results ?? []).map { face in
      let box = face.boundingBox  // доли картинки, начало внизу слева
      var landmarks: [String: [Double]] = [:]
      if let found = face.landmarks {
        func points(_ region: VNFaceLandmarkRegion2D?) -> [Double] {
          guard let region else { return [] }
          var flat: [Double] = []
          for point in region.normalizedPoints {
            // Точки заданы в долях рамки лица, начало внизу слева.
            flat.append(Double(box.minX + point.x * box.width))
            flat.append(Double(1 - (box.minY + point.y * box.height)))
          }
          return flat
        }
        let eyes = (points(found.leftEye), points(found.rightEye))
        let pupils = (points(found.leftPupil), points(found.rightPupil))
        let brows = (points(found.leftEyebrow), points(found.rightEyebrow))
        // В словаре «левый» — левее на снимке, а Vision называет стороны по лицу: ставим по положению глаз.
        let swapped = !eyes.0.isEmpty && !eyes.1.isEmpty && mean(x: eyes.0) > mean(x: eyes.1)
        landmarks["leftEye"] = swapped ? eyes.1 : eyes.0
        landmarks["rightEye"] = swapped ? eyes.0 : eyes.1
        landmarks["leftPupil"] = swapped ? pupils.1 : pupils.0
        landmarks["rightPupil"] = swapped ? pupils.0 : pupils.1
        landmarks["leftEyebrow"] = swapped ? brows.1 : brows.0
        landmarks["rightEyebrow"] = swapped ? brows.0 : brows.1
        landmarks["nose"] = points(found.nose)
        landmarks["outerLips"] = points(found.outerLips)
        landmarks["innerLips"] = points(found.innerLips)
      }
      return [
        "bounds": [
          Double(box.minX), Double(1 - box.maxY), Double(box.maxX), Double(1 - box.minY),
        ],
        "landmarks": landmarks,
      ]
    }
  }

  private static func mean(x flat: [Double]) -> Double {
    var sum = 0.0
    var count = 0.0
    for index in stride(from: 0, to: flat.count - 1, by: 2) {
      sum += flat[index]
      count += 1
    }
    return count == 0 ? 0 : sum / count
  }

  // MARK: Значимость

  private static func saliencyMask(handler: VNImageRequestHandler, width: Int, height: Int) -> Data? {
    let request = VNGenerateAttentionBasedSaliencyImageRequest()
    do {
      try handler.perform([request])
      guard let buffer = request.results?.first?.pixelBuffer else { return nil }
      return resample(buffer, width: width, height: height, normalize: true)
    } catch {
      return nil
    }
  }

  // MARK: Приведение буфера к width × height байт

  /// Билинейно растягивает одноканальный буфер (8 бит или Float32) до `width × height` байт.
  /// [normalize] растягивает значения на весь диапазон 0…255 (значимость приходит в узком диапазоне).
  private static func resample(_ buffer: CVPixelBuffer, width: Int, height: Int, normalize: Bool) -> Data? {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
    let srcWidth = CVPixelBufferGetWidth(buffer)
    let srcHeight = CVPixelBufferGetHeight(buffer)
    let stride = CVPixelBufferGetBytesPerRow(buffer)
    let format = CVPixelBufferGetPixelFormatType(buffer)
    guard srcWidth > 0, srcHeight > 0 else { return nil }

    func value(_ x: Int, _ y: Int) -> Float {
      let row = base.advanced(by: y * stride)
      switch format {
      case kCVPixelFormatType_OneComponent8:
        return Float(row.load(fromByteOffset: x, as: UInt8.self)) / 255
      default:  // kCVPixelFormatType_OneComponent32Float
        return row.load(fromByteOffset: x * 4, as: Float.self)
      }
    }
    guard format == kCVPixelFormatType_OneComponent8 || format == kCVPixelFormatType_OneComponent32Float else {
      return nil
    }

    var low: Float = 0
    var high: Float = 1
    if normalize {
      low = Float.greatestFiniteMagnitude
      high = -Float.greatestFiniteMagnitude
      for y in 0..<srcHeight {
        for x in 0..<srcWidth {
          let v = value(x, y)
          low = min(low, v)
          high = max(high, v)
        }
      }
      if high - low < 1e-6 { return nil }
    }
    let scale = 1 / (high - low)

    var out = Data(count: width * height)
    out.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
      for y in 0..<height {
        let fy = max(0, min(Float(srcHeight - 1), (Float(y) + 0.5) * Float(srcHeight) / Float(height) - 0.5))
        let y0 = Int(fy)
        let y1 = min(srcHeight - 1, y0 + 1)
        let ty = fy - Float(y0)
        for x in 0..<width {
          let fx = max(0, min(Float(srcWidth - 1), (Float(x) + 0.5) * Float(srcWidth) / Float(width) - 0.5))
          let x0 = Int(fx)
          let x1 = min(srcWidth - 1, x0 + 1)
          let tx = fx - Float(x0)
          let top = value(x0, y0) * (1 - tx) + value(x1, y0) * tx
          let bottom = value(x0, y1) * (1 - tx) + value(x1, y1) * tx
          let v = (top * (1 - ty) + bottom * ty - low) * scale
          bytes[y * width + x] = UInt8(max(0, min(255, (v * 255).rounded())))
        }
      }
    }
    return out
  }
}
