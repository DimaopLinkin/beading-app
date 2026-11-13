import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

/// Страница растра: RGB, 8 бит на канал, без прозрачности.
final class RasterPage {
  const RasterPage({
    required this.width,
    required this.height,
    required this.rgb,
    required this.widthMm,
    required this.heightMm,
  });

  final int width;
  final int height;

  /// Размер листа в PDF, миллиметры.
  final int widthMm;
  final int heightMm;
  final Uint8List rgb;
}

/// Собирает PDF, где каждая страница — одна картинка на весь лист. Растр сжимается Flate; шрифты и пакеты не нужны.
final class RasterPdfWriter {
  const RasterPdfWriter();

  static const double _ptPerMm = 72 / 25.4;

  Uint8List build(List<RasterPage> pages) {
    final BytesBuilder out = BytesBuilder(copy: false);
    final List<int> offsets = <int>[];
    int length = 0;

    void write(List<int> bytes) {
      out.add(bytes);
      length += bytes.length;
    }

    void text(String value) => write(latin1.encode(value));

    void startObject(int id) {
      offsets.add(length);
      text('$id 0 obj\n');
    }

    // Объекты: 1 — каталог, 2 — список страниц, затем для страницы i: страница, содержимое, картинка.
    text('%PDF-1.4\n');
    startObject(1);
    text('<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
    startObject(2);
    final String kids = <String>[for (int i = 0; i < pages.length; i++) '${3 + i * 3} 0 R'].join(' ');
    text('<< /Type /Pages /Kids [$kids] /Count ${pages.length} >>\nendobj\n');
    for (int i = 0; i < pages.length; i++) {
      final int page = 3 + i * 3;
      final double w = pages[i].widthMm * _ptPerMm;
      final double h = pages[i].heightMm * _ptPerMm;
      startObject(page);
      text(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${w.toStringAsFixed(2)} ${h.toStringAsFixed(2)}] '
        '/Resources << /XObject << /Im0 ${page + 2} 0 R >> >> /Contents ${page + 1} 0 R >>\nendobj\n',
      );
      final String content = 'q ${w.toStringAsFixed(2)} 0 0 ${h.toStringAsFixed(2)} 0 0 cm /Im0 Do Q';
      startObject(page + 1);
      text('<< /Length ${content.length} >>\nstream\n$content\nendstream\nendobj\n');
      final Uint8List packed = Uint8List.fromList(ZLibCodec().encode(pages[i].rgb));
      startObject(page + 2);
      text(
        '<< /Type /XObject /Subtype /Image /Width ${pages[i].width} /Height ${pages[i].height} '
        '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length ${packed.length} >>\nstream\n',
      );
      write(packed);
      text('\nendstream\nendobj\n');
    }
    final int xref = length;
    text('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
    for (final int offset in offsets) {
      text('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    text('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
    return out.takeBytes();
  }
}
