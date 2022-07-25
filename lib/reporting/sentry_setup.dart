import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config.dart';
import '../helpers.dart';
import 'analytics_logger.dart';

class SentryManager {
  static setup(SentryFlutterOptions options) async {
    PackageInfo info = await PackageInfo.fromPlatform();
    options.release = info.version;
    options.environment = kDebugMode ? 'development' : 'production';
    options.debug = kDebugMode;
    options.diagnosticLevel = SentryLevel.info;
    options.dsn = Config.sentryDsn;
    options.tracesSampleRate = 1.0;
    options.beforeSend = (event, {dynamic hint}) async {
      return _handleBeforeSend(event);
    };
  }

  static _handleBeforeSend(SentryEvent event) {
    Object throwable = event.throwable;

    String? type;
    if (throwable is LogError) {
      type = throwable.type;
      // No need to print this here due to already printed
    } else {
      print('SENTRY: Native error logged ${throwable.runtimeType.toString()}');
    }

    // Don't post errors that happened during analytics calls
    // to avoid infinite recursions
    if (throwable is AnalyticsLogError) {
      print('SENTRY: Ignored posting analytics error ${throwable.type}');
    } else {
      // This caused recursion when was called on native error for some reason
      AnalyticsEvent.errorLogged.log({
        'Logged': throwable is LogError,
        'Type': type ?? 'native',
        'Event ID': event.eventId.toString(),
        'Error': throwable.toString(),
        'Error Type': throwable.runtimeType.toString(),
      });
    }

    return Config.sendErrorAndAnalyticsLogs ? event : null;
  }

  setProfileProps(Map userProps) {
    var props = {};
    for (var key in userProps.keys) {
      var value = userProps[key]?.toString() ?? '(null)';
      key = key.replaceAll('\$', '');
      key = key.replaceAll(' ', '_');
      key = key.toLowerCase();
      props[key] = value;
    }
    Sentry.configureScope((scope) {
      scope.setTag('platform', Platform.operatingSystem);
      for (var it in props.entries) {
        scope.setTag(it.key, it.value);
      }
      scope.setContexts('User Properties', props);
    });
  }
}
