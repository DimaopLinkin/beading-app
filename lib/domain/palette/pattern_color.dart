import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:equatable/equatable.dart';

/// Одна нитка смешанной нити: позиция каталога и её цвет.
final class BlendPart extends Equatable {
  const BlendPart({required this.ref, required this.rgb});

  final CatalogRef ref;
  final Rgb rgb;

  @override
  List<Object?> get props => <Object?>[ref, rgb];
}

/// Цвет схемы: снимок, не ссылка на каталог — правка каталога не меняет старые схемы.
///
/// [components] — одна позиция каталога (бусина, обычная нить) или две (смешанная нить мулине).
/// [finish] — отделка бисера или признак спецнити; на вид схемы не влияет. [symbol] — знак для режима символов.
final class PatternColor extends Equatable {
  PatternColor({
    required this.rgb,
    required this.name,
    required List<CatalogRef> components,
    this.finish,
    this.symbol,
  }) : components = List<CatalogRef>.unmodifiable(components) {
    if (components.isEmpty || components.length > maxComponents) {
      throw ArgumentError.value(components, 'components', 'нужно 1–$maxComponents позиции каталога');
    }
  }

  /// Смешанная нить: RGB — среднее частей в линейном RGB.
  factory PatternColor.blend({
    required String name,
    required List<BlendPart> parts,
    String? finish,
    String? symbol,
  }) => PatternColor(
    rgb: Rgb.average(parts.map((p) => p.rgb).toList()),
    name: name,
    components: parts.map((p) => p.ref).toList(),
    finish: finish,
    symbol: symbol,
  );

  static const int maxComponents = 2;

  final Rgb rgb;
  final String name;
  final List<CatalogRef> components;
  final String? finish;
  final String? symbol;

  PatternColor copyWith({Rgb? rgb, String? name, List<CatalogRef>? components, String? finish, String? symbol}) =>
      PatternColor(
        rgb: rgb ?? this.rgb,
        name: name ?? this.name,
        components: components ?? this.components,
        finish: finish ?? this.finish,
        symbol: symbol ?? this.symbol,
      );

  @override
  List<Object?> get props => <Object?>[rgb, name, components, finish, symbol];
}
