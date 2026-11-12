import 'package:flutter/cupertino.dart';

/// Сгруппированный список в духе iOS (inset grouped) без собственного фона секции.
///
/// У [CupertinoListSection.insetGrouped] фон секции по умолчанию `systemGroupedBackground`: он холоднее
/// фона экрана приложения и проступает в скруглённых углах. Прозрачный фон оставляет там цвет экрана.
class AppListSection extends StatelessWidget {
  const AppListSection({required this.children, this.header, this.footer, this.margin, super.key});

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => CupertinoListSection.insetGrouped(
    header: header,
    footer: footer,
    margin: margin ?? EdgeInsetsDirectional.fromSTEB(20, header == null ? 20 : 0, 20, 10),
    backgroundColor: CupertinoColors.transparent,
    children: children,
  );
}
