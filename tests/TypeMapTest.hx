package;

import haxe.unit.TestCase;

import tink.macro.TypeMap;
using haxe.macro.Context;
using tink.MacroApi;

class TypeMapTest extends TestCase {

  function testMap() {
    var t = new TypeMap();
    var t1 = (macro [{ foo: [{ bar: '5' }]}]).typeof().sure();
    var t2 = (macro [{ foo: [{ bar: 5 }]}]).typeof().sure();
    var t3 = (macro:Array<{@:foo @:bar var foo:Array<{bar:Int}>;}>).toType().sure();
    var t4 = (macro:Array<{@:bar @:foo var foo:Array<{bar:Int}>;}>).toType().sure();
    
    t.set(t1, 0);
    assertEquals(1, Lambda.count(t));
    t.set(t2, 1);
    assertEquals(2, Lambda.count(t));
    t.set(t1, 2);
    assertEquals(2, Lambda.count(t));
    t.set(t2, 3);
    assertEquals(2, Lambda.count(t));
    t.set(t3, 0);
    assertEquals(3, Lambda.count(t));
    t.set(t4, 1);
    assertEquals(3, Lambda.count(t));
    
    assertEquals(2, t.get(t1));
    assertEquals(3, t.get(t2));
    assertEquals(1, t.get(t3));
    assertEquals(1, t.get(t4));
    
    assertTrue(true);
  }
  
}