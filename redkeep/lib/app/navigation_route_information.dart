import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'navigation_destination.dart';

/// Validates platform input before the router parser consumes it. The router
/// remains the owner of the delegate and its platform-observer lifecycle.
class NavigationRouteInformation extends RouteInformationProvider {
  NavigationRouteInformation(this._delegate);
  final GoRouteInformationProvider _delegate;

  @override
  RouteInformation get value {
    final current = _delegate.value;
    return RouteInformation(
      uri: Uri.parse(validatedNavigationLocation(current.uri.toString())),
      state: current.state,
    );
  }

  @override
  void addListener(VoidCallback listener) => _delegate.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _delegate.removeListener(listener);

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    // go_router 18.1.2 compares the old query before replacing it. An invalid
    // UTF-8 query throws there even if our parser input was already sanitized.
    // Replace that malformed platform history entry without decoding it again.
    try {
      _delegate.value.uri.queryParametersAll;
    } on FormatException {
      type = RouteInformationReportingType.neglect;
    }
    _delegate.routerReportsNewRouteInformation(routeInformation, type: type);
  }
}
