import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Ionic `ionViewWillEnter` for a go_router page: calls [onRouteReturn]
/// whenever this page is the top page again after another page was shown on
/// top (or instead) of it. Compares the page key of the top route match
/// (pushed pages have their own key; `replace` keeps the key).
mixin RouteReturnReload<T extends StatefulWidget> on State<T> {
  GoRouterDelegate? _routeReturnDelegate;
  ValueKey<String>? _routeReturnKey;
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
      _routeReturnKey = delegate.currentConfiguration.lastOrNull?.pageKey;
      delegate.addListener(_onRouteReturnChange);
    }
  }

  @override
  void dispose() {
    _routeReturnDelegate?.removeListener(_onRouteReturnChange);
    super.dispose();
  }

  void _onRouteReturnChange() {
    final key = _routeReturnDelegate?.currentConfiguration.lastOrNull?.pageKey;
    if (key == null || _routeReturnKey == null) return;
    if (key != _routeReturnKey) {
      _routeReturnCovered = true;
    } else if (_routeReturnCovered) {
      _routeReturnCovered = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onRouteReturn();
      });
    }
  }
}
