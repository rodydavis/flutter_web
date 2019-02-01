import 'layer_tree.dart';
import 'platform_message.dart';
import 'font_collection.dart';

abstract class RuntimeDelegate {
  String get defaultRouteName;
  void scheduleFrame({bool regenerateLayerTree: true});
  void render(LayerTree layerTree);
  void handlePlatformMessage(PlatformMessage message);
  FontCollection getFontCollection();
}
