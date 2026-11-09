import 'package:equatable/equatable.dart';

/// Комплимент, который надо показать: текст уже с подставленным именем.
final class ShownCompliment extends Equatable {
  const ShownCompliment(this.text);

  final String text;

  @override
  List<Object?> get props => <Object?>[text];
}
