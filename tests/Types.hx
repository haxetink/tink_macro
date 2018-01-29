package ;

import haxe.macro.Expr;
import haxe.macro.Context;

using tink.CoreApi;
using tink.MacroApi;

class Types extends Base {
  function type(c:ComplexType)
    return c.toType().sure();
    
  function resolve(type:String)
    return Context.getType(type);
    
  inline function assertSuccess<S, F>(o:Outcome<S, F>)
    assertTrue(o.isSuccess());
    
  inline function assertFailure<S, F>(o:Outcome<S, F>)
    assertFalse(o.isSuccess());
    
  function testIs() {
    assertSuccess(resolve('Int').isSubTypeOf(resolve('Float')));
    assertFailure(resolve('Float').isSubTypeOf(resolve('Int')));
  }  
  
  function testFields() {
    var expected = type(macro : Void -> Iterator<Arrayish>),
      iterator = type(macro : haxe.ds.StringMap<Arrayish>).getFields(true).sure().filter(function (c) return c.name == 'iterator')[0];
    
    assertSuccess(iterator.type.isSubTypeOf(expected));
    assertSuccess(expected.isSubTypeOf(iterator.type));
  }
  
  function testConvert() {
    assertSuccess((macro : Int).toType());
    assertFailure((macro : Tni).toType());
    function blank()
      return type(MacroApi.pos().makeBlankType());
    
    var bool = type(macro : Bool);
    assertTrue(blank().isSubTypeOf(bool).isSuccess());
    assertTrue(bool.isSubTypeOf(blank()).isSuccess());
    
    MacroApi.pos().makeBlankType().toString();
  }

  function testToComplex() {
    assertEquals('String', Context.getType('String').toComplex().toString());
    assertEquals('tink.CoreApi.Noise', Context.getType('tink.CoreApi.Noise').toComplex().toString());
  }
}