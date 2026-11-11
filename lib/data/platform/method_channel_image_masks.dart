import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_masks.dart';
import 'package:flutter/services.dart';

/// Маски и лица от Apple Vision через платформенный канал `app.beading/image_masks`.
///
/// Dart → платформа: `analyze` с `image` (байты), `width`, `height`. Ответ — словарь с необязательными ключами
/// `subject`, `person`, `saliency` (байты `width × height`) и `faces` (рамка и ориентиры в долях картинки).
/// Нативная часть: `native/darwin/ImageMasksChannel.swift`, общая для iOS и macOS.
///
/// Без нативной части (тесты, Linux) и при любой ошибке платформы возвращается [Err]: мастер тогда работает без масок.
class MethodChannelImageMasks implements ImageMasks {
  MethodChannelImageMasks({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(name);

  static const String name = 'app.beading/image_masks';
  static const String analyzeMethod = 'analyze';

  final MethodChannel _channel;

  @override
  Future<Result<ImageMaskSet>> analyze(Uint8List image, {required int width, required int height}) async {
    try {
      final Map<Object?, Object?>? reply = await _channel.invokeMapMethod<Object?, Object?>(
        analyzeMethod,
        <String, Object?>{'image': image, 'width': width, 'height': height},
      );
      if (reply == null) {
        return Success<ImageMaskSet>(ImageMaskSet.empty(width: width, height: height));
      }
      return Success<ImageMaskSet>(_parse(reply, width, height));
    } on MissingPluginException {
      return const Err<ImageMaskSet>(UnexpectedFailure('image masks: платформа без Vision'));
    } on PlatformException catch (e) {
      return Err<ImageMaskSet>(UnexpectedFailure('image masks: ${e.code}'));
    } on Object catch (e) {
      // Ответ не того вида: маски — улучшение, а не необходимость.
      return Err<ImageMaskSet>(UnexpectedFailure('image masks: $e'));
    }
  }

  ImageMaskSet _parse(Map<Object?, Object?> reply, int width, int height) {
    Uint8List? mask(String key) {
      final Object? value = reply[key];
      // Размер не тот: платформа обязана вернуть ровно width × height, иначе маска бесполезна.
      return value is Uint8List && value.length == width * height ? value : null;
    }

    final Object? rawFaces = reply['faces'];
    final List<DetectedFace> faces = <DetectedFace>[
      if (rawFaces is List<Object?>)
        for (final Object? raw in rawFaces)
          if (raw is Map<Object?, Object?>) ?_parseFace(raw),
    ];
    return ImageMaskSet(
      width: width,
      height: height,
      subject: mask('subject'),
      person: mask('person'),
      saliency: mask('saliency'),
      faces: faces,
    );
  }

  DetectedFace? _parseFace(Map<Object?, Object?> raw) {
    final Object? bounds = raw['bounds'];
    if (bounds is! List<Object?> || bounds.length != 4 || bounds.any((v) => v is! num)) {
      return null;
    }
    final List<double> b = <double>[for (final Object? v in bounds) (v! as num).toDouble()];
    final Object? rawLandmarks = raw['landmarks'];
    final Map<Object?, Object?> landmarks = rawLandmarks is Map<Object?, Object?>
        ? rawLandmarks
        : const <Object?, Object?>{};
    List<NormalizedPoint> points(String key) {
      final Object? flat = landmarks[key];
      if (flat is! List<Object?>) {
        return const <NormalizedPoint>[];
      }
      final List<NormalizedPoint> result = <NormalizedPoint>[];
      for (int i = 0; i + 1 < flat.length; i += 2) {
        final Object? x = flat[i];
        final Object? y = flat[i + 1];
        if (x is num && y is num) {
          result.add(NormalizedPoint(x.toDouble(), y.toDouble()));
        }
      }
      return result;
    }

    return DetectedFace(
      bounds: NormalizedRect(left: b[0], top: b[1], right: b[2], bottom: b[3]),
      landmarks: FaceLandmarks(
        leftEye: points('leftEye'),
        rightEye: points('rightEye'),
        leftPupil: points('leftPupil'),
        rightPupil: points('rightPupil'),
        leftEyebrow: points('leftEyebrow'),
        rightEyebrow: points('rightEyebrow'),
        nose: points('nose'),
        outerLips: points('outerLips'),
        innerLips: points('innerLips'),
      ),
    );
  }
}
