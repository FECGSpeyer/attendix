import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Ionic `ionViewWillEnter` for a go_router page: calls [onRouteReturn]
/// whenever the app comes back to this page's location after another page
/// was shown on top (or instead) of it.
mixin RouteReturnReload<T extends StatefulWidget> on State<T> {
  GoRouterDelegate? _routeReturnDelegate;
  String? _routeReturnPath;
  bool _routeReturnCovered = false;

  /// Called after the frame in which the page became current again.
  void onRouteReturn();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final delegate = GoRouter.maybeOf(context)?.routerDelegate;
    if (delegate != null && delegate != _routeReturnDelegate) {
      _routeReturnDelegate?.removeListener(_onRouteReturnChange);
      _routeReturnDelegate = delegate;
      _routeReturnPath = delegate.currentConfiguration.uri.path;
      delegate.addListener(_onRouteReturnChange);
    }
  }

  @override
  void dispose() {
    _routeReturnDelegate?.removeListener(_onRouteReturnChange);
    super.dispose();
  }

  void _onRouteReturnChange() {
    final path = _routeReturnDelegate?.currentConfiguration.uri.path;
    if (path == null || _routeReturnPath == null) return;
    if (path != _routeReturnPath) {
      _routeReturnCovered = true;
    } else if (_routeReturnCovered) {
      _routeReturnCovered = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onRouteReturn();
      });
    }
  }
}
