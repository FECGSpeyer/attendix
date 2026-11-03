/// Non-web build: the browser never animates a history step.
int? lastBrowserAnimatedNavigationMs() => null;

void browserNavigationShown(int mark) {}

int? setBrowserNavigationContext(String key) => null;

void browserNavigationContextDrawn(int gen) {}
