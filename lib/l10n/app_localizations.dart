import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'AstroManager'**
  String get appName;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AstroManager'**
  String get onboardingTitle;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navTargets.
  ///
  /// In en, this message translates to:
  /// **'Targets'**
  String get navTargets;

  /// No description provided for @navPlanner.
  ///
  /// In en, this message translates to:
  /// **'Night Planner'**
  String get navPlanner;

  /// No description provided for @navEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get navEquipment;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @ui00c6a742e0cc.
  ///
  /// In en, this message translates to:
  /// **'Add target'**
  String get ui00c6a742e0cc;

  /// No description provided for @ui045f304ffd6f.
  ///
  /// In en, this message translates to:
  /// **'Sky Atlas'**
  String get ui045f304ffd6f;

  /// No description provided for @ui05283f4ef116.
  ///
  /// In en, this message translates to:
  /// **'No matching projects. Create one or change the status filter.'**
  String get ui05283f4ef116;

  /// No description provided for @ui060be00f4f26.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get ui060be00f4f26;

  /// No description provided for @ui070f29800fa4.
  ///
  /// In en, this message translates to:
  /// **'Detail atlas'**
  String get ui070f29800fa4;

  /// No description provided for @ui0870ffa5afac.
  ///
  /// In en, this message translates to:
  /// **'No account required'**
  String get ui0870ffa5afac;

  /// No description provided for @ui09c473e0718d.
  ///
  /// In en, this message translates to:
  /// **'Add catalog target'**
  String get ui09c473e0718d;

  /// No description provided for @ui0aa49ee559d1.
  ///
  /// In en, this message translates to:
  /// **'Observation sessions'**
  String get ui0aa49ee559d1;

  /// No description provided for @ui0bb3dd21cebe.
  ///
  /// In en, this message translates to:
  /// **'Add an observing location in Settings'**
  String get ui0bb3dd21cebe;

  /// No description provided for @ui0c013daa126c.
  ///
  /// In en, this message translates to:
  /// **'Azimuth step'**
  String get ui0c013daa126c;

  /// No description provided for @ui0f8828658c23.
  ///
  /// In en, this message translates to:
  /// **'Target exceeds the camera field of view.'**
  String get ui0f8828658c23;

  /// No description provided for @ui0fbe28683fff.
  ///
  /// In en, this message translates to:
  /// **'No forecast hour covers the selected observing period.'**
  String get ui0fbe28683fff;

  /// No description provided for @ui11971a7d5ead.
  ///
  /// In en, this message translates to:
  /// **'Weather: no forecast for this date (outside the supported future window).'**
  String get ui11971a7d5ead;

  /// No description provided for @ui11be89f3afd8.
  ///
  /// In en, this message translates to:
  /// **'Visibility windows'**
  String get ui11be89f3afd8;

  /// No description provided for @ui1467b3cadc1f.
  ///
  /// In en, this message translates to:
  /// **'Application preferences'**
  String get ui1467b3cadc1f;

  /// No description provided for @ui172fca63e0c5.
  ///
  /// In en, this message translates to:
  /// **'Delete observing location?'**
  String get ui172fca63e0c5;

  /// No description provided for @ui17b67c89013c.
  ///
  /// In en, this message translates to:
  /// **'Delete observation session?'**
  String get ui17b67c89013c;

  /// No description provided for @ui17c1a0056fed.
  ///
  /// In en, this message translates to:
  /// **'Default observing location'**
  String get ui17c1a0056fed;

  /// No description provided for @ui19a6646d3ca2.
  ///
  /// In en, this message translates to:
  /// **'Panel pointing coordinates'**
  String get ui19a6646d3ca2;

  /// No description provided for @ui1a66e99317f6.
  ///
  /// In en, this message translates to:
  /// **'Back to previous section'**
  String get ui1a66e99317f6;

  /// No description provided for @ui1b16bcb011f7.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get ui1b16bcb011f7;

  /// No description provided for @ui1da9235ef95f.
  ///
  /// In en, this message translates to:
  /// **'Observing coordinates'**
  String get ui1da9235ef95f;

  /// No description provided for @ui1ee9cc3793a0.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get ui1ee9cc3793a0;

  /// No description provided for @ui1f57e3a552f7.
  ///
  /// In en, this message translates to:
  /// **'Mosaic composition'**
  String get ui1f57e3a552f7;

  /// No description provided for @ui1f65eefd7be9.
  ///
  /// In en, this message translates to:
  /// **'Manage observing sites used for astronomical calculations, weather forecasts and imaging recommendations.'**
  String get ui1f65eefd7be9;

  /// No description provided for @ui24345a14377f.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get ui24345a14377f;

  /// No description provided for @ui26c7be81d748.
  ///
  /// In en, this message translates to:
  /// **'You can change all settings later.'**
  String get ui26c7be81d748;

  /// No description provided for @ui27223e3471b9.
  ///
  /// In en, this message translates to:
  /// **'Delete all current AstroManager data?'**
  String get ui27223e3471b9;

  /// No description provided for @ui28fff6e1be6b.
  ///
  /// In en, this message translates to:
  /// **'Delete project?'**
  String get ui28fff6e1be6b;

  /// No description provided for @ui2bd1833871f6.
  ///
  /// In en, this message translates to:
  /// **'Plan date'**
  String get ui2bd1833871f6;

  /// No description provided for @ui2ce5dd0d6f18.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get ui2ce5dd0d6f18;

  /// No description provided for @ui2d8852d6b4bd.
  ///
  /// In en, this message translates to:
  /// **'Compare observing sites'**
  String get ui2d8852d6b4bd;

  /// No description provided for @ui2dd80239e14e.
  ///
  /// In en, this message translates to:
  /// **'Save project'**
  String get ui2dd80239e14e;

  /// No description provided for @ui2fc33582c462.
  ///
  /// In en, this message translates to:
  /// **'Observing Locations'**
  String get ui2fc33582c462;

  /// No description provided for @ui33b2d3f12223.
  ///
  /// In en, this message translates to:
  /// **'Delete and restore'**
  String get ui33b2d3f12223;

  /// No description provided for @ui33c5457fa99c.
  ///
  /// In en, this message translates to:
  /// **'This backup does not include image attachments.'**
  String get ui33c5457fa99c;

  /// No description provided for @ui35015e0d23f1.
  ///
  /// In en, this message translates to:
  /// **'Find suitable celestial targets.'**
  String get ui35015e0d23f1;

  /// No description provided for @ui36155d48f460.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get ui36155d48f460;

  /// No description provided for @ui36b9372eb847.
  ///
  /// In en, this message translates to:
  /// **'No matching observable windows. Try another date, location or target.'**
  String get ui36b9372eb847;

  /// No description provided for @ui39dda2c6ed9c.
  ///
  /// In en, this message translates to:
  /// **'Language preference'**
  String get ui39dda2c6ed9c;

  /// No description provided for @ui3b0ef409e65c.
  ///
  /// In en, this message translates to:
  /// **'Integration unavailable'**
  String get ui3b0ef409e65c;

  /// No description provided for @ui3bdfd0cb3ade.
  ///
  /// In en, this message translates to:
  /// **'No valid camera + optic profiles. Add an imaging setup in Equipment.'**
  String get ui3bdfd0cb3ade;

  /// No description provided for @ui3c275cc70d7a.
  ///
  /// In en, this message translates to:
  /// **'Add an observing location'**
  String get ui3c275cc70d7a;

  /// No description provided for @ui3c692a68d4bc.
  ///
  /// In en, this message translates to:
  /// **'Edit location'**
  String get ui3c692a68d4bc;

  /// No description provided for @ui3d4c90a257e4.
  ///
  /// In en, this message translates to:
  /// **'Keep current data'**
  String get ui3d4c90a257e4;

  /// No description provided for @ui3da474537ac3.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get ui3da474537ac3;

  /// No description provided for @ui3dc434d025d0.
  ///
  /// In en, this message translates to:
  /// **'Light pollution'**
  String get ui3dc434d025d0;

  /// No description provided for @ui3dea13604e7b.
  ///
  /// In en, this message translates to:
  /// **'Select a setup first.'**
  String get ui3dea13604e7b;

  /// No description provided for @ui3ea96ab8636e.
  ///
  /// In en, this message translates to:
  /// **'Center target'**
  String get ui3ea96ab8636e;

  /// No description provided for @ui4025e05099a6.
  ///
  /// In en, this message translates to:
  /// **'Target exceeds frame'**
  String get ui4025e05099a6;

  /// No description provided for @ui4077b1fe737b.
  ///
  /// In en, this message translates to:
  /// **'No valid night-light data at this location.'**
  String get ui4077b1fe737b;

  /// No description provided for @ui41def7a0febe.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get ui41def7a0febe;

  /// No description provided for @ui425a30ac0225.
  ///
  /// In en, this message translates to:
  /// **'Location permission is optional'**
  String get ui425a30ac0225;

  /// No description provided for @ui42c9c9254f7c.
  ///
  /// In en, this message translates to:
  /// **'Show details'**
  String get ui42c9c9254f7c;

  /// No description provided for @ui43ec4c12bba0.
  ///
  /// In en, this message translates to:
  /// **'No observing locations yet.'**
  String get ui43ec4c12bba0;

  /// No description provided for @ui44ccfba93c5d.
  ///
  /// In en, this message translates to:
  /// **'Create a new planned project'**
  String get ui44ccfba93c5d;

  /// No description provided for @ui46ed89cc0f2f.
  ///
  /// In en, this message translates to:
  /// **'Observing location'**
  String get ui46ed89cc0f2f;

  /// No description provided for @ui4730f1e09b8b.
  ///
  /// In en, this message translates to:
  /// **'Merge (no overwrites)'**
  String get ui4730f1e09b8b;

  /// No description provided for @ui47341fdcd55b.
  ///
  /// In en, this message translates to:
  /// **'Calculated position'**
  String get ui47341fdcd55b;

  /// No description provided for @ui481edc32889e.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AstroManager'**
  String get ui481edc32889e;

  /// No description provided for @ui487977828634.
  ///
  /// In en, this message translates to:
  /// **'No setup selected'**
  String get ui487977828634;

  /// No description provided for @ui49b71fc5a2a6.
  ///
  /// In en, this message translates to:
  /// **'Geometric visibility: '**
  String get ui49b71fc5a2a6;

  /// No description provided for @ui4a0fb3757ade.
  ///
  /// In en, this message translates to:
  /// **'Mosaic planner'**
  String get ui4a0fb3757ade;

  /// No description provided for @ui4a25b21b0d6e.
  ///
  /// In en, this message translates to:
  /// **'Add session'**
  String get ui4a25b21b0d6e;

  /// No description provided for @ui4b631f698425.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get ui4b631f698425;

  /// No description provided for @ui4b68bcd5385b.
  ///
  /// In en, this message translates to:
  /// **'DSS2 · CDS · OpenNGC'**
  String get ui4b68bcd5385b;

  /// No description provided for @ui50f94286ba30.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get ui50f94286ba30;

  /// No description provided for @ui52ca48b0e66a.
  ///
  /// In en, this message translates to:
  /// **'Terrain horizon (degrees above horizontal)'**
  String get ui52ca48b0e66a;

  /// No description provided for @ui5301648dcf6b.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get ui5301648dcf6b;

  /// No description provided for @ui53cc51344084.
  ///
  /// In en, this message translates to:
  /// **'Continue without account'**
  String get ui53cc51344084;

  /// No description provided for @ui53e890d5f0ff.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get ui53e890d5f0ff;

  /// No description provided for @ui575f8e577376.
  ///
  /// In en, this message translates to:
  /// **'No mount selected'**
  String get ui575f8e577376;

  /// No description provided for @ui58c7bbeb7619.
  ///
  /// In en, this message translates to:
  /// **'Frame at atlas center'**
  String get ui58c7bbeb7619;

  /// No description provided for @ui5c08cf4e9c00.
  ///
  /// In en, this message translates to:
  /// **'No optical profiles created yet.'**
  String get ui5c08cf4e9c00;

  /// No description provided for @ui5dc7a464a194.
  ///
  /// In en, this message translates to:
  /// **'No astronomical darkness during this night.'**
  String get ui5dc7a464a194;

  /// No description provided for @ui5f64a92ba0ff.
  ///
  /// In en, this message translates to:
  /// **'View in sky atlas'**
  String get ui5f64a92ba0ff;

  /// No description provided for @ui5f9ad5660708.
  ///
  /// In en, this message translates to:
  /// **'Save block'**
  String get ui5f9ad5660708;

  /// No description provided for @ui6043b4bdf9af.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get ui6043b4bdf9af;

  /// No description provided for @ui617742b22795.
  ///
  /// In en, this message translates to:
  /// **'Celestial Object Catalog'**
  String get ui617742b22795;

  /// No description provided for @ui61aaa61c9257.
  ///
  /// In en, this message translates to:
  /// **'Choose how AstroManager looks. Astronomy night mode is designed for use during observing sessions.'**
  String get ui61aaa61c9257;

  /// No description provided for @ui61cc55aa0453.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get ui61cc55aa0453;

  /// No description provided for @ui61d1ea83799f.
  ///
  /// In en, this message translates to:
  /// **'Next morning'**
  String get ui61d1ea83799f;

  /// No description provided for @ui622c745f6090.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get ui622c745f6090;

  /// No description provided for @ui649df08a448e.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get ui649df08a448e;

  /// No description provided for @ui66d110ceb8b1.
  ///
  /// In en, this message translates to:
  /// **'Celestial targets'**
  String get ui66d110ceb8b1;

  /// No description provided for @ui673cf6379550.
  ///
  /// In en, this message translates to:
  /// **'Open the setup guide'**
  String get ui673cf6379550;

  /// No description provided for @ui68cae6be1750.
  ///
  /// In en, this message translates to:
  /// **'Minimum altitude'**
  String get ui68cae6be1750;

  /// No description provided for @ui69bd4ef9fbd0.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get ui69bd4ef9fbd0;

  /// No description provided for @ui6a3a764e8369.
  ///
  /// In en, this message translates to:
  /// **'Set up later'**
  String get ui6a3a764e8369;

  /// No description provided for @ui6a5832ad0336.
  ///
  /// In en, this message translates to:
  /// **'Optional equipment'**
  String get ui6a5832ad0336;

  /// No description provided for @ui6b2f076ce910.
  ///
  /// In en, this message translates to:
  /// **'Setup guide'**
  String get ui6b2f076ce910;

  /// No description provided for @ui6ccbc90af45f.
  ///
  /// In en, this message translates to:
  /// **'24-hour clock'**
  String get ui6ccbc90af45f;

  /// No description provided for @ui6e8d0d74571b.
  ///
  /// In en, this message translates to:
  /// **'Remove mosaic'**
  String get ui6e8d0d74571b;

  /// No description provided for @ui70440046a3dc.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get ui70440046a3dc;

  /// No description provided for @ui704e48190443.
  ///
  /// In en, this message translates to:
  /// **'Show weather'**
  String get ui704e48190443;

  /// No description provided for @ui74d723a22635.
  ///
  /// In en, this message translates to:
  /// **'Observation opportunity alerts'**
  String get ui74d723a22635;

  /// No description provided for @ui74f97baa21c6.
  ///
  /// In en, this message translates to:
  /// **'Sky dome'**
  String get ui74f97baa21c6;

  /// No description provided for @ui77dfd2135f4d.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ui77dfd2135f4d;

  /// No description provided for @ui786033dcc229.
  ///
  /// In en, this message translates to:
  /// **'Refresh terrain profile'**
  String get ui786033dcc229;

  /// No description provided for @ui791f6a42150b.
  ///
  /// In en, this message translates to:
  /// **'Save frame'**
  String get ui791f6a42150b;

  /// No description provided for @ui7b11107ed698.
  ///
  /// In en, this message translates to:
  /// **'Provisional recommendation · incomplete inputs'**
  String get ui7b11107ed698;

  /// No description provided for @ui7d1e9530df6a.
  ///
  /// In en, this message translates to:
  /// **'Terrain horizon'**
  String get ui7d1e9530df6a;

  /// No description provided for @ui7d9252d939e7.
  ///
  /// In en, this message translates to:
  /// **'Equipment Inventory'**
  String get ui7d9252d939e7;

  /// No description provided for @ui7dd375219ee2.
  ///
  /// In en, this message translates to:
  /// **'Manage coordinates, elevation and time zones.'**
  String get ui7dd375219ee2;

  /// No description provided for @ui7e9c7d331b44.
  ///
  /// In en, this message translates to:
  /// **'Add an observing location in Settings to calculate visibility and weather.'**
  String get ui7e9c7d331b44;

  /// No description provided for @ui7f4511910c62.
  ///
  /// In en, this message translates to:
  /// **'Measurement units'**
  String get ui7f4511910c62;

  /// No description provided for @ui7fab3f394f70.
  ///
  /// In en, this message translates to:
  /// **'Outdated forecasts are not treated as favorable conditions.'**
  String get ui7fab3f394f70;

  /// No description provided for @ui808827bfce48.
  ///
  /// In en, this message translates to:
  /// **'Metric (km, m, °C)'**
  String get ui808827bfce48;

  /// No description provided for @ui80fb1d443bf8.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get ui80fb1d443bf8;

  /// No description provided for @ui81b0085421dc.
  ///
  /// In en, this message translates to:
  /// **'Replace all data…'**
  String get ui81b0085421dc;

  /// No description provided for @ui830d75da70e9.
  ///
  /// In en, this message translates to:
  /// **'No equipment selected'**
  String get ui830d75da70e9;

  /// No description provided for @ui869045558929.
  ///
  /// In en, this message translates to:
  /// **'Timeline zoom'**
  String get ui869045558929;

  /// No description provided for @ui86bda4b88b6c.
  ///
  /// In en, this message translates to:
  /// **'Recommended astrophotography targets'**
  String get ui86bda4b88b6c;

  /// No description provided for @ui894a58ab60dc.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get ui894a58ab60dc;

  /// No description provided for @ui89b86ab0e66f.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get ui89b86ab0e66f;

  /// No description provided for @ui8bd28d90f59e.
  ///
  /// In en, this message translates to:
  /// **'Atlas'**
  String get ui8bd28d90f59e;

  /// No description provided for @ui8c7478cc7c8e.
  ///
  /// In en, this message translates to:
  /// **'Save session'**
  String get ui8c7478cc7c8e;

  /// No description provided for @ui8f3bd1539454.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get ui8f3bd1539454;

  /// No description provided for @ui8f554b96bcf9.
  ///
  /// In en, this message translates to:
  /// **'Use Aladin controls'**
  String get ui8f554b96bcf9;

  /// No description provided for @ui8fc6831c6a64.
  ///
  /// In en, this message translates to:
  /// **'Astrophotography projects'**
  String get ui8fc6831c6a64;

  /// No description provided for @ui90e40d504340.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get ui90e40d504340;

  /// No description provided for @ui91b0658329ef.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get ui91b0658329ef;

  /// No description provided for @ui94a2566fc494.
  ///
  /// In en, this message translates to:
  /// **'Interactive night timeline'**
  String get ui94a2566fc494;

  /// No description provided for @ui969f7db05af0.
  ///
  /// In en, this message translates to:
  /// **'Add an observing location in Settings to plan a night.'**
  String get ui969f7db05af0;

  /// No description provided for @ui9832a3af6228.
  ///
  /// In en, this message translates to:
  /// **'Delete location'**
  String get ui9832a3af6228;

  /// No description provided for @ui9950fdb3ff36.
  ///
  /// In en, this message translates to:
  /// **'Hide Aladin controls'**
  String get ui9950fdb3ff36;

  /// No description provided for @ui9b9040010710.
  ///
  /// In en, this message translates to:
  /// **'Enable opportunity notifications'**
  String get ui9b9040010710;

  /// No description provided for @ui9d8d3808063b.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get ui9d8d3808063b;

  /// No description provided for @ui9f0d29b85777.
  ///
  /// In en, this message translates to:
  /// **'The selected appearance is saved automatically and restored at startup.'**
  String get ui9f0d29b85777;

  /// No description provided for @ui9f5cd8a2e880.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get ui9f5cd8a2e880;

  /// No description provided for @uia0252af29582.
  ///
  /// In en, this message translates to:
  /// **'Export coordinates'**
  String get uia0252af29582;

  /// No description provided for @uia0aea5917b87.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get uia0aea5917b87;

  /// No description provided for @uia16162846d0f.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get uia16162846d0f;

  /// No description provided for @uia16c5bbe4bf9.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get uia16c5bbe4bf9;

  /// No description provided for @uia21573df2689.
  ///
  /// In en, this message translates to:
  /// **'Weather forecast available on request.'**
  String get uia21573df2689;

  /// No description provided for @uia22108965948.
  ///
  /// In en, this message translates to:
  /// **'View in atlas'**
  String get uia22108965948;

  /// No description provided for @uia2d09bb94d15.
  ///
  /// In en, this message translates to:
  /// **'New target alert'**
  String get uia2d09bb94d15;

  /// No description provided for @uia48940ba0bcd.
  ///
  /// In en, this message translates to:
  /// **'Larger file; attachments stay outside SQLite.'**
  String get uia48940ba0bcd;

  /// No description provided for @uia646e7421988.
  ///
  /// In en, this message translates to:
  /// **'Include session images'**
  String get uia646e7421988;

  /// No description provided for @uia65eaa8807ce.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get uia65eaa8807ce;

  /// No description provided for @uia733b809d2f1.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get uia733b809d2f1;

  /// No description provided for @uia8c1255a61f5.
  ///
  /// In en, this message translates to:
  /// **'Back to Settings'**
  String get uia8c1255a61f5;

  /// No description provided for @uia934498ee820.
  ///
  /// In en, this message translates to:
  /// **'You can enter coordinates manually. Location permission is requested only if you choose to use device positioning.'**
  String get uia934498ee820;

  /// No description provided for @uia9ffd48761d4.
  ///
  /// In en, this message translates to:
  /// **'Astronomical darkness · observing night'**
  String get uia9ffd48761d4;

  /// No description provided for @uiaaef230d053a.
  ///
  /// In en, this message translates to:
  /// **'Target details'**
  String get uiaaef230d053a;

  /// No description provided for @uiab11392eecc8.
  ///
  /// In en, this message translates to:
  /// **'Create Optical Profile'**
  String get uiab11392eecc8;

  /// No description provided for @uiabb54c80e94a.
  ///
  /// In en, this message translates to:
  /// **'Weather unavailable; observation planning works offline.'**
  String get uiabb54c80e94a;

  /// No description provided for @uiabe1abeac3f9.
  ///
  /// In en, this message translates to:
  /// **'Camera framing saved'**
  String get uiabe1abeac3f9;

  /// No description provided for @uiacb5dcfa25cf.
  ///
  /// In en, this message translates to:
  /// **'Tap to schedule a target'**
  String get uiacb5dcfa25cf;

  /// No description provided for @uiadff506ca880.
  ///
  /// In en, this message translates to:
  /// **'Configure measurement units and time display.'**
  String get uiadff506ca880;

  /// No description provided for @uiafda4861e62e.
  ///
  /// In en, this message translates to:
  /// **'Dome'**
  String get uiafda4861e62e;

  /// No description provided for @uib14c2bdab7ea.
  ///
  /// In en, this message translates to:
  /// **'Add observing location'**
  String get uib14c2bdab7ea;

  /// No description provided for @uib7000d56da11.
  ///
  /// In en, this message translates to:
  /// **'Sky atlas'**
  String get uib7000d56da11;

  /// No description provided for @uib724a7ee9877.
  ///
  /// In en, this message translates to:
  /// **'Lunar conditions · observing night'**
  String get uib724a7ee9877;

  /// No description provided for @uib74bdee9c34f.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get uib74bdee9c34f;

  /// No description provided for @uib88fd9c31c88.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on this device. No account or registration is required.'**
  String get uib88fd9c31c88;

  /// No description provided for @uib9c17d38393b.
  ///
  /// In en, this message translates to:
  /// **'Favorites only'**
  String get uib9c17d38393b;

  /// No description provided for @uibb701e1d5144.
  ///
  /// In en, this message translates to:
  /// **'Observing'**
  String get uibb701e1d5144;

  /// No description provided for @uibbfa773e5a63.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get uibbfa773e5a63;

  /// No description provided for @uibc981983e7f5.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get uibc981983e7f5;

  /// No description provided for @uibcc3ee5b9b23.
  ///
  /// In en, this message translates to:
  /// **'The session and its attached images will be deleted.'**
  String get uibcc3ee5b9b23;

  /// No description provided for @uibcf701be5725.
  ///
  /// In en, this message translates to:
  /// **'System notifications are unavailable on this platform.'**
  String get uibcf701be5725;

  /// No description provided for @uibd800ea1019b.
  ///
  /// In en, this message translates to:
  /// **'Create an observing site so local sky calculations use accurate coordinates and time zones.'**
  String get uibd800ea1019b;

  /// No description provided for @uibea543e35c09.
  ///
  /// In en, this message translates to:
  /// **'Online refresh failed; showing a cached reading.'**
  String get uibea543e35c09;

  /// No description provided for @uibff3b84703d3.
  ///
  /// In en, this message translates to:
  /// **'No observation sessions recorded yet.'**
  String get uibff3b84703d3;

  /// No description provided for @uic19156a46b86.
  ///
  /// In en, this message translates to:
  /// **'Use terrain horizon'**
  String get uic19156a46b86;

  /// No description provided for @uic238c91fb1c5.
  ///
  /// In en, this message translates to:
  /// **'UTC date'**
  String get uic238c91fb1c5;

  /// No description provided for @uic2832ecacf0b.
  ///
  /// In en, this message translates to:
  /// **'12-hour clock (AM/PM)'**
  String get uic2832ecacf0b;

  /// No description provided for @uic4e10bae35e6.
  ///
  /// In en, this message translates to:
  /// **'Project unavailable'**
  String get uic4e10bae35e6;

  /// No description provided for @uic5928f418aec.
  ///
  /// In en, this message translates to:
  /// **'Select at least two saved locations.'**
  String get uic5928f418aec;

  /// No description provided for @uic6a037b6db1c.
  ///
  /// In en, this message translates to:
  /// **'Save mosaic'**
  String get uic6a037b6db1c;

  /// No description provided for @uic7f73bb54d92.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get uic7f73bb54d92;

  /// No description provided for @uic80e16108340.
  ///
  /// In en, this message translates to:
  /// **'No setup'**
  String get uic80e16108340;

  /// No description provided for @uic877cbb0e805.
  ///
  /// In en, this message translates to:
  /// **'App name'**
  String get uic877cbb0e805;

  /// No description provided for @uic999c3b97e35.
  ///
  /// In en, this message translates to:
  /// **'Evening (night date)'**
  String get uic999c3b97e35;

  /// No description provided for @uica4f9dcf204e.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get uica4f9dcf204e;

  /// No description provided for @uiccc10c286211.
  ///
  /// In en, this message translates to:
  /// **'Search Messier, NGC and IC objects'**
  String get uiccc10c286211;

  /// No description provided for @uiccd63d8a2ab7.
  ///
  /// In en, this message translates to:
  /// **'Satellite night lights'**
  String get uiccd63d8a2ab7;

  /// No description provided for @uicdd7bb2816b7.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get uicdd7bb2816b7;

  /// No description provided for @uicefd33736d52.
  ///
  /// In en, this message translates to:
  /// **'GPS coordinates and elevation may be inaccurate.'**
  String get uicefd33736d52;

  /// No description provided for @uicf1b14e91ae9.
  ///
  /// In en, this message translates to:
  /// **'Center frame'**
  String get uicf1b14e91ae9;

  /// No description provided for @uicf1c486c7507.
  ///
  /// In en, this message translates to:
  /// **'Add a camera, optics and mount later in Equipment to calculate accurate framing and mosaics.'**
  String get uicf1c486c7507;

  /// No description provided for @uid0574e8b9721.
  ///
  /// In en, this message translates to:
  /// **'Reasons and scoring details'**
  String get uid0574e8b9721;

  /// No description provided for @uid0b22c91a705.
  ///
  /// In en, this message translates to:
  /// **'Permission is requested only when enabling.'**
  String get uid0b22c91a705;

  /// No description provided for @uid35260a00f65.
  ///
  /// In en, this message translates to:
  /// **'Targets'**
  String get uid35260a00f65;

  /// No description provided for @uid374bd2e1c9a.
  ///
  /// In en, this message translates to:
  /// **'Moonlight conditions'**
  String get uid374bd2e1c9a;

  /// No description provided for @uid3942d236715.
  ///
  /// In en, this message translates to:
  /// **'No integration target set; all usable time is still tracked.'**
  String get uid3942d236715;

  /// No description provided for @uid49161f69125.
  ///
  /// In en, this message translates to:
  /// **'No targets assigned. Use Edit to add a catalog target.'**
  String get uid49161f69125;

  /// No description provided for @uid5f56b122ede.
  ///
  /// In en, this message translates to:
  /// **'No matching celestial objects.'**
  String get uid5f56b122ede;

  /// No description provided for @uid619f9b2e034.
  ///
  /// In en, this message translates to:
  /// **'No equipment yet. Add a camera, lens, telescope or mount.'**
  String get uid619f9b2e034;

  /// No description provided for @uid87f47b47e4d.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get uid87f47b47e4d;

  /// No description provided for @uid88966393d5b.
  ///
  /// In en, this message translates to:
  /// **'Radial step'**
  String get uid88966393d5b;

  /// No description provided for @uid9074210f303.
  ///
  /// In en, this message translates to:
  /// **'Check satellite data'**
  String get uid9074210f303;

  /// No description provided for @uid94e8bb0897a.
  ///
  /// In en, this message translates to:
  /// **'Set up equipment'**
  String get uid94e8bb0897a;

  /// No description provided for @uida461330cb4a.
  ///
  /// In en, this message translates to:
  /// **'Schedule target'**
  String get uida461330cb4a;

  /// No description provided for @uida91388c72d3.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get uida91388c72d3;

  /// No description provided for @uidadd6ac5ba02.
  ///
  /// In en, this message translates to:
  /// **'Data sources'**
  String get uidadd6ac5ba02;

  /// No description provided for @uidb47869ced8c.
  ///
  /// In en, this message translates to:
  /// **'Observing locations'**
  String get uidb47869ced8c;

  /// No description provided for @uidc874e99dd60.
  ///
  /// In en, this message translates to:
  /// **'Catalog targets'**
  String get uidc874e99dd60;

  /// No description provided for @uidf8258556c68.
  ///
  /// In en, this message translates to:
  /// **'Add an observing location to display the local horizon.'**
  String get uidf8258556c68;

  /// No description provided for @uie1b1390ce05d.
  ///
  /// In en, this message translates to:
  /// **'Restore frame'**
  String get uie1b1390ce05d;

  /// No description provided for @uie319b82cf795.
  ///
  /// In en, this message translates to:
  /// **'Calculating terrain horizon (online fetch or local cache)…'**
  String get uie319b82cf795;

  /// No description provided for @uie3318c6b879b.
  ///
  /// In en, this message translates to:
  /// **'Add alert'**
  String get uie3318c6b879b;

  /// No description provided for @uie3b82040565b.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get uie3b82040565b;

  /// No description provided for @uie424945cf483.
  ///
  /// In en, this message translates to:
  /// **'Target visibility · observing night'**
  String get uie424945cf483;

  /// No description provided for @uie53e762e5697.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get uie53e762e5697;

  /// No description provided for @uie5bcbe241fab.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get uie5bcbe241fab;

  /// No description provided for @uie6d945634566.
  ///
  /// In en, this message translates to:
  /// **'Compare selected sites'**
  String get uie6d945634566;

  /// No description provided for @uie7cb810b7b0d.
  ///
  /// In en, this message translates to:
  /// **'Delete mosaic plan?'**
  String get uie7cb810b7b0d;

  /// No description provided for @uie89ded5b6204.
  ///
  /// In en, this message translates to:
  /// **'Night Planner'**
  String get uie89ded5b6204;

  /// No description provided for @uie9eaa2e607f7.
  ///
  /// In en, this message translates to:
  /// **'Open atlas'**
  String get uie9eaa2e607f7;

  /// No description provided for @uiefc007a393f6.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get uiefc007a393f6;

  /// No description provided for @uif21945bfa929.
  ///
  /// In en, this message translates to:
  /// **'Restore AstroManager backup?'**
  String get uif21945bfa929;

  /// No description provided for @uif32345f724f6.
  ///
  /// In en, this message translates to:
  /// **'Add your first observing location to get started.'**
  String get uif32345f724f6;

  /// No description provided for @uif3df390fda9b.
  ///
  /// In en, this message translates to:
  /// **'UTC time'**
  String get uif3df390fda9b;

  /// No description provided for @uif64528fd73a3.
  ///
  /// In en, this message translates to:
  /// **'Your astrophotography planning dashboard.'**
  String get uif64528fd73a3;

  /// No description provided for @uif6fdbe48dc54.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get uif6fdbe48dc54;

  /// No description provided for @uif7b0d2b66b40.
  ///
  /// In en, this message translates to:
  /// **'Loading celestial catalog...'**
  String get uif7b0d2b66b40;

  /// No description provided for @uif8341f218419.
  ///
  /// In en, this message translates to:
  /// **'Optical Profiles'**
  String get uif8341f218419;

  /// No description provided for @uif85359df0751.
  ///
  /// In en, this message translates to:
  /// **'Target may require rotation or a wider field of view.'**
  String get uif85359df0751;

  /// No description provided for @uif8c24833126b.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get uif8c24833126b;

  /// No description provided for @uif8c692e3e700.
  ///
  /// In en, this message translates to:
  /// **'Imperial (mi, ft, °F)'**
  String get uif8c692e3e700;

  /// No description provided for @uif96e47c2a5c6.
  ///
  /// In en, this message translates to:
  /// **'Usable integration: '**
  String get uif96e47c2a5c6;

  /// No description provided for @uifa55fdfefafe.
  ///
  /// In en, this message translates to:
  /// **'Delete block'**
  String get uifa55fdfefafe;

  /// No description provided for @uifd7108f8312a.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get uifd7108f8312a;

  /// No description provided for @uiffc77a8af8e4.
  ///
  /// In en, this message translates to:
  /// **'No mosaic planned for this project.'**
  String get uiffc77a8af8e4;

  /// No description provided for @ui6afa3a9d429d.
  ///
  /// In en, this message translates to:
  /// **'Add an observing location in Settings to calculate altitude and azimuth.'**
  String get ui6afa3a9d429d;

  /// No description provided for @ui200a3b6f9cb1.
  ///
  /// In en, this message translates to:
  /// **'Add at least one camera and one lens or telescope to create a profile.'**
  String get ui200a3b6f9cb1;

  /// No description provided for @uief2a04a57547.
  ///
  /// In en, this message translates to:
  /// **'Angular separation includes lunar topocentric parallax. Brightness and skyglow depend on atmospheric conditions; separation alone is not a suitability rating.'**
  String get uief2a04a57547;

  /// No description provided for @uiaf2b6f5829de.
  ///
  /// In en, this message translates to:
  /// **'Approximate terrain-only horizon: buildings, trees and small obstacles are excluded. This is not a guaranteed line-of-sight prediction.'**
  String get uiaf2b6f5829de;

  /// No description provided for @uib946912b74ae.
  ///
  /// In en, this message translates to:
  /// **'Atlas framing adjustments are previews; edit the project mosaic to save them.'**
  String get uib946912b74ae;

  /// No description provided for @ui92c6d9016973.
  ///
  /// In en, this message translates to:
  /// **'Attach image'**
  String get ui92c6d9016973;

  /// No description provided for @ui19f297bdf569.
  ///
  /// In en, this message translates to:
  /// **'Catalog object not found — reference retained'**
  String get ui19f297bdf569;

  /// No description provided for @uid04f0335165e.
  ///
  /// In en, this message translates to:
  /// **'Catalog unavailable — saved identifier retained'**
  String get uid04f0335165e;

  /// No description provided for @uie95db36d55c9.
  ///
  /// In en, this message translates to:
  /// **'Catalog: OpenNGC · Weather: Open-Meteo where available. Scores are heuristic, not guaranteed imaging outcomes. A maximum of 24 candidates is evaluated per search.'**
  String get uie95db36d55c9;

  /// No description provided for @ui9d39a5a8561f.
  ///
  /// In en, this message translates to:
  /// **'Choose at least two sites, one project target, and a common local calendar date. Weather and terrain data are requested only when you run the comparison.'**
  String get ui9d39a5a8561f;

  /// No description provided for @uia1fe707ecd6d.
  ///
  /// In en, this message translates to:
  /// **'Create a camera + optic profile in Equipment to enable framing.'**
  String get uia1fe707ecd6d;

  /// No description provided for @ui96d27f5f02a2.
  ///
  /// In en, this message translates to:
  /// **'Create an imaging project with a catalog target before comparing sites.'**
  String get ui96d27f5f02a2;

  /// No description provided for @uiab96936180ea.
  ///
  /// In en, this message translates to:
  /// **'Create an imaging project with a target to schedule observing blocks.'**
  String get uiab96936180ea;

  /// No description provided for @uicff73e542e03.
  ///
  /// In en, this message translates to:
  /// **'Create an imaging setup in Equipment.'**
  String get uicff73e542e03;

  /// No description provided for @ui9636239b94de.
  ///
  /// In en, this message translates to:
  /// **'DSS2 Color: Digitized Sky Survey (STScI/NASA), colour HiPS by CDS. HiPS mirror: ESA. Viewer: Aladin Lite (CDS). Object catalog: OpenNGC (CC BY-SA 4.0).'**
  String get ui9636239b94de;

  /// No description provided for @ui1f538388bf6d.
  ///
  /// In en, this message translates to:
  /// **'Displaying the first 12 linked target altitude tracks.'**
  String get ui1f538388bf6d;

  /// No description provided for @ui9ffe7e417419.
  ///
  /// In en, this message translates to:
  /// **'E · 90°'**
  String get ui9ffe7e417419;

  /// No description provided for @ui4c7644985aa0.
  ///
  /// In en, this message translates to:
  /// **'N · 0°'**
  String get ui4c7644985aa0;

  /// No description provided for @ui1c87ede4da8d.
  ///
  /// In en, this message translates to:
  /// **'N · 360°'**
  String get ui1c87ede4da8d;

  /// No description provided for @ui7cadd4c5d829.
  ///
  /// In en, this message translates to:
  /// **'S · 180°'**
  String get ui7cadd4c5d829;

  /// No description provided for @uie24e6af7a656.
  ///
  /// In en, this message translates to:
  /// **'W · 270°'**
  String get uie24e6af7a656;

  /// No description provided for @ui32ed4e09aba6.
  ///
  /// In en, this message translates to:
  /// **'Embedded Aladin Lite is supported on Web, Android, iOS and macOS. On Windows/Linux, open the AstroManager web app in a browser.'**
  String get ui32ed4e09aba6;

  /// No description provided for @ui8c4d6c3b3d5e.
  ///
  /// In en, this message translates to:
  /// **'Embedded sky atlas is not supported on this platform.'**
  String get ui8c4d6c3b3d5e;

  /// No description provided for @uib51b6070e0fe.
  ///
  /// In en, this message translates to:
  /// **'FoV fit is a conservative 0° orientation estimate; check rotation in Sky Atlas.'**
  String get uib51b6070e0fe;

  /// No description provided for @uic04bf688d925.
  ///
  /// In en, this message translates to:
  /// **'GPS coordinates and elevation may be approximate. Verify the time zone manually.'**
  String get uic04bf688d925;

  /// No description provided for @ui579b14a71fd0.
  ///
  /// In en, this message translates to:
  /// **'Geometric altitude over the observing night; shaded periods have astronomical darkness.'**
  String get ui579b14a71fd0;

  /// No description provided for @uicfa6278ac7d1.
  ///
  /// In en, this message translates to:
  /// **'Geometric position using mean sidereal time. Atmospheric refraction, local obstructions, nutation and proper motion are not included.'**
  String get uicfa6278ac7d1;

  /// No description provided for @ui29da2469366e.
  ///
  /// In en, this message translates to:
  /// **'Green: horizon · Yellow: minimum altitude'**
  String get ui29da2469366e;

  /// No description provided for @ui377f4fcb692a.
  ///
  /// In en, this message translates to:
  /// **'Heuristic suitability, not a guarantee of visibility or image quality. Date refers to each site’s local observing night.'**
  String get ui377f4fcb692a;

  /// No description provided for @uic3f00619e69c.
  ///
  /// In en, this message translates to:
  /// **'ICRS/J2000 planning geometry; account separately for field rotation, distortion, framing margins and mount limits.'**
  String get uic3f00619e69c;

  /// No description provided for @ui5772af2d5534.
  ///
  /// In en, this message translates to:
  /// **'Imaging plan'**
  String get ui5772af2d5534;

  /// No description provided for @ui557caacbcc47.
  ///
  /// In en, this message translates to:
  /// **'Incomplete DEM coverage: visibility is uncertain at missing bearings.'**
  String get ui557caacbcc47;

  /// No description provided for @ui466fc492747c.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get ui466fc492747c;

  /// No description provided for @ui3acadcbacf68.
  ///
  /// In en, this message translates to:
  /// **'Loading integration…'**
  String get ui3acadcbacf68;

  /// No description provided for @uicbd907af6e51.
  ///
  /// In en, this message translates to:
  /// **'Loading observing locations...'**
  String get uicbd907af6e51;

  /// No description provided for @ui98c24a2a8357.
  ///
  /// In en, this message translates to:
  /// **'Loading project targets...'**
  String get ui98c24a2a8357;

  /// No description provided for @uie01b341d66a5.
  ///
  /// In en, this message translates to:
  /// **'Loading weather forecast…'**
  String get uie01b341d66a5;

  /// No description provided for @uiedd4f7e4bb90.
  ///
  /// In en, this message translates to:
  /// **'Local noon to next noon; Sun below −18°. Geometric altitude without terrain or atmospheric refraction.'**
  String get uiedd4f7e4bb90;

  /// No description provided for @uidfbfa079b9b3.
  ///
  /// In en, this message translates to:
  /// **'Local noon → next local noon · scroll horizontally to inspect the full night.'**
  String get uidfbfa079b9b3;

  /// No description provided for @uibfce6bfa7f21.
  ///
  /// In en, this message translates to:
  /// **'Manage your imaging equipment and create reusable optical setups.'**
  String get uibfce6bfa7f21;

  /// No description provided for @ui2ddd74e2da32.
  ///
  /// In en, this message translates to:
  /// **'Mean equatorial coordinates of date'**
  String get ui2ddd74e2da32;

  /// No description provided for @ui9fc0b5950ae8.
  ///
  /// In en, this message translates to:
  /// **'Merge retains existing records and rejects duplicate identifiers. Replace removes all existing user data before restoring the backup.'**
  String get ui9fc0b5950ae8;

  /// No description provided for @ui2ef3f5144e2f.
  ///
  /// In en, this message translates to:
  /// **'Moonrise / moonset · noon-to-noon window'**
  String get ui2ef3f5144e2f;

  /// No description provided for @uia81fbcbd890d.
  ///
  /// In en, this message translates to:
  /// **'No matching celestial objects. Try another name or catalog number.'**
  String get uia81fbcbd890d;

  /// No description provided for @ui4c4fb2c9338e.
  ///
  /// In en, this message translates to:
  /// **'No matching observable windows. Try another date, a lower altitude, a shorter session or another target.'**
  String get ui4c4fb2c9338e;

  /// No description provided for @ui1622af53dbaf.
  ///
  /// In en, this message translates to:
  /// **'No observing location. Add one in Settings to discover targets.'**
  String get ui1622af53dbaf;

  /// No description provided for @ui01c73659161b.
  ///
  /// In en, this message translates to:
  /// **'No valid night-light data at this location. No darkness classification is inferred.'**
  String get ui01c73659161b;

  /// No description provided for @ui183079f3bd54.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get ui183079f3bd54;

  /// No description provided for @uicb8fe4639653.
  ///
  /// In en, this message translates to:
  /// **'Not selected (UTC)'**
  String get uicb8fe4639653;

  /// No description provided for @ui51dcf306134f.
  ///
  /// In en, this message translates to:
  /// **'Optional forecast-based alerts. Checks run when the app starts, returns to the foreground or when you tap Check now. No continuous background monitoring is provided.'**
  String get ui51dcf306134f;

  /// No description provided for @ui8e53b9014f94.
  ///
  /// In en, this message translates to:
  /// **'Overlapping blocks are flagged on the timeline. Times are saved as UTC instants.'**
  String get ui8e53b9014f94;

  /// No description provided for @uif23b4e42ebae.
  ///
  /// In en, this message translates to:
  /// **'Plan your upcoming astrophotography sessions.'**
  String get uif23b4e42ebae;

  /// No description provided for @ui9ca2556e9384.
  ///
  /// In en, this message translates to:
  /// **'Portable .ambackup files contain a ZIP archive and work offline. Backups are not encrypted; store them securely. Older .zip backups can also be restored. The bundled celestial catalog is not included.'**
  String get ui9ca2556e9384;

  /// No description provided for @ui7cbe01fed272.
  ///
  /// In en, this message translates to:
  /// **'Ranked for your observing night. Only continuous dark, visible windows meeting the minimum duration are recommended.'**
  String get ui7cbe01fed272;

  /// No description provided for @ui3cbe6d6b9a8d.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get ui3cbe6d6b9a8d;

  /// No description provided for @uib02dd9f372d0.
  ///
  /// In en, this message translates to:
  /// **'Save as project'**
  String get uib02dd9f372d0;

  /// No description provided for @ui70f9cb9ef266.
  ///
  /// In en, this message translates to:
  /// **'Search Messier, NGC and IC objects, common names and other identifiers.'**
  String get ui70f9cb9ef266;

  /// No description provided for @uicb667ede4bff.
  ///
  /// In en, this message translates to:
  /// **'Setup unavailable'**
  String get uicb667ede4bff;

  /// No description provided for @uic4637f3360f4.
  ///
  /// In en, this message translates to:
  /// **'Solar positions are approximate. Sunrise/sunset assumes an unobstructed sea-level horizon and standard refraction. Mountain ridges, weather and artificial light are not included.'**
  String get uic4637f3360f4;

  /// No description provided for @ui67cfc8ef10a1.
  ///
  /// In en, this message translates to:
  /// **'Source: OpenNGC (CC BY-SA 4.0). Positions are geometric planning estimates; local terrain and atmospheric refraction are not modeled.'**
  String get ui67cfc8ef10a1;

  /// No description provided for @ui45e2ba6f58ac.
  ///
  /// In en, this message translates to:
  /// **'Source: OpenNGC · CC BY-SA 4.0\\nEquatorial coordinates: J2000\\nMagnitude: Johnson V, where available'**
  String get ui45e2ba6f58ac;

  /// No description provided for @uia17912e81318.
  ///
  /// In en, this message translates to:
  /// **'Sun below −18°; evaluated from local noon through the following local noon. Intervals can span midnight.'**
  String get uia17912e81318;

  /// No description provided for @ui60877c579854.
  ///
  /// In en, this message translates to:
  /// **'System notifications are unavailable on this platform. Alert rules remain editable for Android/iOS.'**
  String get ui60877c579854;

  /// No description provided for @uid372a1754cfc.
  ///
  /// In en, this message translates to:
  /// **'Tap a scheduled bar to edit or remove it. Adjacent blocks do not conflict.'**
  String get uid372a1754cfc;

  /// No description provided for @uibbcf9cc9545d.
  ///
  /// In en, this message translates to:
  /// **'Target saved to planned projects.'**
  String get uibbcf9cc9545d;

  /// No description provided for @uibce78604878d.
  ///
  /// In en, this message translates to:
  /// **'Terrain elevation unavailable. Existing geometric visibility remains active. Try again when connected; previous night plans are not affected.'**
  String get uibce78604878d;

  /// No description provided for @uia250df8b8b23.
  ///
  /// In en, this message translates to:
  /// **'The AstroManager controls remain available.'**
  String get uia250df8b8b23;

  /// No description provided for @uid1e1a0629525.
  ///
  /// In en, this message translates to:
  /// **'This removes only the mosaic composition, not the project.'**
  String get uid1e1a0629525;

  /// No description provided for @ui720f457fbb75.
  ///
  /// In en, this message translates to:
  /// **'This will replace existing locations, equipment, imaging projects, sessions, night plans and preferences. It cannot be undone. Export your current data first.'**
  String get ui720f457fbb75;

  /// No description provided for @ui183dfe8735d3.
  ///
  /// In en, this message translates to:
  /// **'Unable to save theme preference.'**
  String get ui183dfe8735d3;

  /// No description provided for @ui688741deabd8.
  ///
  /// In en, this message translates to:
  /// **'Upward radiance is not a sky brightness measurement. Nearby lights, terrain, cloud, snow and atmospheric scattering can change actual observing conditions.'**
  String get ui688741deabd8;

  /// No description provided for @ui1b195062efd6.
  ///
  /// In en, this message translates to:
  /// **'Use either ISO or gain; leave the other empty.'**
  String get ui1b195062efd6;

  /// No description provided for @ui0ad4bdc56a6f.
  ///
  /// In en, this message translates to:
  /// **'Show Aladin controls'**
  String get ui0ad4bdc56a6f;

  /// No description provided for @ui9cac3589cec6.
  ///
  /// In en, this message translates to:
  /// **'Location name'**
  String get ui9cac3589cec6;

  /// No description provided for @ui26a68a1776c0.
  ///
  /// In en, this message translates to:
  /// **'Latitude (degrees)'**
  String get ui26a68a1776c0;

  /// No description provided for @ui61c1be517cef.
  ///
  /// In en, this message translates to:
  /// **'Longitude (degrees)'**
  String get ui61c1be517cef;

  /// No description provided for @uif3540ebbbe1d.
  ///
  /// In en, this message translates to:
  /// **'Elevation (meters)'**
  String get uif3540ebbbe1d;

  /// No description provided for @ui6ff3da73b427.
  ///
  /// In en, this message translates to:
  /// **'IANA time zone'**
  String get ui6ff3da73b427;

  /// No description provided for @ui18eef9905556.
  ///
  /// In en, this message translates to:
  /// **'Use the time zone of the observing site.'**
  String get ui18eef9905556;

  /// No description provided for @uic7aeccacfe38.
  ///
  /// In en, this message translates to:
  /// **'e.g. Home Observatory'**
  String get uic7aeccacfe38;

  /// No description provided for @ui42d343d45ade.
  ///
  /// In en, this message translates to:
  /// **'Project target'**
  String get ui42d343d45ade;

  /// No description provided for @ui9abad00a227b.
  ///
  /// In en, this message translates to:
  /// **'Imaging setup'**
  String get ui9abad00a227b;

  /// No description provided for @ui52d0b35277ee.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get ui52d0b35277ee;

  /// No description provided for @uicf723c59b62a.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get uicf723c59b62a;

  /// No description provided for @ui4da9c9af9631.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get ui4da9c9af9631;

  /// No description provided for @uifb1cf0b12af6.
  ///
  /// In en, this message translates to:
  /// **'Optics'**
  String get uifb1cf0b12af6;

  /// No description provided for @ui25ee09590909.
  ///
  /// In en, this message translates to:
  /// **'Mount'**
  String get ui25ee09590909;

  /// No description provided for @uid7decf1aa22b.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get uid7decf1aa22b;

  /// No description provided for @uid3668d0d768f.
  ///
  /// In en, this message translates to:
  /// **'Camera sensor'**
  String get uid3668d0d768f;

  /// No description provided for @ui4f325d995b6d.
  ///
  /// In en, this message translates to:
  /// **'ISO'**
  String get ui4f325d995b6d;

  /// No description provided for @ui96dd91cdcbe7.
  ///
  /// In en, this message translates to:
  /// **'Gain'**
  String get ui96dd91cdcbe7;

  /// No description provided for @uie1daf60163ab.
  ///
  /// In en, this message translates to:
  /// **'Total frames'**
  String get uie1daf60163ab;

  /// No description provided for @ui61a0572c4893.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get ui61a0572c4893;

  /// No description provided for @ui3add7443e812.
  ///
  /// In en, this message translates to:
  /// **'Rejected frames'**
  String get ui3add7443e812;

  /// No description provided for @uia84ff7c31b9b.
  ///
  /// In en, this message translates to:
  /// **'Session notes'**
  String get uia84ff7c31b9b;

  /// No description provided for @ui61cbc867da75.
  ///
  /// In en, this message translates to:
  /// **'Frame count'**
  String get ui61cbc867da75;

  /// No description provided for @uid96c310c0a5d.
  ///
  /// In en, this message translates to:
  /// **'Exposure per frame (seconds) *'**
  String get uid96c310c0a5d;

  /// No description provided for @ui8e52d1dd2047.
  ///
  /// In en, this message translates to:
  /// **'New observation session'**
  String get ui8e52d1dd2047;

  /// No description provided for @ui1fdfa6255cdf.
  ///
  /// In en, this message translates to:
  /// **'Edit observation session'**
  String get ui1fdfa6255cdf;

  /// No description provided for @ui290df83aff99.
  ///
  /// In en, this message translates to:
  /// **'Codefrog light'**
  String get ui290df83aff99;

  /// No description provided for @uif1320b0de6a6.
  ///
  /// In en, this message translates to:
  /// **'Codefrog dark'**
  String get uif1320b0de6a6;

  /// No description provided for @uid5b715dec088.
  ///
  /// In en, this message translates to:
  /// **'Astronomy night'**
  String get uid5b715dec088;

  /// No description provided for @uiefb21777d000.
  ///
  /// In en, this message translates to:
  /// **'Automatically follow your device appearance.'**
  String get uiefb21777d000;

  /// No description provided for @ui2a20a2398b98.
  ///
  /// In en, this message translates to:
  /// **'Bright surfaces with Codefrog green accents.'**
  String get ui2a20a2398b98;

  /// No description provided for @uicda964a692bc.
  ///
  /// In en, this message translates to:
  /// **'Dark Codefrog design with green highlights.'**
  String get uicda964a692bc;

  /// No description provided for @uid252087f82dc.
  ///
  /// In en, this message translates to:
  /// **'Dark surfaces and red lighting for observations.'**
  String get uid252087f82dc;

  /// No description provided for @uib52b36b7269f.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get uib52b36b7269f;

  /// No description provided for @ui3dfce0897065.
  ///
  /// In en, this message translates to:
  /// **'Data sources & credits'**
  String get ui3dfce0897065;

  /// No description provided for @uid8d5d1c30750.
  ///
  /// In en, this message translates to:
  /// **'Move frame west'**
  String get uid8d5d1c30750;

  /// No description provided for @ui73d14320dba1.
  ///
  /// In en, this message translates to:
  /// **'Move frame east'**
  String get ui73d14320dba1;

  /// No description provided for @ui34947da339e5.
  ///
  /// In en, this message translates to:
  /// **'Move frame north'**
  String get ui34947da339e5;

  /// No description provided for @ui4eaf80309310.
  ///
  /// In en, this message translates to:
  /// **'Move frame south'**
  String get ui4eaf80309310;

  /// No description provided for @ui650c599a8907.
  ///
  /// In en, this message translates to:
  /// **'Move framing west'**
  String get ui650c599a8907;

  /// No description provided for @uid2582f1fc224.
  ///
  /// In en, this message translates to:
  /// **'Move framing east'**
  String get uid2582f1fc224;

  /// No description provided for @uibc2cb76b1c25.
  ///
  /// In en, this message translates to:
  /// **'Move framing north'**
  String get uibc2cb76b1c25;

  /// No description provided for @ui13009e218f5d.
  ///
  /// In en, this message translates to:
  /// **'Move framing south'**
  String get ui13009e218f5d;

  /// No description provided for @ui2888e9293965.
  ///
  /// In en, this message translates to:
  /// **'Refresh projects'**
  String get ui2888e9293965;

  /// No description provided for @ui67300d0fed7c.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get ui67300d0fed7c;

  /// No description provided for @ui0c3c52e40ad0.
  ///
  /// In en, this message translates to:
  /// **'Equipment actions'**
  String get ui0c3c52e40ad0;

  /// No description provided for @uic030274fdf38.
  ///
  /// In en, this message translates to:
  /// **'Profile actions'**
  String get uic030274fdf38;

  /// No description provided for @ui5b6f739130d0.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get ui5b6f739130d0;

  /// No description provided for @uib57187749c45.
  ///
  /// In en, this message translates to:
  /// **'Refresh satellite data'**
  String get uib57187749c45;

  /// No description provided for @uib8d889787970.
  ///
  /// In en, this message translates to:
  /// **'Delete alert'**
  String get uib8d889787970;

  /// No description provided for @uid128718e84ab.
  ///
  /// In en, this message translates to:
  /// **'Search catalog'**
  String get uid128718e84ab;

  /// No description provided for @ui768e0c1c6957.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get ui768e0c1c6957;

  /// No description provided for @ui709a23220f2c.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get ui709a23220f2c;

  /// No description provided for @ui55f8ebc805e6.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get ui55f8ebc805e6;

  /// No description provided for @uibce06414177f.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get uibce06414177f;

  /// No description provided for @ui85a7de6e2705.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get ui85a7de6e2705;

  /// No description provided for @uif69ff6e8d889.
  ///
  /// In en, this message translates to:
  /// **'Galaxy'**
  String get uif69ff6e8d889;

  /// No description provided for @uia796e9cb0c48.
  ///
  /// In en, this message translates to:
  /// **'Nebula'**
  String get uia796e9cb0c48;

  /// No description provided for @uid75dc68bbdd5.
  ///
  /// In en, this message translates to:
  /// **'Cluster'**
  String get uid75dc68bbdd5;

  /// No description provided for @uid2fbdb31702e.
  ///
  /// In en, this message translates to:
  /// **'Azimuth'**
  String get uid2fbdb31702e;

  /// No description provided for @ui22786d42cc30.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get ui22786d42cc30;

  /// No description provided for @uieb9a4bc1c0c1.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get uieb9a4bc1c0c1;

  /// No description provided for @ui6c82e6dd8680.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get ui6c82e6dd8680;

  /// No description provided for @ui1370004da76f.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get ui1370004da76f;

  /// No description provided for @ui906fe5068823.
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get ui906fe5068823;

  /// No description provided for @ui86b5bfa21ad7.
  ///
  /// In en, this message translates to:
  /// **'Overlap'**
  String get ui86b5bfa21ad7;

  /// No description provided for @ui179359b39edb.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get ui179359b39edb;

  /// No description provided for @uidc3decbb9384.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get uidc3decbb9384;

  /// No description provided for @ui6f9f011c5d36.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get ui6f9f011c5d36;

  /// No description provided for @uiced3905ec822.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get uiced3905ec822;

  /// No description provided for @ui0e4aaf56954d.
  ///
  /// In en, this message translates to:
  /// **'Skip onboarding'**
  String get ui0e4aaf56954d;

  /// No description provided for @ui17fef669f6c7.
  ///
  /// In en, this message translates to:
  /// **'Unable to save observing location.'**
  String get ui17fef669f6c7;

  /// No description provided for @uifb2660989020.
  ///
  /// In en, this message translates to:
  /// **'Could not save the setup preference.'**
  String get uifb2660989020;

  /// No description provided for @uif7ed55847ce8.
  ///
  /// In en, this message translates to:
  /// **'Unable to save language preference.'**
  String get uif7ed55847ce8;

  /// No description provided for @ui49226c1839e3.
  ///
  /// In en, this message translates to:
  /// **'Project title *'**
  String get ui49226c1839e3;

  /// No description provided for @ui6316b9fccaa6.
  ///
  /// In en, this message translates to:
  /// **'Imaging goal'**
  String get ui6316b9fccaa6;

  /// No description provided for @ui7b0b8940ba8d.
  ///
  /// In en, this message translates to:
  /// **'e.g. LRGB mosaic'**
  String get ui7b0b8940ba8d;

  /// No description provided for @uie7d20a678c55.
  ///
  /// In en, this message translates to:
  /// **'Planned integration (minutes)'**
  String get uie7d20a678c55;

  /// No description provided for @uibae7d5be7082.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get uibae7d5be7082;

  /// No description provided for @uief3ef61fb395.
  ///
  /// In en, this message translates to:
  /// **'Search Messier, NGC, IC or common name'**
  String get uief3ef61fb395;

  /// No description provided for @ui2239546998dc.
  ///
  /// In en, this message translates to:
  /// **'Search celestial objects'**
  String get ui2239546998dc;

  /// No description provided for @uib257209114e9.
  ///
  /// In en, this message translates to:
  /// **'M31, NGC 224, Andromeda...'**
  String get uib257209114e9;

  /// No description provided for @ui64b44557393c.
  ///
  /// In en, this message translates to:
  /// **'Object category'**
  String get ui64b44557393c;

  /// No description provided for @ui1087e8351bd0.
  ///
  /// In en, this message translates to:
  /// **'Center RA (°)'**
  String get ui1087e8351bd0;

  /// No description provided for @uic3595bc2db24.
  ///
  /// In en, this message translates to:
  /// **'Center Dec (°)'**
  String get uic3595bc2db24;

  /// No description provided for @ui4f59e782df06.
  ///
  /// In en, this message translates to:
  /// **'Find targets by name or catalog identifier'**
  String get ui4f59e782df06;

  /// No description provided for @uibfe842aeacff.
  ///
  /// In en, this message translates to:
  /// **'Equipment name'**
  String get uibfe842aeacff;

  /// No description provided for @ui21122fd5506f.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sony a7 II'**
  String get ui21122fd5506f;

  /// No description provided for @ui77574766df8d.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get ui77574766df8d;

  /// No description provided for @ui81ced9e6eff5.
  ///
  /// In en, this message translates to:
  /// **'e.g. Wide-field setup'**
  String get ui81ced9e6eff5;

  /// No description provided for @uia67a605b9174.
  ///
  /// In en, this message translates to:
  /// **'Lens or telescope'**
  String get uia67a605b9174;

  /// No description provided for @uib282f2b3ba52.
  ///
  /// In en, this message translates to:
  /// **'Mount (optional)'**
  String get uib282f2b3ba52;

  /// No description provided for @ui167fe3b1822d.
  ///
  /// In en, this message translates to:
  /// **'Optical multiplier'**
  String get ui167fe3b1822d;

  /// No description provided for @uifd5eaae796a7.
  ///
  /// In en, this message translates to:
  /// **'1.0 = native, 0.8 = reducer, 2.0 = Barlow'**
  String get uifd5eaae796a7;

  /// No description provided for @ui83cc9086515f.
  ///
  /// In en, this message translates to:
  /// **'e.g. 47.480000'**
  String get ui83cc9086515f;

  /// No description provided for @uiae58b7d1e457.
  ///
  /// In en, this message translates to:
  /// **'e.g. 8.210000'**
  String get uiae58b7d1e457;

  /// No description provided for @ui2150d066fad6.
  ///
  /// In en, this message translates to:
  /// **'Europe/Zurich'**
  String get ui2150d066fad6;

  /// No description provided for @ui91a71a6d16dd.
  ///
  /// In en, this message translates to:
  /// **'Minimum duration'**
  String get ui91a71a6d16dd;

  /// No description provided for @ui5e3ceb0b833f.
  ///
  /// In en, this message translates to:
  /// **'Find target (e.g. M31 or NGC 224)'**
  String get ui5e3ceb0b833f;

  /// No description provided for @uie4c3ec9c7c4d.
  ///
  /// In en, this message translates to:
  /// **'Celestial target'**
  String get uie4c3ec9c7c4d;

  /// No description provided for @uid8b94fdc1405.
  ///
  /// In en, this message translates to:
  /// **'Minimum observation duration'**
  String get uid8b94fdc1405;

  /// No description provided for @ui64f92e2af6c4.
  ///
  /// In en, this message translates to:
  /// **'Imaging project'**
  String get ui64f92e2af6c4;

  /// No description provided for @uic126d285f5f2.
  ///
  /// In en, this message translates to:
  /// **'Repeated hour: choose UTC offset'**
  String get uic126d285f5f2;

  /// No description provided for @ui10c3d1ca4b19.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get ui10c3d1ca4b19;

  /// No description provided for @ui4d56ca9be0c8.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get ui4d56ca9be0c8;

  /// No description provided for @uibc3023b36063.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get uibc3023b36063;

  /// No description provided for @ui348d98c030bf.
  ///
  /// In en, this message translates to:
  /// **'The requested page does not exist.'**
  String get ui348d98c030bf;

  /// No description provided for @uif7b5bf8cef8e.
  ///
  /// In en, this message translates to:
  /// **'Go to Dashboard'**
  String get uif7b5bf8cef8e;

  /// No description provided for @uicb33e2d6f6cb.
  ///
  /// In en, this message translates to:
  /// **'Setup step'**
  String get uicb33e2d6f6cb;

  /// No description provided for @ui9e172bd7b50a.
  ///
  /// In en, this message translates to:
  /// **'Update language'**
  String get ui9e172bd7b50a;

  /// No description provided for @dashboard000.
  ///
  /// In en, this message translates to:
  /// **'Observing dashboard'**
  String get dashboard000;

  /// No description provided for @dashboard001.
  ///
  /// In en, this message translates to:
  /// **'Manage widgets'**
  String get dashboard001;

  /// No description provided for @dashboard002.
  ///
  /// In en, this message translates to:
  /// **'Dashboard observing location'**
  String get dashboard002;

  /// No description provided for @dashboard003.
  ///
  /// In en, this message translates to:
  /// **'Add an observing location in Settings to personalize the dashboard.'**
  String get dashboard003;

  /// No description provided for @dashboard004.
  ///
  /// In en, this message translates to:
  /// **'Loading observing locations…'**
  String get dashboard004;

  /// No description provided for @dashboard005.
  ///
  /// In en, this message translates to:
  /// **'Observing locations unavailable.'**
  String get dashboard005;

  /// No description provided for @dashboard006.
  ///
  /// In en, this message translates to:
  /// **'No dashboard widgets. Use Manage widgets to add one.'**
  String get dashboard006;

  /// No description provided for @dashboard007.
  ///
  /// In en, this message translates to:
  /// **'Could not save dashboard changes:'**
  String get dashboard007;

  /// No description provided for @dashboard008.
  ///
  /// In en, this message translates to:
  /// **'Dashboard widget'**
  String get dashboard008;

  /// No description provided for @dashboard009.
  ///
  /// In en, this message translates to:
  /// **'Unknown widget'**
  String get dashboard009;

  /// No description provided for @dashboard010.
  ///
  /// In en, this message translates to:
  /// **'Widget options'**
  String get dashboard010;

  /// No description provided for @dashboard011.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get dashboard011;

  /// No description provided for @dashboard012.
  ///
  /// In en, this message translates to:
  /// **'Move earlier'**
  String get dashboard012;

  /// No description provided for @dashboard013.
  ///
  /// In en, this message translates to:
  /// **'Move later'**
  String get dashboard013;

  /// No description provided for @dashboard014.
  ///
  /// In en, this message translates to:
  /// **'Hide widget'**
  String get dashboard014;

  /// No description provided for @dashboard015.
  ///
  /// In en, this message translates to:
  /// **'Remove widget'**
  String get dashboard015;

  /// No description provided for @dashboard016.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get dashboard016;

  /// No description provided for @dashboard017.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get dashboard017;

  /// No description provided for @dashboard018.
  ///
  /// In en, this message translates to:
  /// **'Restore default widgets'**
  String get dashboard018;

  /// No description provided for @dashboard019.
  ///
  /// In en, this message translates to:
  /// **'Widget size'**
  String get dashboard019;

  /// No description provided for @dashboard020.
  ///
  /// In en, this message translates to:
  /// **'Compact actions'**
  String get dashboard020;

  /// No description provided for @dashboard021.
  ///
  /// In en, this message translates to:
  /// **'Show coordinates'**
  String get dashboard021;

  /// No description provided for @dashboard022.
  ///
  /// In en, this message translates to:
  /// **'No additional settings.'**
  String get dashboard022;

  /// No description provided for @dashboard023.
  ///
  /// In en, this message translates to:
  /// **'Dashboard configuration could not be loaded.'**
  String get dashboard023;

  /// No description provided for @dashboard024.
  ///
  /// In en, this message translates to:
  /// **'7-Night Forecast'**
  String get dashboard024;

  /// No description provided for @dashboard025.
  ///
  /// In en, this message translates to:
  /// **'Weather outlook for the next seven observing nights'**
  String get dashboard025;

  /// No description provided for @dashboard026.
  ///
  /// In en, this message translates to:
  /// **'Seven-night forecast widget is not yet available.'**
  String get dashboard026;

  /// No description provided for @dashboard027.
  ///
  /// In en, this message translates to:
  /// **'Top 3 Targets Tonight'**
  String get dashboard027;

  /// No description provided for @dashboard028.
  ///
  /// In en, this message translates to:
  /// **'Recommended objects for the current observing night'**
  String get dashboard028;

  /// No description provided for @dashboard029.
  ///
  /// In en, this message translates to:
  /// **'Tonight’s target recommendations are not yet available.'**
  String get dashboard029;

  /// No description provided for @dashboard030.
  ///
  /// In en, this message translates to:
  /// **'Tonight at a Glance'**
  String get dashboard030;

  /// No description provided for @dashboard031.
  ///
  /// In en, this message translates to:
  /// **'Astronomical darkness and lunar conditions'**
  String get dashboard031;

  /// No description provided for @dashboard032.
  ///
  /// In en, this message translates to:
  /// **'Astronomical night summary is not yet available.'**
  String get dashboard032;

  /// No description provided for @dashboard033.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dashboard033;

  /// No description provided for @dashboard034.
  ///
  /// In en, this message translates to:
  /// **'Open frequently used AstroManager screens'**
  String get dashboard034;

  /// No description provided for @dashboard035.
  ///
  /// In en, this message translates to:
  /// **'Observing Site'**
  String get dashboard035;

  /// No description provided for @dashboard036.
  ///
  /// In en, this message translates to:
  /// **'Current observing location and coordinates'**
  String get dashboard036;

  /// No description provided for @dashboard037.
  ///
  /// In en, this message translates to:
  /// **'Manage locations'**
  String get dashboard037;

  /// No description provided for @dashboard038.
  ///
  /// In en, this message translates to:
  /// **'Loading dashboard widget'**
  String get dashboard038;

  /// No description provided for @dashboard039.
  ///
  /// In en, this message translates to:
  /// **'No data available.'**
  String get dashboard039;

  /// No description provided for @dashboard040.
  ///
  /// In en, this message translates to:
  /// **'Unable to load widget data.'**
  String get dashboard040;

  /// No description provided for @dashboard041.
  ///
  /// In en, this message translates to:
  /// **'Data unavailable offline.'**
  String get dashboard041;

  /// No description provided for @dashboard042.
  ///
  /// In en, this message translates to:
  /// **'No observing location selected.'**
  String get dashboard042;

  /// No description provided for @dashboard043.
  ///
  /// In en, this message translates to:
  /// **'This widget is not installed.'**
  String get dashboard043;

  /// No description provided for @dashboard044.
  ///
  /// In en, this message translates to:
  /// **'Invalid widget settings.'**
  String get dashboard044;

  /// No description provided for @dashboard045.
  ///
  /// In en, this message translates to:
  /// **'Edit layout'**
  String get dashboard045;

  /// No description provided for @dashboard046.
  ///
  /// In en, this message translates to:
  /// **'Done editing'**
  String get dashboard046;

  /// No description provided for @dashboard047.
  ///
  /// In en, this message translates to:
  /// **'Drag the grip or use the arrows to move a widget. Select Resize to adjust its size.'**
  String get dashboard047;

  /// No description provided for @dashboard048.
  ///
  /// In en, this message translates to:
  /// **'Reset this device layout?'**
  String get dashboard048;

  /// No description provided for @dashboard049.
  ///
  /// In en, this message translates to:
  /// **'Widgets and layouts on other devices are preserved.'**
  String get dashboard049;

  /// No description provided for @dashboard050.
  ///
  /// In en, this message translates to:
  /// **'Reset layout'**
  String get dashboard050;

  /// No description provided for @dashboard051.
  ///
  /// In en, this message translates to:
  /// **'Edit widget'**
  String get dashboard051;

  /// No description provided for @dashboard052.
  ///
  /// In en, this message translates to:
  /// **'Drag widget'**
  String get dashboard052;

  /// No description provided for @dashboard053.
  ///
  /// In en, this message translates to:
  /// **'Move widget left'**
  String get dashboard053;

  /// No description provided for @dashboard054.
  ///
  /// In en, this message translates to:
  /// **'Move widget up'**
  String get dashboard054;

  /// No description provided for @dashboard055.
  ///
  /// In en, this message translates to:
  /// **'Move widget down'**
  String get dashboard055;

  /// No description provided for @dashboard056.
  ///
  /// In en, this message translates to:
  /// **'Move widget right'**
  String get dashboard056;

  /// No description provided for @dashboard057.
  ///
  /// In en, this message translates to:
  /// **'Resize widget'**
  String get dashboard057;

  /// No description provided for @dashboardResize.
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get dashboardResize;

  /// No description provided for @dashboardWidthColumns.
  ///
  /// In en, this message translates to:
  /// **'Width (columns)'**
  String get dashboardWidthColumns;

  /// No description provided for @dashboardHeightRows.
  ///
  /// In en, this message translates to:
  /// **'Height (rows)'**
  String get dashboardHeightRows;

  /// No description provided for @dashboardWeather01.
  ///
  /// In en, this message translates to:
  /// **'Maximum cloud cover (%)'**
  String get dashboardWeather01;

  /// No description provided for @dashboardWeather02.
  ///
  /// In en, this message translates to:
  /// **'Minimum clear duration (hours)'**
  String get dashboardWeather02;

  /// No description provided for @dashboardWeather03.
  ///
  /// In en, this message translates to:
  /// **'Cloud limit'**
  String get dashboardWeather03;

  /// No description provided for @dashboardWeather04.
  ///
  /// In en, this message translates to:
  /// **'Minimum clear'**
  String get dashboardWeather04;

  /// No description provided for @dashboardWeather05.
  ///
  /// In en, this message translates to:
  /// **'Cloud cover'**
  String get dashboardWeather05;

  /// No description provided for @dashboardWeather06.
  ///
  /// In en, this message translates to:
  /// **'clear'**
  String get dashboardWeather06;

  /// No description provided for @dashboardWeather07.
  ///
  /// In en, this message translates to:
  /// **'covered'**
  String get dashboardWeather07;

  /// No description provided for @dashboardWeather08.
  ///
  /// In en, this message translates to:
  /// **'Stale forecast'**
  String get dashboardWeather08;

  /// No description provided for @dashboardWeather09.
  ///
  /// In en, this message translates to:
  /// **'Offline cache'**
  String get dashboardWeather09;

  /// No description provided for @dashboardWeather10.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get dashboardWeather10;

  /// No description provided for @dashboardWeather11.
  ///
  /// In en, this message translates to:
  /// **'No astronomical darkness'**
  String get dashboardWeather11;

  /// No description provided for @dashboardWeather12.
  ///
  /// In en, this message translates to:
  /// **'No forecast coverage'**
  String get dashboardWeather12;

  /// No description provided for @dashboardWeather13.
  ///
  /// In en, this message translates to:
  /// **'Weather forecast unavailable. Check your connection.'**
  String get dashboardWeather13;

  /// No description provided for @dashboardWeather14.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh. Showing the last forecast.'**
  String get dashboardWeather14;

  /// No description provided for @dashboardWeather15.
  ///
  /// In en, this message translates to:
  /// **'Astronomical darkness'**
  String get dashboardWeather15;

  /// No description provided for @dashboardWeather16.
  ///
  /// In en, this message translates to:
  /// **'Forecast coverage'**
  String get dashboardWeather16;

  /// No description provided for @dashboardWeather17.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get dashboardWeather17;

  /// No description provided for @dashboardWeather18.
  ///
  /// In en, this message translates to:
  /// **'Qualifying clear hours'**
  String get dashboardWeather18;

  /// No description provided for @dashboardWeather19.
  ///
  /// In en, this message translates to:
  /// **'Longest clear period'**
  String get dashboardWeather19;

  /// No description provided for @dashboardWeather20.
  ///
  /// In en, this message translates to:
  /// **'Average cloud cover'**
  String get dashboardWeather20;

  /// No description provided for @dashboardWeather21.
  ///
  /// In en, this message translates to:
  /// **'Cloud trend'**
  String get dashboardWeather21;

  /// No description provided for @dashboardWeather22.
  ///
  /// In en, this message translates to:
  /// **'improving'**
  String get dashboardWeather22;

  /// No description provided for @dashboardWeather23.
  ///
  /// In en, this message translates to:
  /// **'stable'**
  String get dashboardWeather23;

  /// No description provided for @dashboardWeather24.
  ///
  /// In en, this message translates to:
  /// **'worsening'**
  String get dashboardWeather24;

  /// No description provided for @dashboardWeather25.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get dashboardWeather25;

  /// No description provided for @dashboardWeather26.
  ///
  /// In en, this message translates to:
  /// **'Forecast incomplete: uncovered hours are unknown, not clear.'**
  String get dashboardWeather26;

  /// No description provided for @dashboardWeather27.
  ///
  /// In en, this message translates to:
  /// **'Open Night Planner'**
  String get dashboardWeather27;

  /// No description provided for @dashboardWeatherRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh forecast'**
  String get dashboardWeatherRefresh;

  /// No description provided for @dashboardWeatherTimeZoneSelect.
  ///
  /// In en, this message translates to:
  /// **'Select a time zone from the list.'**
  String get dashboardWeatherTimeZoneSelect;

  /// No description provided for @dashboardTargets1.
  ///
  /// In en, this message translates to:
  /// **'Candidate targets'**
  String get dashboardTargets1;

  /// No description provided for @dashboardTargets2.
  ///
  /// In en, this message translates to:
  /// **'Minimum session duration (minutes)'**
  String get dashboardTargets2;

  /// No description provided for @dashboardTargets3.
  ///
  /// In en, this message translates to:
  /// **'combined'**
  String get dashboardTargets3;

  /// No description provided for @dashboardTargets4.
  ///
  /// In en, this message translates to:
  /// **'catalog'**
  String get dashboardTargets4;

  /// No description provided for @dashboardTargets5.
  ///
  /// In en, this message translates to:
  /// **'projects'**
  String get dashboardTargets5;

  /// No description provided for @dashboardTargets6.
  ///
  /// In en, this message translates to:
  /// **'favorites'**
  String get dashboardTargets6;

  /// No description provided for @dashboardTargets7.
  ///
  /// In en, this message translates to:
  /// **'Projects, favorites and catalog'**
  String get dashboardTargets7;

  /// No description provided for @dashboardTargets8.
  ///
  /// In en, this message translates to:
  /// **'Catalog targets'**
  String get dashboardTargets8;

  /// No description provided for @dashboardTargets9.
  ///
  /// In en, this message translates to:
  /// **'Active projects'**
  String get dashboardTargets9;

  /// No description provided for @dashboardTargets10.
  ///
  /// In en, this message translates to:
  /// **'Favorite targets'**
  String get dashboardTargets10;

  /// No description provided for @dashboardTargets11.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate target recommendations.'**
  String get dashboardTargets11;

  /// No description provided for @dashboardTargets12.
  ///
  /// In en, this message translates to:
  /// **'Weather unavailable · provisional scores'**
  String get dashboardTargets12;

  /// No description provided for @dashboardTargets13.
  ///
  /// In en, this message translates to:
  /// **'Stale weather · provisional scores'**
  String get dashboardTargets13;

  /// No description provided for @dashboardTargets14.
  ///
  /// In en, this message translates to:
  /// **'Recalculate recommendations'**
  String get dashboardTargets14;

  /// No description provided for @dashboardTargets15.
  ///
  /// In en, this message translates to:
  /// **'No candidate targets. Add projects or favorites, or select Catalog.'**
  String get dashboardTargets15;

  /// No description provided for @dashboardTargets16.
  ///
  /// In en, this message translates to:
  /// **'No qualifying targets for this night and minimum duration.'**
  String get dashboardTargets16;

  /// No description provided for @dashboardTargets17.
  ///
  /// In en, this message translates to:
  /// **'candidates evaluated'**
  String get dashboardTargets17;

  /// No description provided for @dashboardTargets18.
  ///
  /// In en, this message translates to:
  /// **'Top 3 use the existing suitability model.'**
  String get dashboardTargets18;

  /// No description provided for @dashboardTargets19.
  ///
  /// In en, this message translates to:
  /// **'Provisional'**
  String get dashboardTargets19;

  /// No description provided for @dashboardTargets20.
  ///
  /// In en, this message translates to:
  /// **'Peak altitude'**
  String get dashboardTargets20;

  /// No description provided for @dashboardTargets21.
  ///
  /// In en, this message translates to:
  /// **'Moon separation'**
  String get dashboardTargets21;

  /// No description provided for @dashboardTargets22.
  ///
  /// In en, this message translates to:
  /// **'Terrain horizon not available; not included in score.'**
  String get dashboardTargets22;

  /// No description provided for @dashboardTargets23.
  ///
  /// In en, this message translates to:
  /// **'Cached terrain at peak bearing'**
  String get dashboardTargets23;

  /// No description provided for @dashboardTargets24.
  ///
  /// In en, this message translates to:
  /// **'possible obstruction'**
  String get dashboardTargets24;

  /// No description provided for @dashboardTargets25.
  ///
  /// In en, this message translates to:
  /// **'not included in score.'**
  String get dashboardTargets25;

  /// No description provided for @dashboardTargets26.
  ///
  /// In en, this message translates to:
  /// **'Sky Atlas'**
  String get dashboardTargets26;

  /// No description provided for @dashboardTargets27.
  ///
  /// In en, this message translates to:
  /// **'Plan observation'**
  String get dashboardTargets27;

  /// No description provided for @dashboardTargets28.
  ///
  /// In en, this message translates to:
  /// **'Why this score?'**
  String get dashboardTargets28;

  /// No description provided for @dashboardTargets29.
  ///
  /// In en, this message translates to:
  /// **'Weather coverage'**
  String get dashboardTargets29;

  /// No description provided for @dashboardTargets30.
  ///
  /// In en, this message translates to:
  /// **'This observing window has ended.'**
  String get dashboardTargets30;

  /// No description provided for @dashboardTargets31.
  ///
  /// In en, this message translates to:
  /// **'Choose a project for this target:'**
  String get dashboardTargets31;

  /// No description provided for @dashboardTargets32.
  ///
  /// In en, this message translates to:
  /// **'Create a new imaging project and plan'**
  String get dashboardTargets32;

  /// No description provided for @dashboardTargets33.
  ///
  /// In en, this message translates to:
  /// **'Overlapping observation'**
  String get dashboardTargets33;

  /// No description provided for @dashboardTargets34.
  ///
  /// In en, this message translates to:
  /// **'This block overlaps another plan. Save it anyway?'**
  String get dashboardTargets34;

  /// No description provided for @dashboardTargets35.
  ///
  /// In en, this message translates to:
  /// **'Observation added to Night Planner.'**
  String get dashboardTargets35;

  /// No description provided for @dashboardTargets36.
  ///
  /// In en, this message translates to:
  /// **'Could not save observation'**
  String get dashboardTargets36;

  /// No description provided for @dashboardTargets37.
  ///
  /// In en, this message translates to:
  /// **'complete'**
  String get dashboardTargets37;

  /// No description provided for @dashboardTargets38.
  ///
  /// In en, this message translates to:
  /// **'partial'**
  String get dashboardTargets38;

  /// No description provided for @dashboardTargets39.
  ///
  /// In en, this message translates to:
  /// **'missing'**
  String get dashboardTargets39;

  /// No description provided for @dashboardTargets40.
  ///
  /// In en, this message translates to:
  /// **'stale'**
  String get dashboardTargets40;

  /// No description provided for @dashboardTonight02.
  ///
  /// In en, this message translates to:
  /// **'Continuous astronomical darkness throughout this observing night.'**
  String get dashboardTonight02;

  /// No description provided for @dashboardTonight03.
  ///
  /// In en, this message translates to:
  /// **'Darkness duration'**
  String get dashboardTonight03;

  /// No description provided for @dashboardTonight04.
  ///
  /// In en, this message translates to:
  /// **'Remaining darkness'**
  String get dashboardTonight04;

  /// No description provided for @dashboardTonight05.
  ///
  /// In en, this message translates to:
  /// **'Sunset / sunrise'**
  String get dashboardTonight05;

  /// No description provided for @dashboardTonight06.
  ///
  /// In en, this message translates to:
  /// **'Astronomical dusk / dawn'**
  String get dashboardTonight06;

  /// No description provided for @dashboardTonight07.
  ///
  /// In en, this message translates to:
  /// **'Moon phase and illumination'**
  String get dashboardTonight07;

  /// No description provided for @dashboardTonight08.
  ///
  /// In en, this message translates to:
  /// **'Moonrise / moonset'**
  String get dashboardTonight08;

  /// No description provided for @dashboardTonight09.
  ///
  /// In en, this message translates to:
  /// **'Moon stays above horizon'**
  String get dashboardTonight09;

  /// No description provided for @dashboardTonight10.
  ///
  /// In en, this message translates to:
  /// **'Moon stays below horizon'**
  String get dashboardTonight10;

  /// No description provided for @dashboardTonight11.
  ///
  /// In en, this message translates to:
  /// **'No lunar crossing this night'**
  String get dashboardTonight11;

  /// No description provided for @dashboardTonight12.
  ///
  /// In en, this message translates to:
  /// **'Some solar events do not occur during this observing night.'**
  String get dashboardTonight12;

  /// No description provided for @dashboardTonight13.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate astronomical conditions.'**
  String get dashboardTonight13;

  /// No description provided for @dashboardTonight14.
  ///
  /// In en, this message translates to:
  /// **'New Moon'**
  String get dashboardTonight14;

  /// No description provided for @dashboardTonight15.
  ///
  /// In en, this message translates to:
  /// **'Waxing Crescent'**
  String get dashboardTonight15;

  /// No description provided for @dashboardTonight16.
  ///
  /// In en, this message translates to:
  /// **'First Quarter'**
  String get dashboardTonight16;

  /// No description provided for @dashboardTonight17.
  ///
  /// In en, this message translates to:
  /// **'Waxing Gibbous'**
  String get dashboardTonight17;

  /// No description provided for @dashboardTonight18.
  ///
  /// In en, this message translates to:
  /// **'Full Moon'**
  String get dashboardTonight18;

  /// No description provided for @dashboardTonight19.
  ///
  /// In en, this message translates to:
  /// **'Waning Gibbous'**
  String get dashboardTonight19;

  /// No description provided for @dashboardTonight20.
  ///
  /// In en, this message translates to:
  /// **'Last Quarter'**
  String get dashboardTonight20;

  /// No description provided for @dashboardTonight21.
  ///
  /// In en, this message translates to:
  /// **'Waning Crescent'**
  String get dashboardTonight21;

  /// No description provided for @dashboardActivity01.
  ///
  /// In en, this message translates to:
  /// **'Active Imaging Projects'**
  String get dashboardActivity01;

  /// No description provided for @dashboardActivity02.
  ///
  /// In en, this message translates to:
  /// **'Accepted integration time and imaging goal progress'**
  String get dashboardActivity02;

  /// No description provided for @dashboardActivity03.
  ///
  /// In en, this message translates to:
  /// **'Recent Observation Sessions'**
  String get dashboardActivity03;

  /// No description provided for @dashboardActivity04.
  ///
  /// In en, this message translates to:
  /// **'Recent imaging activity and accepted exposure time'**
  String get dashboardActivity04;

  /// No description provided for @dashboardActivity05.
  ///
  /// In en, this message translates to:
  /// **'Number of projects'**
  String get dashboardActivity05;

  /// No description provided for @dashboardActivity06.
  ///
  /// In en, this message translates to:
  /// **'Number of sessions'**
  String get dashboardActivity06;

  /// No description provided for @dashboardActivity07.
  ///
  /// In en, this message translates to:
  /// **'Show Sky Atlas'**
  String get dashboardActivity07;

  /// No description provided for @dashboardActivity08.
  ///
  /// In en, this message translates to:
  /// **'Show Night Planner'**
  String get dashboardActivity08;

  /// No description provided for @dashboardActivity09.
  ///
  /// In en, this message translates to:
  /// **'Show Projects'**
  String get dashboardActivity09;

  /// No description provided for @dashboardActivity10.
  ///
  /// In en, this message translates to:
  /// **'Show Session Logging'**
  String get dashboardActivity10;

  /// No description provided for @dashboardActivity11.
  ///
  /// In en, this message translates to:
  /// **'Show Targets'**
  String get dashboardActivity11;

  /// No description provided for @dashboardActivity12.
  ///
  /// In en, this message translates to:
  /// **'Show Equipment'**
  String get dashboardActivity12;

  /// No description provided for @dashboardActivity13.
  ///
  /// In en, this message translates to:
  /// **'Unable to load project progress.'**
  String get dashboardActivity13;

  /// No description provided for @dashboardActivity14.
  ///
  /// In en, this message translates to:
  /// **'No active imaging projects. Create one in Projects.'**
  String get dashboardActivity14;

  /// No description provided for @dashboardActivity15.
  ///
  /// In en, this message translates to:
  /// **'Accepted integration'**
  String get dashboardActivity15;

  /// No description provided for @dashboardActivity16.
  ///
  /// In en, this message translates to:
  /// **'Integration progress'**
  String get dashboardActivity16;

  /// No description provided for @dashboardActivity17.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get dashboardActivity17;

  /// No description provided for @dashboardActivity18.
  ///
  /// In en, this message translates to:
  /// **'No integration goal set.'**
  String get dashboardActivity18;

  /// No description provided for @dashboardActivity19.
  ///
  /// In en, this message translates to:
  /// **'sessions'**
  String get dashboardActivity19;

  /// No description provided for @dashboardActivity20.
  ///
  /// In en, this message translates to:
  /// **'Unable to load recent sessions.'**
  String get dashboardActivity20;

  /// No description provided for @dashboardActivity21.
  ///
  /// In en, this message translates to:
  /// **'No observation sessions recorded yet.'**
  String get dashboardActivity21;

  /// No description provided for @dashboardActivity22.
  ///
  /// In en, this message translates to:
  /// **'accepted frames'**
  String get dashboardActivity22;

  /// No description provided for @dashboardActivity23.
  ///
  /// In en, this message translates to:
  /// **'rejected frames'**
  String get dashboardActivity23;

  /// No description provided for @dashboardActivity24.
  ///
  /// In en, this message translates to:
  /// **'Choose a project to log a session'**
  String get dashboardActivity24;

  /// No description provided for @dashboardActivity25.
  ///
  /// In en, this message translates to:
  /// **'Unable to load projects.'**
  String get dashboardActivity25;

  /// No description provided for @dashboardActivity26.
  ///
  /// In en, this message translates to:
  /// **'No projects available. Create a project first.'**
  String get dashboardActivity26;

  /// No description provided for @dashboardActivity27.
  ///
  /// In en, this message translates to:
  /// **'Observation session saved.'**
  String get dashboardActivity27;

  /// No description provided for @dashboardActivity28.
  ///
  /// In en, this message translates to:
  /// **'Could not save session'**
  String get dashboardActivity28;

  /// No description provided for @dashboardActivity29.
  ///
  /// In en, this message translates to:
  /// **'Log session'**
  String get dashboardActivity29;

  /// No description provided for @dashboardActivity30.
  ///
  /// In en, this message translates to:
  /// **'Select at least one quick action in widget settings.'**
  String get dashboardActivity30;

  /// No description provided for @dashboardUpcomingPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Observation Plans'**
  String get dashboardUpcomingPlansTitle;

  /// No description provided for @dashboardUpcomingPlansDescription.
  ///
  /// In en, this message translates to:
  /// **'Scheduled observing blocks and overlapping plans'**
  String get dashboardUpcomingPlansDescription;

  /// No description provided for @dashboardAlertsWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Observation Opportunities & Alerts'**
  String get dashboardAlertsWidgetTitle;

  /// No description provided for @dashboardAlertsWidgetDescription.
  ///
  /// In en, this message translates to:
  /// **'Enabled alert rules and previously notified opportunities'**
  String get dashboardAlertsWidgetDescription;

  /// No description provided for @dashboardUpcomingNights.
  ///
  /// In en, this message translates to:
  /// **'Upcoming observing nights'**
  String get dashboardUpcomingNights;

  /// No description provided for @dashboardMaxObservations.
  ///
  /// In en, this message translates to:
  /// **'Maximum displayed observations'**
  String get dashboardMaxObservations;

  /// No description provided for @dashboardMaxAlerts.
  ///
  /// In en, this message translates to:
  /// **'Maximum displayed alerts'**
  String get dashboardMaxAlerts;

  /// No description provided for @dashboardShowNotified.
  ///
  /// In en, this message translates to:
  /// **'Show recently notified opportunities'**
  String get dashboardShowNotified;

  /// No description provided for @dashboardNoUpcomingPlans.
  ///
  /// In en, this message translates to:
  /// **'No upcoming observation blocks at this location.'**
  String get dashboardNoUpcomingPlans;

  /// No description provided for @dashboardOpenNightPlanner.
  ///
  /// In en, this message translates to:
  /// **'Open Night Planner'**
  String get dashboardOpenNightPlanner;

  /// No description provided for @dashboardOverlappingPlans.
  ///
  /// In en, this message translates to:
  /// **'Overlapping observations'**
  String get dashboardOverlappingPlans;

  /// No description provided for @dashboardUnableLoadPlans.
  ///
  /// In en, this message translates to:
  /// **'Unable to load planned observations.'**
  String get dashboardUnableLoadPlans;

  /// No description provided for @dashboardAlertsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Opportunity notifications are disabled.'**
  String get dashboardAlertsDisabled;

  /// No description provided for @dashboardNoAlertRules.
  ///
  /// In en, this message translates to:
  /// **'No alert rules for this observing location.'**
  String get dashboardNoAlertRules;

  /// No description provided for @dashboardNoEnabledRules.
  ///
  /// In en, this message translates to:
  /// **'No enabled alert rules at this location.'**
  String get dashboardNoEnabledRules;

  /// No description provided for @dashboardMonitoredTargets.
  ///
  /// In en, this message translates to:
  /// **'Monitored targets'**
  String get dashboardMonitoredTargets;

  /// No description provided for @dashboardRecentlyNotified.
  ///
  /// In en, this message translates to:
  /// **'Recently notified opportunities'**
  String get dashboardRecentlyNotified;

  /// No description provided for @dashboardNotified.
  ///
  /// In en, this message translates to:
  /// **'Notified'**
  String get dashboardNotified;

  /// No description provided for @dashboardNoBackgroundChecks.
  ///
  /// In en, this message translates to:
  /// **'Checks run at app start, foreground or manually; no continuous background monitoring.'**
  String get dashboardNoBackgroundChecks;

  /// No description provided for @dashboardManageAlerts.
  ///
  /// In en, this message translates to:
  /// **'Manage alerts in Settings'**
  String get dashboardManageAlerts;

  /// No description provided for @dashboardUnableLoadAlerts.
  ///
  /// In en, this message translates to:
  /// **'Unable to load observation alerts.'**
  String get dashboardUnableLoadAlerts;

  /// No description provided for @dashboardObservingNightLabel.
  ///
  /// In en, this message translates to:
  /// **'Observing night'**
  String get dashboardObservingNightLabel;

  /// No description provided for @dashboardSiteConditionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Observing Site'**
  String get dashboardSiteConditionsTitle;

  /// No description provided for @dashboardSiteConditionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Cached terrain horizon and night-light conditions for the selected site'**
  String get dashboardSiteConditionsDescription;

  /// No description provided for @dashboardSiteShowDetails.
  ///
  /// In en, this message translates to:
  /// **'Show environmental details'**
  String get dashboardSiteShowDetails;

  /// No description provided for @dashboardSiteTerrain.
  ///
  /// In en, this message translates to:
  /// **'Terrain horizon'**
  String get dashboardSiteTerrain;

  /// No description provided for @dashboardSiteLight.
  ///
  /// In en, this message translates to:
  /// **'Night-light radiance'**
  String get dashboardSiteLight;

  /// No description provided for @dashboardSiteNoTerrain.
  ///
  /// In en, this message translates to:
  /// **'No cached terrain profile. Check the site details to load one.'**
  String get dashboardSiteNoTerrain;

  /// No description provided for @dashboardSiteNoLight.
  ///
  /// In en, this message translates to:
  /// **'No cached night-light data. Check the site details to load a sample.'**
  String get dashboardSiteNoLight;

  /// No description provided for @dashboardSiteCacheOnly.
  ///
  /// In en, this message translates to:
  /// **'Cache only · no automatic data requests'**
  String get dashboardSiteCacheOnly;

  /// No description provided for @dashboardSiteStale.
  ///
  /// In en, this message translates to:
  /// **'Outdated cached data'**
  String get dashboardSiteStale;

  /// No description provided for @dashboardSiteCoverage.
  ///
  /// In en, this message translates to:
  /// **'Known bearings'**
  String get dashboardSiteCoverage;

  /// No description provided for @dashboardSiteNotLineOfSight.
  ///
  /// In en, this message translates to:
  /// **'Modeled terrain horizon is not surveyed line of sight. Unknown bearings remain unknown.'**
  String get dashboardSiteNotLineOfSight;

  /// No description provided for @dashboardSiteNotSkyBrightness.
  ///
  /// In en, this message translates to:
  /// **'Satellite radiance is not measured sky brightness or a Bortle class.'**
  String get dashboardSiteNotSkyBrightness;

  /// No description provided for @dashboardSiteSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get dashboardSiteSource;

  /// No description provided for @dashboardSiteDatasetDate.
  ///
  /// In en, this message translates to:
  /// **'Dataset month'**
  String get dashboardSiteDatasetDate;

  /// No description provided for @dashboardSiteChecked.
  ///
  /// In en, this message translates to:
  /// **'Retrieved'**
  String get dashboardSiteChecked;

  /// No description provided for @dashboardSiteProfileDate.
  ///
  /// In en, this message translates to:
  /// **'Profile generated'**
  String get dashboardSiteProfileDate;

  /// No description provided for @dashboardSiteCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare observing sites'**
  String get dashboardSiteCompare;

  /// No description provided for @dashboardSiteManage.
  ///
  /// In en, this message translates to:
  /// **'Manage site data'**
  String get dashboardSiteManage;

  /// No description provided for @dashboardSiteExpand.
  ///
  /// In en, this message translates to:
  /// **'Show details'**
  String get dashboardSiteExpand;

  /// No description provided for @dashboardSiteCollapse.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get dashboardSiteCollapse;

  /// No description provided for @dashboardSiteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to read cached site conditions.'**
  String get dashboardSiteUnavailable;

  /// No description provided for @dashboardSiteKindSatellite.
  ///
  /// In en, this message translates to:
  /// **'Satellite upward radiance'**
  String get dashboardSiteKindSatellite;

  /// No description provided for @dashboardSiteKindMeasured.
  ///
  /// In en, this message translates to:
  /// **'Measured zenith sky brightness'**
  String get dashboardSiteKindMeasured;

  /// No description provided for @dashboardSiteKindModeled.
  ///
  /// In en, this message translates to:
  /// **'Modeled zenith sky brightness'**
  String get dashboardSiteKindModeled;

  /// No description provided for @dashboardSiteMissing.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get dashboardSiteMissing;

  /// No description provided for @dashboardSiteCache.
  ///
  /// In en, this message translates to:
  /// **'Cached'**
  String get dashboardSiteCache;

  /// No description provided for @dashboardSiteCatalogUpdated.
  ///
  /// In en, this message translates to:
  /// **'Source catalogue updated'**
  String get dashboardSiteCatalogUpdated;

  /// No description provided for @dashboardSiteRefreshCache.
  ///
  /// In en, this message translates to:
  /// **'Refresh cached site data'**
  String get dashboardSiteRefreshCache;

  /// No description provided for @dashboardSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save dashboard changes.'**
  String get dashboardSaveError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
