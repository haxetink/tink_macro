package;

import haxe.unit.TestCase;

import tink.macro.TypeMap;
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
  
}