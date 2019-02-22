import 'assets/assets.dart';
import 'text/font_collection.dart';
import 'dom_renderer.dart';

/// Initializes the platform.
Future<void> webOnlyInitializePlatform({AssetManager assetManager}) async {
  if (assetManager == null) {
    assetManager = new AssetManager();
  }
  await webOnlySetAssetManager(assetManager);
  await _fontCollection.ensureFontsLoaded();
}

AssetManager _assetManager;
FontCollection _fontCollection;

/// Specifies that the platform should use the given [AssetManager] to load
/// assets.
///
/// The given asset manager is used to initialize the font collection.
Future<void> webOnlySetAssetManager(AssetManager assetManager) async {
  assert(assetManager != null, 'Cannot set assetManager to null');
  if (assetManager == _assetManager) return;

  _assetManager = assetManager;

  _fontCollection ??= FontCollection();
  _fontCollection.clear();
  if (_assetManager != null) {
    await _fontCollection.registerFonts(_assetManager);
  }

  if (domRenderer.debugIsInWidgetTest) {
    _fontCollection.debugRegisterTestFonts();
  }
}

/// This class handles downloading assets over the network.
AssetManager get webOnlyAssetManager => _assetManager;

/// A collection of fonts that may be used by the platform.
FontCollection get webOnlyFontCollection => _fontCollection;
