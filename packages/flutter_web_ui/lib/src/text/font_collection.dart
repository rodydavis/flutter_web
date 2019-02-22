import 'dart:typed_data';
import 'dart:convert' show json, utf8;
import 'dart:html' as html show FontFace, document, window;
import '../assets/assets.dart';

const _testFontFamily = 'Ahem';
const _testFontUrl = '/packages/flutter_web/assets/Ahem.ttf';

/// This class is responsible for registering and loading fonts.
///
/// Once an asset manager has been set in the framework, call
/// [registerFonts] with it to register fonts declared in the
/// font manifest. If test fonts are enabled, then call
/// [registerTestFonts] as well.
class FontCollection {
  _FontManager _assetFontManager;
  _FontManager _testFontManager;

  /// Reads the font manifest using the [assetManager] and registers all of the
  /// fonts declared within.
  Future<void> registerFonts(AssetManager assetManager) async {
    ByteData byteData;

    try {
      byteData = await assetManager.load('FontManifest.json');
    } on AssetManagerException catch (e) {
      if (e.httpStatus == 404) {
        html.window.console
            .warn('Font manifest does not exist at `${e.url}` – ignoring.');
        return;
      } else {
        rethrow;
      }
    }

    if (byteData == null) {
      throw new AssertionError(
          'There was a problem trying to load FontManifest.json');
    }

    final List fontManifest =
        json.decode(utf8.decode(byteData.buffer.asUint8List()));
    if (fontManifest == null) {
      throw new AssertionError(
          'There was a problem trying to load FontManifest.json');
    }

    _assetFontManager = _FontManager();

    for (Map<String, dynamic> fontFamily in fontManifest) {
      final String family = fontFamily['family'];
      final List fontAssets = fontFamily['fonts'];

      for (Map<String, dynamic> fontAsset in fontAssets) {
        final String asset = fontAsset['asset'];
        final descriptors = <String, String>{};
        for (var descriptor in fontAsset.keys) {
          if (descriptor != 'asset') {
            descriptors[descriptor] = '${fontAsset[descriptor]}';
          }
        }
        _assetFontManager.registerAsset(
            family, 'url(${assetManager.getAssetUrl(asset)})', descriptors);
      }
    }
  }

  /// Registers fonts that are used by tests.
  void debugRegisterTestFonts() {
    _testFontManager = _DebugTestFontManager(_testFontFamily);
    _testFontManager.registerAsset(
        _testFontFamily, 'url($_testFontUrl)', const <String, String>{});
  }

  /// Returns a [Future] that completes when the registered fonts are loaded
  /// and ready to be used.
  Future<void> ensureFontsLoaded() async {
    await _assetFontManager?.ensureFontsLoaded();
    await _testFontManager?.ensureFontsLoaded();
  }

  /// Unregister all fonts that have been registered.
  void clear() {
    _assetFontManager = null;
    _testFontManager = null;
    html.document.fonts.clear();
  }
}

/// Manages a collection of fonts and ensures they are loaded.
class _FontManager {
  final _registeredFamilies = <String, List<html.FontFace>>{};
  final _fontLoadingFutures = <Future<void>>[];

  void registerAsset(
    String family,
    String asset,
    Map<String, String> descriptors,
  ) {
    final fontFace = html.FontFace(family, asset, descriptors);
    _registeredFamilies
        .putIfAbsent(family, () => <html.FontFace>[])
        .add(fontFace);
    _fontLoadingFutures
        .add(fontFace.load().then((_) => html.document.fonts.add(fontFace)));
  }

  /// Returns a set of [FontFace]s that match the given [family].
  ///
  /// These fonts are not guaranteed to be loaded yet. To ensure they have
  /// been, call [ensureFontsLoaded].
  List<html.FontFace> fontsForFamily(String family) {
    return _registeredFamilies[family];
  }

  /// Returns a [Future] that completes when all fonts that have been
  /// registered with this font manager have been loaded and are ready to use.
  Future<void> ensureFontsLoaded() {
    return Future.wait(_fontLoadingFutures);
  }
}

class _DebugTestFontManager extends _FontManager {
  final String _debugTestFontFamily;

  _DebugTestFontManager(this._debugTestFontFamily);

  @override
  List<html.FontFace> fontsForFamily(String family) =>
      super.fontsForFamily(_debugTestFontFamily);
}
