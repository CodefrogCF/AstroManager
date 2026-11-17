import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

import '../domain/models/weather_forecast.dart';

class WeatherAttribution extends StatelessWidget {
  const WeatherAttribution(this.provider, {this.style, super.key});

  final WeatherProviderMetadata provider;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final attribution = provider.attribution;
    if (attribution == null) return const SizedBox.shrink();

    final textStyle = style ?? Theme.of(context).textTheme.labelSmall;
    final url = Uri.tryParse(provider.homepageUrl ?? '');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      return Text(attribution, style: textStyle);
    }
    return Link(
      uri: url,
      target: LinkTarget.blank,
      builder: (context, followLink) => InkWell(
        onTap: followLink,
        child: Text(
          attribution,
          style: textStyle?.copyWith(decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}
