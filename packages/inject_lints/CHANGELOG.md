## 0.3.0

- Read rule options like the analyzer does: from the `analysis_options.yaml` nearest to each file,
  following its `include:` entries, relative paths and `package:` URIs alike. A shared options
  file can now hold the `inject_lints` section for all packages. Before, the plugin read only the
  file at the package root.
- Document that `diagnostics` takes a map, not a list, and that rule options go in the top-level
  `inject_lints` section, not under `diagnostics`.

## 0.2.0

- Add the style rule `avoid_constructing_injected_class`. It reports a class with `@inject` or
  `@assistedInject` that is constructed by hand instead of taken from the dependency graph. It
  checks tests too; skip files with `exclude` globs.
- Rules can take options in a top-level `inject_lints` section of `analysis_options.yaml`.

## 0.1.0

- Initial release: an analyzer plugin that reports in the IDE what the inject.dart generator would
  reject, with quick fixes and optional style rules.
