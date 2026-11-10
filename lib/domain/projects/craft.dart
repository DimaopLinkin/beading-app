/// Ремесло проекта ([ADR-0003](../../../docs/decisions/0003-crafts-in-domain.md)).
enum Craft {
  beading,
  crossStitch
  ;

  /// Допустимые техники этого ремесла.
  List<Technique> get techniques => Technique.values.where((t) => t.craft == this).toList(growable: false);
}

/// Техника исполнения. Каждая относится ровно к одному ремеслу.
enum Technique {
  loom(Craft.beading),
  peyote(Craft.beading),
  brick(Craft.beading),
  square(Craft.beading),
  offLoom(Craft.beading),
  crossStitch(Craft.crossStitch),
  tent(Craft.crossStitch)
  ;

  const Technique(this.craft);

  final Craft craft;

  /// Первая по списку техника ремесла: что выбрать, если пользователь ничего не указал.
  static Technique defaultFor(Craft craft) => craft.techniques.first;
}
