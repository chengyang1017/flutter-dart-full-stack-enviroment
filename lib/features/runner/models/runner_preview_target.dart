enum RunnerPreviewTarget {
  phone,
  tablet,
  web,
}

extension RunnerPreviewTargetInfo on RunnerPreviewTarget {
  String get label => switch (this) {
        RunnerPreviewTarget.phone => '手机',
        RunnerPreviewTarget.tablet => '平板',
        RunnerPreviewTarget.web => '网页',
      };

  String get description => switch (this) {
        RunnerPreviewTarget.phone => '在 IDE 内以 390 × 844 的手机尺寸运行',
        RunnerPreviewTarget.tablet => '在 IDE 内以 820 × 1180 的平板尺寸运行',
        RunnerPreviewTarget.web => '运行完成后在新的浏览器标签页打开',
      };

  bool get opensExternalTab => this == RunnerPreviewTarget.web;

  double? get viewportWidth => switch (this) {
        RunnerPreviewTarget.phone => 390,
        RunnerPreviewTarget.tablet => 820,
        RunnerPreviewTarget.web => null,
      };

  double? get viewportHeight => switch (this) {
        RunnerPreviewTarget.phone => 844,
        RunnerPreviewTarget.tablet => 1180,
        RunnerPreviewTarget.web => null,
      };
}
