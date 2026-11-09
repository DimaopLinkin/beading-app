import 'package:beading/core/clock.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/settings/secret_tap_detector.dart';
import 'package:beading/domain/settings/secret_tap_handler.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// «О приложении»: логотип, версия, тёплая подпись.
///
/// Семь быстрых нажатий по логотипу сообщают [secretTapHandler] о секрете; долгое нажатие на версию открывает
/// скрытый раздел ([onOpenHidden]).
class AboutScreen extends StatefulWidget {
  const AboutScreen({
    required this.appInfoProvider,
    required this.clock,
    required this.secretTapHandler,
    required this.onOpenHidden,
    super.key,
  });

  final AppInfoProvider appInfoProvider;
  final Clock clock;
  final SecretTapHandler secretTapHandler;
  final VoidCallback onOpenHidden;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  // Создаём один раз: при пересборке (смена темы) серия нажатий и загрузка версии не сбрасываются.
  late final Future<AppInfo> _appInfo = widget.appInfoProvider.load();
  late final SecretTapDetector _detector = SecretTapDetector(clock: widget.clock);

  void _onLogoTap() {
    if (_detector.register()) widget.secretTapHandler.onSecretTapped();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.aboutTitle)),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                GestureDetector(
                  key: const ValueKey<String>('about-logo'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _onLogoTap,
                  child: ExcludeSemantics(child: _Logo(color: tokens.accent.resolveFrom(context))),
                ),
                SizedBox(height: tokens.spacing.l),
                Text(l10n.appTitle, style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle),
                SizedBox(height: tokens.spacing.s),
                Semantics(
                  onLongPress: widget.onOpenHidden,
                  child: GestureDetector(
                    key: const ValueKey<String>('about-version'),
                    behavior: HitTestBehavior.opaque,
                    onLongPress: widget.onOpenHidden,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: tokens.minTapTarget, minWidth: tokens.minTapTarget),
                      child: Center(
                        child: FutureBuilder<AppInfo>(
                          future: _appInfo,
                          builder: (context, snapshot) => Text(
                            snapshot.hasData ? l10n.aboutVersion(snapshot.requireData.display) : '',
                            style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacing.xl),
                Text(l10n.aboutTagline, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Временный логотип: круг акцентного цвета с бусинкой. Настоящий придёт с дизайном (T01b).
class _Logo extends StatelessWidget {
  const _Logo({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 96,
    height: 96,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    alignment: Alignment.center,
    child: Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: CupertinoColors.white),
    ),
  );
}
