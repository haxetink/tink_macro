package;

import haxe.unit.TestCase;

using tink.MacroApi;
using haxe.macro.Context;

class TypeMapTest extends TestCase {

  function testMap() {
    var t = new TypeMap();
    var t1 = (macro [{ foo: [{ bar: '5' }]}]).typeof();
    var t2 = (macro [{ foo: [{ bar: 5 }]}]).typeof();
    
    t.set(t1, 0);
    assertEquals(Lambda.count(t), 1);
    t.set(t2, 1);
    assertEquals(Lambda.count(t), 2);
    t.set(t1, 2);
    assertEquals(Lambda.count(t), 2);
    t.set(t2, 3);
    assertEquals(Lambda.count(t), 2);
    
    assertEquals(t.get(t1), 2);
    assertEquals(t.get(t2), 3);
    
    assertTrue(true);
  }
  
  function testAnonWithReducibleField() {
    var t = new TypeMap();
    var t1 = (macro:{i:Null<Int>}).toType().sure();
    var t2 = (macro:{i:Null<Null<Int>>}).toType().sure();
    t.set(t1, true);
    assertTrue(t.exists(t2));
    
  }
  
}