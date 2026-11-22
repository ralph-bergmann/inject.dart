## 0.2.0

- Add the style rule `avoid_constructing_injected_class`. It reports a class with `@inject` or
  `@assistedInject` that is constructed by hand instead of taken from the dependency graph. It
  checks tests too; skip files with `exclude` globs.
- Rules can take options in a top-level `inject_lints` section of `analysis_options.yaml`.

## 0.1.0

- Initial release: an analyzer plugin that reports in the IDE what the inject.dart generator would
  reject, with quick fixes and optional style rules.
