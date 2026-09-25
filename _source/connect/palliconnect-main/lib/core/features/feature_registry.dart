import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/session_provider.dart';

final featureRegistryProvider = Provider((ref) {
  final school = ref.watch(currentSchoolProvider);
  return FeatureRegistry(school?.enabledFeatures ?? []);
});

class FeatureRegistry {
  final List<String> _enabledFeatures;

  FeatureRegistry(this._enabledFeatures);

  bool isEnabled(String featureKey) {
    if (featureKey == 'today' || featureKey == 'child_switcher' || featureKey == 'messages') return true;
    if (featureKey == 'digital_diary') {
      return _enabledFeatures.contains('diary') || _enabledFeatures.contains('digital_diary');
    }
    return _enabledFeatures.contains(featureKey);
  }
}
