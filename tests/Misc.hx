import tink.MacroApi;
import haxe.unit.TestCase;

using tink.CoreApi;

class Misc extends TestCase {
  function testMain() {
    assertEquals('Run', MacroApi.getMainClass().force());
  }
}