import 'package:flutter/material.dart';

import 'ui_strings.dart';

/// Translates existing English UI labels. Falls back to English for
/// astronomical names, dynamic values, and unrecognized strings.
String appTranslate(BuildContext context, String source) {
  if (Localizations.maybeLocaleOf(context)?.languageCode != 'de') {
    return source;
  }
  return appGermanUiStrings[source] ?? source;
}

/// Preserves Flutter Text scaling, directionality, and semantics while
/// translating visible labels. Keys remain on the outer widget.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) => Text(
    appTranslate(context, data),
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    textScaler: textScaler,
    maxLines: maxLines,
    semanticsLabel: semanticsLabel == null
        ? null
        : appTranslate(context, semanticsLabel!),
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor: selectionColor,
  );
}

InputDecoration localizeDecoration(
  BuildContext context,
  InputDecoration decoration,
) => decoration.copyWith(
  labelText: decoration.labelText == null
      ? null
      : appTranslate(context, decoration.labelText!),
  hintText: decoration.hintText == null
      ? null
      : appTranslate(context, decoration.hintText!),
  helperText: decoration.helperText == null
      ? null
      : appTranslate(context, decoration.helperText!),
  counterText: decoration.counterText == null
      ? null
      : appTranslate(context, decoration.counterText!),
  errorText: decoration.errorText == null
      ? null
      : appTranslate(context, decoration.errorText!),
);
