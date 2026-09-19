/// Single source of truth for the product identity: name, release channel and
/// the links the UI is allowed to show.
///
/// Only VoidrauVPN links live here. The tunnel *core* binary is treated as a
/// black box (it is launched through `AETHER_*` environment variables, which is
/// its own interface) — nothing in the UI advertises any other project.
class AppInfo {
  static const appName = 'VoidrauVPN';

  /// Injected by the release workflow (`--dart-define=VOIDRAU_VERSION=...`).
  static const version =
      String.fromEnvironment('VOIDRAU_VERSION', defaultValue: '1.0.0');

  /// Version of the bundled tunnel core.
  static const core = '2.0.0';

  static const socksHost = '127.0.0.1';
  static const socksPort = 1819;

  /// Release repository: the in-app updater reads GitHub Releases from here and
  /// the About page links to it.
  static const owner = 'AnishtayiN';
  static const repo = 'VoidrauVPN';
  static const repoUrl = 'https://github.com/AnishtayiN/VoidrauVPN';
  static const releasesUrl = 'https://github.com/AnishtayiN/VoidrauVPN/releases';

  /// Official channel — install instructions and release notes are posted here.
  static const telegramHandle = '@Voidrau';
  static const telegramUrl = 'https://t.me/Voidrau';
}
