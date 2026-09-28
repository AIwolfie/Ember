import 'package:flutter_test/flutter_test.dart';
import 'package:ember_flutter/theme.dart';
import 'package:ember_flutter/services/update_service.dart';

void main() {
  group('Theme Tests', () {
    test('EmberThemes contains all 5 handcrafted palettes', () {
      expect(EmberThemes.all.length, 5);
      final ids = EmberThemes.all.map((t) => t.id).toList();
      expect(
        ids,
        containsAll(['amber', 'emerald', 'amethyst', 'solar', 'rose']),
      );
    });

    test(
      'EmberThemes.fromId returns correct theme and falls back to amber',
      () {
        expect(EmberThemes.fromId('emerald').id, 'emerald');
        expect(EmberThemes.fromId('amethyst').id, 'amethyst');
        expect(EmberThemes.fromId('solar').id, 'solar');
        expect(EmberThemes.fromId('rose').id, 'rose');
        expect(EmberThemes.fromId('non_existent').id, 'amber');
        expect(EmberThemes.fromId(null).id, 'amber');
      },
    );
  });

  group('UpdateService Tests', () {
    test('UpdateService instance initializes without throwing', () {
      final service = UpdateService.instance;
      expect(service, isNotNull);
      // In a headless test environment, updater is not on device so isAvailable is false
      expect(service.isAvailable, isFalse);
    });
  });
}
