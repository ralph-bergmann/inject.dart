import 'package:inject_generator/src/codegen/naming.dart';
import 'package:test/test.dart';

import '../helpers/pipeline_golden_helper.dart';

const _goldenDir = 'test/golden/factory_generator';

void main() {
  group('FactoryGenerator', () {
    test(
      'simple_factory golden',
      () => runPipelineGolden(
        fixtureName: 'simple_factory',
        goldenDir: _goldenDir,
      ),
    );

    test(
      'multiple_assisted_params golden',
      () => runPipelineGolden(
        fixtureName: 'multiple_assisted_params',
        goldenDir: _goldenDir,
      ),
    );

    test(
      'no_injected_deps golden',
      () => runPipelineGolden(
        fixtureName: 'no_injected_deps',
        goldenDir: _goldenDir,
      ),
    );

    test(
      'multiple_injected_deps golden',
      () => runPipelineGolden(
        fixtureName: 'multiple_injected_deps',
        goldenDir: _goldenDir,
      ),
    );

    test(
      'named_constructor golden',
      () => runPipelineGolden(
        fixtureName: 'named_constructor',
        goldenDir: _goldenDir,
      ),
    );

    test(
      'multi_qualifier_factory golden',
      () => runPipelineGolden(
        fixtureName: 'multi_qualifier_factory',
        goldenDir: _goldenDir,
      ),
    );

    test(
      'synthesized_simple golden',
      () => runPipelineGolden(
        fixtureName: 'synthesized_simple',
        goldenDir: _goldenDir,
        expectFactory: true,
      ),
    );

    test(
      'synthesized_multiple_assisted golden',
      () => runPipelineGolden(
        fixtureName: 'synthesized_multiple_assisted',
        goldenDir: _goldenDir,
        expectFactory: true,
      ),
    );

    test(
      'synthesized_no_injected_deps golden',
      () => runPipelineGolden(
        fixtureName: 'synthesized_no_injected_deps',
        goldenDir: _goldenDir,
        expectFactory: true,
      ),
    );

    test(
      'synthesized_named_constructor golden',
      () => runPipelineGolden(
        fixtureName: 'synthesized_named_constructor',
        goldenDir: _goldenDir,
        expectFactory: true,
      ),
    );

    test(
      'synthesized_optional_positional golden',
      () => runPipelineGolden(
        fixtureName: 'synthesized_optional_positional',
        goldenDir: _goldenDir,
        expectFactory: true,
      ),
    );

    test(
      'synthesized_multi_constructor golden',
      () => runPipelineGolden(
        fixtureName: 'synthesized_multi_constructor',
        goldenDir: _goldenDir,
        expectFactory: true,
      ),
    );

    test(
      'synthesized_multi_distinct_deps golden',
      () => runPipelineGolden(
        fixtureName: 'synthesized_multi_distinct_deps',
        goldenDir: _goldenDir,
        expectFactory: true,
      ),
    );

    test(
      'synthesized_multi_named_only golden',
      () => runPipelineGolden(
        fixtureName: 'synthesized_multi_named_only',
        goldenDir: _goldenDir,
        expectFactory: true,
      ),
    );

    test(
      'synthesized_default_plus_named golden',
      () => runPipelineGolden(
        fixtureName: 'synthesized_default_plus_named',
        goldenDir: _goldenDir,
        expectFactory: true,
      ),
    );

    test(
      'synthesized_partial_explicit golden',
      () => runPipelineGolden(
        fixtureName: 'synthesized_partial_explicit',
        goldenDir: _goldenDir,
        expectFactory: true,
      ),
    );
  });

  group('synthesizedFactoryClassName', () {
    test('single-ctor (null qualifier) → no suffix', () {
      expect(synthesizedFactoryClassName('CoffeeMaker', null), 'CoffeeMakerFactory');
    });

    test('qualifier #standard → Standard suffix', () {
      expect(
        synthesizedFactoryClassName('CoffeeMaker', 'standard'),
        'CoffeeMakerStandardFactory',
      );
    });

    test('qualifier #brand_name (snake_case) → Brand_name suffix (capitalize-only)', () {
      expect(
        synthesizedFactoryClassName('CoffeeMaker', 'brand_name'),
        'CoffeeMakerBrand_nameFactory',
      );
    });

    test('qualifier #brandName (camelCase) → BrandName suffix', () {
      expect(
        synthesizedFactoryClassName('CoffeeMaker', 'brandName'),
        'CoffeeMakerBrandNameFactory',
      );
    });

    test('qualifier #BrandName (already capitalized) → BrandName suffix', () {
      expect(
        synthesizedFactoryClassName('CoffeeMaker', 'BrandName'),
        'CoffeeMakerBrandNameFactory',
      );
    });
  });

  group('isValidQualifierIdentifier', () {
    test('accepts plain lowercase', () {
      expect(isValidQualifierIdentifier('standard'), isTrue);
    });

    test('accepts camelCase', () {
      expect(isValidQualifierIdentifier('brandName'), isTrue);
    });

    test('accepts snake_case with underscore', () {
      expect(isValidQualifierIdentifier('brand_name'), isTrue);
    });

    test('accepts digits in the middle', () {
      expect(isValidQualifierIdentifier('v2'), isTrue);
    });

    test('accepts digit-leading content (suffix position)', () {
      // Qualifier is suffixed onto a class name, so its first character is
      // never the first character of the identifier.
      expect(isValidQualifierIdentifier('123foo'), isTrue);
    });

    test('rejects empty string', () {
      expect(isValidQualifierIdentifier(''), isFalse);
    });

    test('rejects hyphen', () {
      expect(isValidQualifierIdentifier('foo-bar'), isFalse);
    });

    test('rejects dot', () {
      expect(isValidQualifierIdentifier('foo.bar'), isFalse);
    });

    test('rejects whitespace', () {
      expect(isValidQualifierIdentifier('foo bar'), isFalse);
    });

    test('rejects dollar sign (reserved for codegen)', () {
      expect(isValidQualifierIdentifier(r'foo$bar'), isFalse);
    });

    test('rejects unicode beyond ASCII identifier chars', () {
      expect(isValidQualifierIdentifier('föö'), isFalse);
    });
  });
}
