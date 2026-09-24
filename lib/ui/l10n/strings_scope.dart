import 'package:flutter/widgets.dart';
import 'package:fes_distribution/ui/l10n/app_strings.dart';

class StringsScope extends InheritedWidget {
  const StringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StringsScope>();
    assert(scope != null, 'StringsScope not found in widget tree');
    return scope!.strings;
  }

  @override
  bool updateShouldNotify(StringsScope oldWidget) =>
      oldWidget.strings.language != strings.language;
}

extension StringsContext on BuildContext {
  AppStrings get s => StringsScope.of(this);
}
