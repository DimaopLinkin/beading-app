import 'dart:typed_data';

/// Размытие прямоугольным окном радиуса [radius] пикселей (край картинки — окно обрезается), за O(w·h) независимо от
/// радиуса: бегущие суммы по строкам, затем по столбцам.
Float32List boxBlur(Float32List data, int width, int height, int radius) {
  final Float32List tmp = Float32List(width * height);
  final Float32List out = Float32List(width * height);
  final Float64List sums = Float64List((width > height ? width : height) + 1);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      sums[x + 1] = sums[x] + data[y * width + x];
    }
    for (int x = 0; x < width; x++) {
      final int from = x - radius < 0 ? 0 : x - radius;
      final int to = x + radius >= width ? width - 1 : x + radius;
      tmp[y * width + x] = (sums[to + 1] - sums[from]) / (to - from + 1);
    }
  }
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      sums[y + 1] = sums[y] + tmp[y * width + x];
    }
    for (int y = 0; y < height; y++) {
      final int from = y - radius < 0 ? 0 : y - radius;
      final int to = y + radius >= height ? height - 1 : y + radius;
      out[y * width + x] = (sums[to + 1] - sums[from]) / (to - from + 1);
    }
  }
  return out;
}
