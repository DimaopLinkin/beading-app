/// Группа отделок бисера для выбора в мастере (T62): внутри группы цвета сочетаются друг с другом, между группами
/// бусины заметно различаются блеском и прозрачностью.
///
/// Значения отделок совпадают с `finish` в `assets/catalog/*.json` и не пересекаются между группами.
enum BeadFinishGroup {
  /// Непрозрачный и матовый: ровный цвет без блика, лучше всего собирает картину.
  solid(<String>{'opaque', 'matte'}),

  /// Блестящий: глянцевый, церейский, гальванический, металлик, радужный.
  luster(<String>{'luster', 'ceylon', 'galvanized', 'metallic', 'rainbow'}),

  /// Прозрачный и с линией: прозрачный, прокрашенный изнутри, с серебряной или золотой линией.
  transparent(<String>{'transparent', 'inside_dyed', 'silver_lined', 'gold_lined'})
  ;

  const BeadFinishGroup(this.finishes);

  final Set<String> finishes;

  /// Все отделки выбранных групп.
  static Set<String> finishesOf(Iterable<BeadFinishGroup> groups) => <String>{
    for (final BeadFinishGroup group in groups) ...group.finishes,
  };
}
