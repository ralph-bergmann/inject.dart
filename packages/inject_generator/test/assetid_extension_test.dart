import 'package:build/build.dart';
import 'package:inject_generator/src/build/builder_utils.dart';
import 'package:test/test.dart';

void main() {
  group('AssetId replaceExtension tests', () {
    test('replaces extension at the end of path', () {
      final assetId = AssetId('package', 'lib/src/file.dart');
      final newAssetId = assetId.replaceExtension('.dart', '.g.dart');
      expect(newAssetId.path, equals('lib/src/file.g.dart'));
      expect(newAssetId.package, equals('package'));
    });

    test('handles compound extensions correctly', () {
      final assetId = AssetId('package', 'lib/src/file.inject_summary.json');
      final newAssetId = assetId.replaceExtension('.inject_summary.json', '.inject.dart');
      expect(newAssetId.path, equals('lib/src/file.inject.dart'));
    });

    test('returns original AssetId if extension not found', () {
      final assetId = AssetId('package', 'lib/src/file.dart');
      final newAssetId = assetId.replaceExtension('.txt', '.g.dart');
      expect(newAssetId, equals(assetId));
    });

    test('does not replace matching substring in middle of path', () {
      final assetId = AssetId('package', 'lib/src/dart/file.txt');
      final newAssetId = assetId.replaceExtension('.dart', '.g.dart');
      expect(newAssetId.path, equals('lib/src/dart/file.txt'));
    });

    test('handles extensions with special characters', () {
      final assetId = AssetId('package', 'lib/src/file.dart+json');
      final newAssetId = assetId.replaceExtension('.dart+json', '.processed');
      expect(newAssetId.path, equals('lib/src/file.processed'));
    });
  });
}
