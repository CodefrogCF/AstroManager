import 'package:astromanager/core/astronomy/solar_events.dart';
import 'package:astromanager/features/dashboard/domain/seven_night_weather.dart';
import 'package:astromanager/features/locations/domain/models/observing_location.dart';
import 'package:astromanager/features/weather/domain/models/weather_forecast.dart';
import 'package:astromanager/features/weather/domain/models/weather_value.dart';
import 'package:flutter_test/flutter_test.dart';

const site = ObservingLocation(
  id: 'ch',
  name: 'Swiss site',
  latitude: 47.48,
  longitude: 8.21,
  elevationMeters: 400,
  timeZone: 'Europe/Zurich',
  isDefault: true,
);

WeatherForecast weather(List<HourlyWeatherForecast> hours) => WeatherForecast(
  provider: const WeatherProviderMetadata(id: 'fake', name: 'Test'),
  latitudeDegrees: site.latitude,
  longitudeDegrees: site.longitude,
  issuedAtUtc: DateTime.utc(2026, 11, 3, 18),
  fetchedAtUtc: DateTime.utc(2026, 11, 3, 18),
  hours: hours,
);

HourlyWeatherForecast hour(int utcHour, {double? cloud}) =>
    HourlyWeatherForecast(
      timeUtc: DateTime.utc(2026, 11, 3, utcHour),
      totalCloudCoverPercent: cloud == null
          ? const WeatherValue<double>.missing()
          : WeatherValue<double>.available(cloud),
    );

