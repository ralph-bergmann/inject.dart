import 'package:inject_annotation/inject_annotation.dart';

import 'multi_constructor_qualifier_component.inject.dart' as g;

const preview = Qualifier(#preview);
const detail = Qualifier(#detail);

@inject
class Canvas {}

class ProfileWidget {
  @inject
  @preview
  ProfileWidget.preview(this.canvas, @preview this.configService);

  @inject
  @detail
  ProfileWidget.detail(this.canvas, @detail this.configService);

  final Canvas canvas;
  final ConfigService configService;
}

@singleton
class ConfigService {
  @inject
  @preview
  ConfigService.forPreview();

  @inject
  @detail
  ConfigService.forDetail();
}

@Component()
abstract class ProfileComponent {
  static const g.ProfileComponent$Component Function() create = g.ProfileComponent$Component.create;

  @inject
  @preview
  ProfileWidget get previewWidget;

  @inject
  @detail
  ProfileWidget get detailWidget;

  @inject
  @preview
  ConfigService get previewConfig;

  @inject
  @detail
  ConfigService get detailConfig;
}
