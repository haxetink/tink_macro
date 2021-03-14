package;

import haxe.unit.TestCase;
import haxe.macro.Expr;

using tink.MacroApi;

class TypeMapTest extends TestCase {

  function testMap() {
    var t = new TypeMap();
    var t1 = (macro [{ foo: [{ bar: '5' }]}]).typeof().sure();
    var t2 = (macro [{ foo: [{ bar: 5 }]}]).typeof().sure();
    var t3 = (macro [{ foo: [{ bar: 5 }]}]).typeof().sure();
    var t4 = (macro [{ foo: [({ bar: 5 }:{ @foo var bar:Int; })]}]).typeof().sure();

    t.set(t1, 0);
    assertEquals(Lambda.count(t), 1);
    t.set(t2, 1);
    assertEquals(Lambda.count(t), 2);
    t.set(t1, 2);
    assertEquals(Lambda.count(t), 2);
    t.set(t2, 3);
    t.set(t3, 3);
    assertEquals(Lambda.count(t), 2);
    t.set(t4, 4);
    assertEquals(Lambda.count(t), 3);

    assertEquals(t.get(t1), 2);
    assertEquals(t.get(t2), 3);

    assertTrue(true);
  }

  function testNormalization() {
    for (settings in [
      { count: 4, map: new TypeMap(TypeMap.noFollow)},
      { count: 2, map: new TypeMap(TypeMap.keepNull)},
      { count: 1, map: new TypeMap()},
    ]) {

      function set(ct:ComplexType)
        settings.map.set(ct.toType().sure(), ct);

      set(macro : String);
      set(macro : MyString);
      set(macro : Null<String>);
      set(macro : Null<MyString>);

      assertEquals(settings.count, Lambda.count(settings.map));
    }
  }
}