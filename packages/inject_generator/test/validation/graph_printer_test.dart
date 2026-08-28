import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/analysis/entry_point_collector.dart';
import 'package:inject_generator/src/validation/async_propagation_result.dart';
import 'package:inject_generator/src/validation/binding_graph_result.dart';
import 'package:inject_generator/src/validation/binding_key.dart';
import 'package:inject_generator/src/validation/graph_printer.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

BindingKey _key(ClassElement cls, {String? qualifier}) => BindingKey.fromDartType(cls.thisType, qualifier: qualifier)!;

BindingSource _source(
  BindingKey key,
  ClassElement element, {
  bool isAsync = false,
  bool isSingleton = false,
}) => (
  key: key,
  origin: element.name!,
  isAsync: isAsync,
  isSingleton: isSingleton,
  element: element,
);

EntryPoint _ep(BindingKey key, ClassElement element) => (
  element: element,
  key: key,
  isFuture: false,
  isProvider: false,
);

AsyncPropagationResult _asyncResult({
  required Map<BindingKey, bool> asyncBindings,
  required Map<BindingKey, BindingSource> bindingMap,
  required Map<BindingKey, List<BindingKey>> dependencyEdges,
}) => AsyncPropagationResult(
  asyncBindings: asyncBindings,
  bindingMap: bindingMap,
  dependencyEdges: dependencyEdges,
);

BindingGraphResult _graphResult({
  required Map<BindingKey, BindingSource> bindingMap,
  required Map<BindingKey, List<BindingKey>> dependencyEdges,
}) => BindingGraphResult(
  bindingMap: bindingMap,
  dependencyEdges: dependencyEdges,
  duplicateBindings: {},
);