void main() {
  test(
    'full day includes elapsed daylight and clips both clear-sky totals',
    () {
      final day = SolarEvents.calculateForLocalDate(
        location: site,
        localDate: DateTime.utc(2026, 11, 3),
      );
      final forecast = weather([
        for (final time in [8, 9, 10, 19, 20, 23]) hour(time, cloud: 10),
      ]);
      ClearSkySummary summarize(ClearSkyView view) =>
          SevenNightWeatherAggregator.calculate(
            periods: [day],
            forecast: forecast,
            nowUtc: DateTime.utc(2026, 11, 3, 18),
            options: const SevenNightWeatherOptions(),
            view: view,
          ).single;

      final night = summarize(ClearSkyView.nightOnly);
      expect(night.clearDuration, const Duration(hours: 2));
      expect(night.longestClearInterval, const Duration(hours: 2));

      final fullDay = summarize(ClearSkyView.fullDay);
      expect(fullDay.expectedCoverage, const Duration(hours: 24));
      expect(fullDay.forecastCoverage, const Duration(hours: 5));
      expect(fullDay.clearDuration, const Duration(hours: 5));
      expect(fullDay.longestClearInterval, const Duration(hours: 3));
      expect(fullDay.isComplete, isFalse);
    },
  );

  test('full-day coverage follows local DST and fractional UTC offsets', () {
    const kathmandu = ObservingLocation(
      id: 'np',
      name: 'Kathmandu',
      latitude: 27.7,
      longitude: 85.3,
      elevationMeters: 1400,
      timeZone: 'Asia/Kathmandu',
      isDefault: false,
    );
    for (final (location, date, hours) in [
      (site, DateTime.utc(2026, 3, 29), 23),
      (site, DateTime.utc(2026, 10, 25), 25),
      (kathmandu, DateTime.utc(2026, 11, 3), 24),
    ]) {
      final day = SolarEvents.calculateForLocalDate(
        location: location,
        localDate: date,
      );
      final midnight = day.dayStartUtc;
      final firstHour = DateTime.utc(
        midnight.year,
        midnight.month,
        midnight.day,
        midnight.hour,
      );
      final summary = SevenNightWeatherAggregator.calculate(
        periods: [day],
        forecast: weather([
          for (var i = 0; i <= hours; i++)
            HourlyWeatherForecast(
              timeUtc: firstHour.add(Duration(hours: i)),
              totalCloudCoverPercent: const WeatherValue.available(0),
            ),
        ]),
        nowUtc: day.dayEndUtc,
        options: const SevenNightWeatherOptions(),
        view: ClearSkyView.fullDay,
      ).single;
      final expected = Duration(hours: hours);
      expect(summary.expectedCoverage, expected, reason: location.timeZone);
      expect(summary.isComplete, isTrue, reason: location.timeZone);
      expect(summary.clearDuration, expected, reason: location.timeZone);
      expect(summary.longestClearInterval, expected, reason: location.timeZone);
    }
  });

  test(
    'only forecast-covered darkness is counted; missing hours break clear runs',
    () {
      final night = SolarEvents.calculateForLocalDate(
        location: site,
        localDate: DateTime.utc(2026, 11, 3),
      );
      const options = SevenNightWeatherOptions(
        maximumCloudPercent: 30,
        minimumClearDuration: Duration(hours: 2),
      );
      final summary = SevenNightWeatherAggregator.calculate(
        periods: [night],
        forecast: weather([
          hour(19, cloud: 10),
          hour(20, cloud: 10),
          hour(21), // explicitly missing cloud cover
          hour(22, cloud: 15),
          hour(23, cloud: 70),
        ]),
        nowUtc: DateTime.utc(2026, 11, 3, 18),
        options: options,
      ).single;
      expect(summary.hasForecast, isTrue);
      expect(summary.forecastCoverage, const Duration(hours: 4));
      expect(summary.clearDuration, const Duration(hours: 2));
      expect(summary.longestClearInterval, const Duration(hours: 2));
      expect(summary.isComplete, isFalse);
      expect(summary.qualifies(options), isTrue);
    },
  );

  test('sparse forecast must never be interpreted as a clear night', () {
    final night = SolarEvents.calculateForLocalDate(
      location: site,
      localDate: DateTime.utc(2026, 11, 3),
    );
    final result = SevenNightWeatherAggregator.calculate(
      periods: [night],
      forecast: weather([hour(20)]),
      nowUtc: DateTime.utc(2026, 11, 3, 18),
      options: const SevenNightWeatherOptions(),
    ).single;
    expect(result.forecastCoverage, Duration.zero);
    expect(result.clearDuration, Duration.zero);
    expect(result.averageCloudPercent, isNull);
    expect(result.isComplete, isFalse);
    expect(result.trend, NightCloudTrend.unknown);
  });

  test('only future dark intervals contribute to remaining coverage', () {
    final night = SolarEvents.calculateForLocalDate(
      location: site,
      localDate: DateTime.utc(2026, 11, 3),
    );
    final result = SevenNightWeatherAggregator.calculate(
      periods: [night],
      forecast: weather([hour(19, cloud: 0), hour(20, cloud: 0)]),
      nowUtc: DateTime.utc(2026, 11, 3, 20),
      options: const SevenNightWeatherOptions(),
    ).single;
    expect(result.forecastCoverage, const Duration(hours: 1));
    expect(result.clearDuration, Duration.zero);
  });

  test(
    'seven upcoming local nights remain unique through a DST transition',
    () {
      final nights = SevenNightWeatherAggregator.upcomingNights(
        location: site,
        nowUtc: DateTime.utc(2026, 3, 28, 20),
      );
      expect(nights, hasLength(7));
      expect(nights.map((n) => n.localDate).toSet(), hasLength(7));
      expect(nights.first.localDate, DateTime.utc(2026, 3, 28));
      expect(
        nights.first.nightStartUtc.isBefore(nights[1].nightStartUtc),
        isTrue,
      );
      for (final n in nights) {
        expect(n.nightEndUtc.isAfter(n.nightStartUtc), isTrue);
      }

      final periods = SevenNightWeatherAggregator.upcomingPeriods(
        location: site,
        nowUtc: DateTime.utc(2026, 3, 29, 1),
      );
      expect(periods.nights.first.localDate, DateTime.utc(2026, 3, 28));
      expect(periods.days.first.localDate, DateTime.utc(2026, 3, 29));
      expect(periods.days, hasLength(7));
    },
  );

  test('trend describes actual cloud evolution within covered darkness', () {
    final night = SolarEvents.calculateForLocalDate(
      location: site,
      localDate: DateTime.utc(2026, 11, 3),
    );
    final result = SevenNightWeatherAggregator.calculate(
      periods: [night],
      forecast: weather([
        hour(19, cloud: 90),
        hour(20, cloud: 80),
        hour(21, cloud: 10),
        hour(22, cloud: 0),
      ]),
      nowUtc: DateTime.utc(2026, 11, 3, 18),
      options: const SevenNightWeatherOptions(),
    ).single;
    expect(result.trend, NightCloudTrend.improving);
  });

  test('invalid thresholds are rejected', () {
    final nights = [
      SolarEvents.calculateForLocalDate(
        location: site,
        localDate: DateTime.utc(2026, 11, 3),
      ),
    ];
    expect(
      () => SevenNightWeatherAggregator.calculate(
        periods: nights,
        forecast: weather([hour(19)]),
        nowUtc: DateTime.utc(2026, 11, 3, 18),
        options: const SevenNightWeatherOptions(maximumCloudPercent: 101),
      ),
      throwsArgumentError,
    );
  });
}
