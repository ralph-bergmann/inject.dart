## 0.4.1

- `exclude` now also reads the `analysis_options.yaml` above the package root. In a pub
  workspace, a package without its own options file uses the file of the workspace root;
  before, the plugin stopped at the package root and ignored that file's globs.

## 0.4.0

- `exclude` now works like the analyzer's `analyzer: exclude`. The lists of a file and the
  files it includes are combined; before, the including file replaced them. An
  `analysis_options.yaml` in a subfolder adds globs relative to its own folder, and the globs
  from the files above it still apply.

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