void main() {
  group('GraphPrinter', () {
    late LibraryElement lib;

    setUpAll(() async {
      lib = await _resolveLibrary('''
        class CoffeeShop {}
        class Brewer {}
        class Grinder {}
        class Heater {}
        class SimpleApp {}
        class Service {}
        class HttpClient {}
        class UseCaseA {}
        class UseCaseB {}
        class Repository {}
        class App {}
        class A {}
        class B {}
        class C {}
        class L1 {}
        class L2 {}
        class L3 {}
        class L4 {}
        class L5 {}
        class L6 {}
        class L7 {}
        class L8 {}
        class L9 {}
        class L10 {}
        class L11 {}
        class L12 {}
        class L13 {}
        class L14 {}
        class L15 {}
        class L16 {}
        class L17 {}
        class L18 {}
        class L19 {}
        class L20 {}
        class L21 {}
        class L22 {}
        class Deep {}
      ''');
    });

    ClassElement cls(String name) => lib.getClass(name)!;

    test('empty entry-points list — returns empty string', () {
      final k = _key(cls('Heater'));
      final gr = _graphResult(bindingMap: {k: _source(k, cls('Heater'))}, dependencyEdges: {k: []});
      final ar = _asyncResult(asyncBindings: {}, bindingMap: {k: _source(k, cls('Heater'))}, dependencyEdges: {k: []});
      final printer = GraphPrinter(
        componentClass: cls('CoffeeShop'),
        entryPoints: [],
        graphResult: gr,
        asyncResult: ar,
      );
      expect(printer.render(), isEmpty);
    });

    test('linear chain of 3 nodes — fully expanded, no shared block', () {
      // SimpleApp → Service (@singleton) → HttpClient
      final kApp = _key(cls('SimpleApp'));
      final kService = _key(cls('Service'));
      final kHttp = _key(cls('HttpClient'));

      final bindingMap = {
        kApp: _source(kApp, cls('SimpleApp')),
        kService: _source(kService, cls('Service'), isSingleton: true),
        kHttp: _source(kHttp, cls('HttpClient')),
      };
      final depEdges = {
        kApp: <BindingKey>[],
        kService: [kHttp],
        kHttp: <BindingKey>[],
      };
      final gr = _graphResult(bindingMap: bindingMap, dependencyEdges: depEdges);
      final ar = _asyncResult(asyncBindings: {}, bindingMap: bindingMap, dependencyEdges: depEdges);

      final printer = GraphPrinter(
        componentClass: cls('SimpleApp'),
        entryPoints: [_ep(kService, cls('Service'))],
        graphResult: gr,
        asyncResult: ar,
      );

      final output = printer.render();

      expect(output, contains('[inject_generator] Dependency graph for SimpleApp:'));
      expect(output, contains('Service (@singleton)'));
      expect(output, contains('HttpClient'));
      expect(output, isNot(contains('shared bindings')));
      expect(output, isNot(contains('...')));
    });

    test('diamond — Heater shared by Brewer and Grinder — pub-style references in main tree', () {
      // CoffeeShop → Brewer (@singleton, @async) → Heater (@singleton)
      //           └→ Grinder                     → Heater (@singleton)
      final kCoffee = _key(cls('CoffeeShop'));
      final kBrewer = _key(cls('Brewer'));
      final kGrinder = _key(cls('Grinder'));
      final kHeater = _key(cls('Heater'));

      final bindingMap = {
        kCoffee: _source(kCoffee, cls('CoffeeShop')),
        kBrewer: _source(kBrewer, cls('Brewer'), isAsync: true, isSingleton: true),
        kGrinder: _source(kGrinder, cls('Grinder')),
        kHeater: _source(kHeater, cls('Heater'), isSingleton: true),
      };
      final depEdges = {
        kCoffee: <BindingKey>[],
        kBrewer: [kHeater],
        kGrinder: [kHeater],
        kHeater: <BindingKey>[],
      };
      final gr = _graphResult(bindingMap: bindingMap, dependencyEdges: depEdges);
      final ar = _asyncResult(
        asyncBindings: {kBrewer: true, kHeater: false},
        bindingMap: bindingMap,
        dependencyEdges: depEdges,
      );

      final printer = GraphPrinter(
        componentClass: cls('CoffeeShop'),
        entryPoints: [_ep(kBrewer, cls('Brewer')), _ep(kGrinder, cls('Grinder'))],
        graphResult: gr,
        asyncResult: ar,
      );

      final output = printer.render();

      // Main tree header
      expect(output, contains('[inject_generator] Dependency graph for CoffeeShop:'));
      // Brewer and Grinder appear fully expanded in main tree
      expect(output, contains('Brewer (@singleton, @async)'));
      expect(output, contains('Grinder'));
      // Heater appears as pub-style reference (no annotation, just name...)
      expect(output, contains('Heater...'));
      // Shared block present
      expect(output, contains('shared bindings'));
      expect(output, contains('Heater (@singleton, injected by: Brewer, Grinder)'));
    });

    test('shared node with own dependencies — shared block renders sub-tree', () {
      // App → UseCaseA → Repository (@singleton, @async) → HttpClient (@singleton)
      //     → UseCaseB → Repository
      final kApp = _key(cls('App'));
      final kUseCaseA = _key(cls('UseCaseA'));
      final kUseCaseB = _key(cls('UseCaseB'));
      final kRepo = _key(cls('Repository'));
      final kHttp = _key(cls('HttpClient'));

      final bindingMap = {
        kApp: _source(kApp, cls('App')),
        kUseCaseA: _source(kUseCaseA, cls('UseCaseA')),
        kUseCaseB: _source(kUseCaseB, cls('UseCaseB')),
        kRepo: _source(kRepo, cls('Repository'), isSingleton: true, isAsync: true),
        kHttp: _source(kHttp, cls('HttpClient'), isSingleton: true),
      };
      final depEdges = {
        kApp: <BindingKey>[],
        kUseCaseA: [kRepo],
        kUseCaseB: [kRepo],
        kRepo: [kHttp],
        kHttp: <BindingKey>[],
      };
      final gr = _graphResult(bindingMap: bindingMap, dependencyEdges: depEdges);
      final ar = _asyncResult(
        asyncBindings: {kRepo: true, kUseCaseA: true, kUseCaseB: true},
        bindingMap: bindingMap,
        dependencyEdges: depEdges,
      );

      final printer = GraphPrinter(
        componentClass: cls('App'),
        entryPoints: [_ep(kUseCaseA, cls('UseCaseA')), _ep(kUseCaseB, cls('UseCaseB'))],
        graphResult: gr,
        asyncResult: ar,
      );

      final output = printer.render();

      // Repository appears as reference in main tree
      expect(output, contains('Repository...'));
      // Shared block has Repository with sub-tree including HttpClient
      expect(output, contains('Repository (@singleton, @async, injected by: UseCaseA, UseCaseB)'));
      expect(output, contains('HttpClient (@singleton)'));
    });

    test('nested shared — shared node A has a dep B which is also shared', () {
      // App entry points: [UseCaseA, UseCaseB]
      //   UseCaseA → Repository, HttpClient
      //   UseCaseB → Repository
      //   Repository → HttpClient
      // Receivers: Repository ← {UseCaseA, UseCaseB} (shared);
      //            HttpClient ← {UseCaseA, Repository} (shared).
      // Repository (shared) has dep HttpClient (also shared) — so Repository's
      // shared-block sub-tree must render HttpClient as `HttpClient...`, and
      // HttpClient must have its own shared-block root entry.
      final kApp = _key(cls('App'));
      final kUseCaseA = _key(cls('UseCaseA'));
      final kUseCaseB = _key(cls('UseCaseB'));
      final kRepo = _key(cls('Repository'));
      final kHttp = _key(cls('HttpClient'));

      final bindingMap = {
        kApp: _source(kApp, cls('App')),
        kUseCaseA: _source(kUseCaseA, cls('UseCaseA')),
        kUseCaseB: _source(kUseCaseB, cls('UseCaseB')),
        kRepo: _source(kRepo, cls('Repository'), isSingleton: true),
        kHttp: _source(kHttp, cls('HttpClient')),
      };
      final depEdges = {
        kApp: <BindingKey>[],
        kUseCaseA: [kRepo, kHttp],
        kUseCaseB: [kRepo],
        kRepo: [kHttp],
        kHttp: <BindingKey>[],
      };
      final gr = _graphResult(bindingMap: bindingMap, dependencyEdges: depEdges);
      final ar = _asyncResult(asyncBindings: {}, bindingMap: bindingMap, dependencyEdges: depEdges);

      final printer = GraphPrinter(
        componentClass: cls('App'),
        entryPoints: [_ep(kUseCaseA, cls('UseCaseA')), _ep(kUseCaseB, cls('UseCaseB'))],
        graphResult: gr,
        asyncResult: ar,
      );

      final output = printer.render();

      // Both shared nodes appear as pub-style references in the main tree.
      expect(output, contains('Repository...'));
      expect(output, contains('HttpClient...'));

      // Shared-block header present and both have root entries.
      expect(output, contains('(shared bindings — each appears in the tree above as <name>...)'));
      expect(output, contains('Repository (@singleton, injected by: UseCaseA, UseCaseB)'));
      expect(output, contains('HttpClient (injected by: Repository, UseCaseA)'));

      // Repository's shared-block sub-tree references its shared dep as
      // a `HttpClient...` reference (not a fully expanded label) — this is the
      // nested-shared invariant: a shared node's own deps still respect the
      // `<name>...` rule when they are themselves shared.
      final repoIndex = output.indexOf('Repository (@singleton, injected by:');
      expect(repoIndex, greaterThanOrEqualTo(0));
      // Look for `└── HttpClient...` (sub-tree connector + pub-style ref) after the Repository line.
      final subTreeRef = output.indexOf(RegExp(r'└── HttpClient\.\.\.'), repoIndex);
      expect(
        subTreeRef,
        greaterThan(repoIndex),
        reason: 'Repository sub-tree must reference HttpClient as <name>... not fully expand it',
      );
    });

    test('alphabetical sorting in shared block — multiple shared nodes', () {
      // B → A (shared), B → C (shared), D → A, D → C
      // entry points: [B, D]
      final kApp = _key(cls('App'));
      final kA = _key(cls('A'));
      final kB = _key(cls('B'));
      final kC = _key(cls('C'));
      final kDep = _key(cls('Deep')); // using Deep as the 4th node

      final bindingMap = {
        kApp: _source(kApp, cls('App')),
        kA: _source(kA, cls('A')),
        kB: _source(kB, cls('B')),
        kC: _source(kC, cls('C')),
        kDep: _source(kDep, cls('Deep')),
      };
      final depEdges = {
        kApp: <BindingKey>[],
        kA: <BindingKey>[],
        kB: [kA, kC],
        kC: <BindingKey>[],
        kDep: [kA, kC],
      };
      final gr = _graphResult(bindingMap: bindingMap, dependencyEdges: depEdges);
      final ar = _asyncResult(asyncBindings: {}, bindingMap: bindingMap, dependencyEdges: depEdges);

      final printer = GraphPrinter(
        componentClass: cls('App'),
        entryPoints: [_ep(kB, cls('B')), _ep(kDep, cls('Deep'))],
        graphResult: gr,
        asyncResult: ar,
      );

      final output = printer.render();

      // Both A and C are shared; block entries must be alphabetically sorted.
      // Shared-block body lines are indented with 2 spaces.
      final aIndex = output.indexOf(RegExp(r'^  A ', multiLine: true));
      final cIndex = output.indexOf(RegExp(r'^  C ', multiLine: true));
      expect(aIndex, greaterThanOrEqualTo(0), reason: 'A entry must be present in shared block');
      expect(cIndex, greaterThanOrEqualTo(0), reason: 'C entry must be present in shared block');
      expect(aIndex, lessThan(cIndex), reason: 'A should appear before C in shared block');
    });

    test('alphabetical sorting of receiver list per shared entry', () {
      // Heater injected by Grinder and Brewer → sorted: Brewer, Grinder
      final kCoffee = _key(cls('CoffeeShop'));
      final kBrewer = _key(cls('Brewer'));
      final kGrinder = _key(cls('Grinder'));
      final kHeater = _key(cls('Heater'));

      final bindingMap = {
        kCoffee: _source(kCoffee, cls('CoffeeShop')),
        kBrewer: _source(kBrewer, cls('Brewer')),
        kGrinder: _source(kGrinder, cls('Grinder')),
        kHeater: _source(kHeater, cls('Heater')),
      };
      final depEdges = {
        kCoffee: <BindingKey>[],
        kBrewer: [kHeater],
        kGrinder: [kHeater],
        kHeater: <BindingKey>[],
      };
      final gr = _graphResult(bindingMap: bindingMap, dependencyEdges: depEdges);
      final ar = _asyncResult(asyncBindings: {}, bindingMap: bindingMap, dependencyEdges: depEdges);

      final printer = GraphPrinter(
        componentClass: cls('CoffeeShop'),
        entryPoints: [_ep(kBrewer, cls('Brewer')), _ep(kGrinder, cls('Grinder'))],
        graphResult: gr,
        asyncResult: ar,
      );

      final output = printer.render();
      // Receiver list is sorted alphabetically: Brewer before Grinder
      expect(output, contains('injected by: Brewer, Grinder'));
    });

    test('multiple entry-points — correct connector choice (├── vs └──)', () {
      final kCoffee = _key(cls('CoffeeShop'));
      final kBrewer = _key(cls('Brewer'));
      final kGrinder = _key(cls('Grinder'));

      final bindingMap = {
        kCoffee: _source(kCoffee, cls('CoffeeShop')),
        kBrewer: _source(kBrewer, cls('Brewer')),
        kGrinder: _source(kGrinder, cls('Grinder')),
      };
      final depEdges = {
        kCoffee: <BindingKey>[],
        kBrewer: <BindingKey>[],
        kGrinder: <BindingKey>[],
      };
      final gr = _graphResult(bindingMap: bindingMap, dependencyEdges: depEdges);
      final ar = _asyncResult(asyncBindings: {}, bindingMap: bindingMap, dependencyEdges: depEdges);

      final printer = GraphPrinter(
        componentClass: cls('CoffeeShop'),
        entryPoints: [_ep(kBrewer, cls('Brewer')), _ep(kGrinder, cls('Grinder'))],
        graphResult: gr,
        asyncResult: ar,
      );

      final output = printer.render();

      // First entry uses ├──, last uses └──
      expect(output, contains('├── Brewer'));
      expect(output, contains('└── Grinder'));
    });

    test('depth limit — chain longer than 20 emits depth-limit marker', () {
      // Build a linear chain L1 → L2 → ... → L22 (22 levels — entry point at
      // depth 0 and 21 descendants, so the 21st descendant at depth 21 fires
      // the depth-limit marker).
      final nodes = [
        cls('L1'),
        cls('L2'),
        cls('L3'),
        cls('L4'),
        cls('L5'),
        cls('L6'),
        cls('L7'),
        cls('L8'),
        cls('L9'),
        cls('L10'),
        cls('L11'),
        cls('L12'),
        cls('L13'),
        cls('L14'),
        cls('L15'),
        cls('L16'),
        cls('L17'),
        cls('L18'),
        cls('L19'),
        cls('L20'),
        cls('L21'),
        cls('L22'),
      ];
      final keys = nodes.map((c) => _key(c)).toList();
      final bindingMap = {for (var i = 0; i < nodes.length; i++) keys[i]: _source(keys[i], nodes[i])};
      final depEdges = {
        for (var i = 0; i < keys.length - 1; i++) keys[i]: [keys[i + 1]],
        keys.last: <BindingKey>[],
      };
      final gr = _graphResult(bindingMap: bindingMap, dependencyEdges: depEdges);
      final ar = _asyncResult(asyncBindings: {}, bindingMap: bindingMap, dependencyEdges: depEdges);

      final printer = GraphPrinter(
        componentClass: cls('Deep'),
        entryPoints: [_ep(keys[0], nodes[0])],
        graphResult: gr,
        asyncResult: ar,
      );

      final output = printer.render();
      expect(output, contains('… (depth limit reached)'));
    });

    test('shared sub-tree with validator-missed cycle short-circuits via seen', () {
      // Hypothetical: validator missed a cycle B → C → B that lives under
      // shared root A. Without seen propagation, the printer would recurse
      // until depth-limit (20 lines of garbage). With seen seeded by the
      // block root + propagated through the sub-tree, the back-edge to B is
      // short-circuited as `B...` on the second visit.
      final kApp = _key(cls('App'));
      final kA = _key(cls('A'));
      final kB = _key(cls('B'));
      final kC = _key(cls('C'));
      final kX = _key(cls('UseCaseA'));
      final kY = _key(cls('UseCaseB'));

      final bindingMap = {
        kApp: _source(kApp, cls('App')),
        kA: _source(kA, cls('A')),
        kB: _source(kB, cls('B')),
        kC: _source(kC, cls('C')),
        kX: _source(kX, cls('UseCaseA')),
        kY: _source(kY, cls('UseCaseB')),
      };
      // X and Y both inject A (→ A is shared).
      // A → B → C → B  (cycle hidden under shared root A; B and C have only A
      // and each other as receivers, so neither is shared in its own right).
      final depEdges = {
        kApp: <BindingKey>[],
        kX: [kA],
        kY: [kA],
        kA: [kB],
        kB: [kC],
        kC: [kB],
      };
      final gr = _graphResult(bindingMap: bindingMap, dependencyEdges: depEdges);
      final ar = _asyncResult(asyncBindings: {}, bindingMap: bindingMap, dependencyEdges: depEdges);

      final printer = GraphPrinter(
        componentClass: cls('App'),
        entryPoints: [_ep(kX, cls('UseCaseA')), _ep(kY, cls('UseCaseB'))],
        graphResult: gr,
        asyncResult: ar,
      );

      final output = printer.render();

      // The back-edge must short-circuit as a `...`-reference, not stack-recurse.
      // Count `… (depth limit reached)` markers — must be zero.
      expect(
        output,
        isNot(contains('… (depth limit reached)')),
        reason: 'cycle inside shared sub-tree must be caught by seen, not depth-limit',
      );
      // The cycle target B must appear at least once as a back-edge reference.
      expect(output, contains('B...'), reason: 'B must short-circuit on the back-edge visit');
    });

    test('deterministic output — two renders produce identical strings', () {
      final kCoffee = _key(cls('CoffeeShop'));
      final kBrewer = _key(cls('Brewer'));
      final kGrinder = _key(cls('Grinder'));
      final kHeater = _key(cls('Heater'));

      final bindingMap = {
        kCoffee: _source(kCoffee, cls('CoffeeShop')),
        kBrewer: _source(kBrewer, cls('Brewer'), isSingleton: true, isAsync: true),
        kGrinder: _source(kGrinder, cls('Grinder')),
        kHeater: _source(kHeater, cls('Heater'), isSingleton: true),
      };
      final depEdges = {
        kCoffee: <BindingKey>[],
        kBrewer: [kHeater],
        kGrinder: [kHeater],
        kHeater: <BindingKey>[],
      };
      final gr = _graphResult(bindingMap: bindingMap, dependencyEdges: depEdges);
      final ar = _asyncResult(
        asyncBindings: {kBrewer: true},
        bindingMap: bindingMap,
        dependencyEdges: depEdges,
      );

      final printer = GraphPrinter(
        componentClass: cls('CoffeeShop'),
        entryPoints: [_ep(kBrewer, cls('Brewer')), _ep(kGrinder, cls('Grinder'))],
        graphResult: gr,
        asyncResult: ar,
      );

      expect(printer.render(), equals(printer.render()));
    });
  });
}
