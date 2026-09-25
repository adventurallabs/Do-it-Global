import 'package:flutter_test/flutter_test.dart';

import 'package:feature_bus_tracking/feature_bus_tracking.dart';

void main() {
  test('exports the bus tracking screen', () {
    expect(BusTrackingScreen.new, isNotNull);
  });
}
