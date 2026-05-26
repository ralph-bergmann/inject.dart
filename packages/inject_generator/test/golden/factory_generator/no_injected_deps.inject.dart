// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'no_injected_deps.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    _messageFactory$Provider = _MessageFactory$Provider();
  }

  late final _MessageFactory$Provider _messageFactory$Provider;

  @override
  _i1.MessageFactory get messageFactory => _messageFactory$Provider.get();
}

class _MessageFactory$Factory implements _i1.MessageFactory {
  const _MessageFactory$Factory();

  @override
  _i1.Message create(String text) => _i1.Message(text);
}

class _MessageFactory$Provider implements _i2.Provider<_i1.MessageFactory> {
  _MessageFactory$Provider();

  late final _i1.MessageFactory _factory = _MessageFactory$Factory();

  @override
  _i1.MessageFactory get() => _factory;
}
