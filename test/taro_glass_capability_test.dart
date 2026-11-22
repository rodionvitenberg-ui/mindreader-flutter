import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/design_system/taro_glass_capability.dart';
import 'package:mindreader/design_system/taro_glass_mode.dart';

/// Тесты чистого решения [TaroGlassCapability.decide] (без платформенных вызовов).
void main() {
  test('no shader filters -> fake everywhere', () {
    expect(
      TaroGlassCapability.decide(
        shaderFiltersSupported: false,
        isAndroid: true,
        isApple: false,
        androidVulkanSupported: true,
      ),
      TaroGlassMode.fake,
    );
    expect(
      TaroGlassCapability.decide(
        shaderFiltersSupported: false,
        isAndroid: false,
        isApple: true,
        androidVulkanSupported: false,
      ),
      TaroGlassMode.fake,
    );
  });

  test('Apple (Metal) -> glass when shaders supported', () {
    expect(
      TaroGlassCapability.decide(
        shaderFiltersSupported: true,
        isAndroid: false,
        isApple: true,
        androidVulkanSupported: false,
      ),
      TaroGlassMode.glass,
    );
  });

  test('Android uses glass only with Vulkan', () {
    expect(
      TaroGlassCapability.decide(
        shaderFiltersSupported: true,
        isAndroid: true,
        isApple: false,
        androidVulkanSupported: true,
      ),
      TaroGlassMode.glass,
    );
    expect(
      TaroGlassCapability.decide(
        shaderFiltersSupported: true,
        isAndroid: true,
        isApple: false,
        androidVulkanSupported: false,
      ),
      TaroGlassMode.fake,
    );
  });

  test('other platforms default to fake', () {
    expect(
      TaroGlassCapability.decide(
        shaderFiltersSupported: true,
        isAndroid: false,
        isApple: false,
        androidVulkanSupported: false,
      ),
      TaroGlassMode.fake,
    );
  });

  test('render self-test overrides the heuristic', () {
    // Black frame => fake even though Vulkan is reported.
    expect(
      TaroGlassCapability.decide(
        shaderFiltersSupported: true,
        isAndroid: true,
        isApple: false,
        androidVulkanSupported: true,
        selfTestGlassWorks: false,
      ),
      TaroGlassMode.fake,
    );
    // Glass rendered => glass even without Vulkan report.
    expect(
      TaroGlassCapability.decide(
        shaderFiltersSupported: true,
        isAndroid: true,
        isApple: false,
        androidVulkanSupported: false,
        selfTestGlassWorks: true,
      ),
      TaroGlassMode.glass,
    );
    // Failed/timed-out probe (fail-safe false) => fake even on Apple/Vulkan.
    expect(
      TaroGlassCapability.decide(
        shaderFiltersSupported: true,
        isAndroid: false,
        isApple: true,
        androidVulkanSupported: false,
        selfTestGlassWorks: false,
      ),
      TaroGlassMode.fake,
    );
  });
}
