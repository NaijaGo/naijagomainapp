import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

enum LocationAccessIssue { servicesDisabled, denied, deniedForever }

class LocationAccessResult {
  final LocationPermission? permission;
  final LocationAccessIssue? issue;
  final String message;

  const LocationAccessResult._({
    required this.permission,
    required this.issue,
    required this.message,
  });

  const LocationAccessResult.granted({required LocationPermission permission})
    : this._(permission: permission, issue: null, message: '');

  const LocationAccessResult.blocked({
    required LocationAccessIssue issue,
    required String message,
    LocationPermission? permission,
  }) : this._(permission: permission, issue: issue, message: message);

  bool get granted => issue == null;
  bool get shouldOpenLocationSettings =>
      issue == LocationAccessIssue.servicesDisabled;
  bool get shouldOpenAppSettings =>
      issue == LocationAccessIssue.denied ||
      issue == LocationAccessIssue.deniedForever;
  bool get needsSettingsAction =>
      shouldOpenLocationSettings || shouldOpenAppSettings;
  String get dialogTitle => shouldOpenLocationSettings
      ? 'Turn on Location Services'
      : 'Allow Location Access';
  String get settingsActionLabel => shouldOpenLocationSettings
      ? 'Open Location Settings'
      : 'Open App Settings';
}

class LocationAccessService {
  static Future<LocationAccessResult> ensureAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationAccessResult.blocked(
        issue: LocationAccessIssue.servicesDisabled,
        message:
            'Location services are turned off. Enable them to use current location on your iPhone.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccessResult.granted(permission: permission);
      case LocationPermission.denied:
        return const LocationAccessResult.blocked(
          issue: LocationAccessIssue.denied,
          message:
              'Location access was denied. On iPhone, you may need to allow location from Settings before this can work again.',
          permission: LocationPermission.denied,
        );
      case LocationPermission.deniedForever:
        return const LocationAccessResult.blocked(
          issue: LocationAccessIssue.deniedForever,
          message:
              'Location access is blocked for this app. Open iPhone Settings and allow location access to continue.',
          permission: LocationPermission.deniedForever,
        );
      case LocationPermission.unableToDetermine:
        return const LocationAccessResult.blocked(
          issue: LocationAccessIssue.denied,
          message:
              'We could not determine your location permission status. Please review location access in Settings.',
          permission: LocationPermission.unableToDetermine,
        );
    }
  }

  static LocationSettings currentLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: false,
      );
    }

    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  static Future<void> openRelevantSettings(LocationAccessResult result) async {
    if (result.shouldOpenLocationSettings) {
      await Geolocator.openLocationSettings();
      return;
    }

    if (result.shouldOpenAppSettings) {
      await Geolocator.openAppSettings();
    }
  }

  static Future<void> presentIssue(
    BuildContext context,
    LocationAccessResult result,
  ) async {
    if (!result.needsSettingsAction) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    final openSettings =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.dialogTitle),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(result.settingsActionLabel),
              ),
            ],
          ),
        ) ??
        false;

    if (openSettings) {
      await openRelevantSettings(result);
    }
  }
}
