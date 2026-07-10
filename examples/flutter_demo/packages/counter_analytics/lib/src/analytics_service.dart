/// The analytics contract of this package.
///
/// Consumers (like `IncrementTracker`, or any class in the app) inject this
/// interface; [AnalyticsModule] decides which implementation they receive.
/// Bindings are keyed by the provider method's **declared return type**, so
/// nothing outside [AnalyticsModule] ever names the concrete class — tests
/// swap in a fake by providing their own [AnalyticsService] binding.
abstract class AnalyticsService {
  void track(String event);
}
