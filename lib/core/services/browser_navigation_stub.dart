/// Non-web build: the browser never animates a history step.
int? lastBrowserAnimatedNavigationMs() => null;

void browserNavigationShown(int mark) {}

void setBrowserNavigationContext(String key) {}
