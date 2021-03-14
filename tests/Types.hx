package ;

#if macro
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
  }

  #if haxe4
  function testFinal() {
    var t = macro : {
      final foo:Int;
    };
    switch t.toType().sure() {
      case TAnonymous(_.get().fields => [f]): assertTrue(f.isFinal);
      default:
    }
  }
  #end

  function testExpr() {
    assertEquals('VarChar<255>', (macro : VarChar<255>).toType().sure().toComplex().toString());
  }

  function testToComplex() {
    assertEquals('String', Context.getType('String').toComplex().toString());
    assertEquals('tink.CoreApi.Noise', Context.getType('tink.CoreApi.Noise').toComplex().toString());
  }

  function testDeduceCommonType() {
    function ct2t(ct:ComplexType) return ct.toType().sure();
    assertEquals('StdTypes.Float', tink.macro.Types.deduceCommonType([(macro:Float), (macro:Int)].map(ct2t)).sure().toComplex().toString());
    assertEquals('Types.CommonI1', tink.macro.Types.deduceCommonType([(macro:Types.CommonA), (macro:Types.CommonB), (macro:Types.CommonC)].map(ct2t)).sure().toComplex().toString());
    assertEquals('Types.CommonI2', tink.macro.Types.deduceCommonType([(macro:Types.CommonB), (macro:Types.CommonC)].map(ct2t)).sure().toComplex().toString());
    // assertEquals('Types.CommonI3', tink.macro.Types.deduceCommonType([(macro:Types.CommonC)].map(ct2t)).sure().toComplex().toString());
  }
}
#end

interface CommonI1 {}
interface CommonI2 {}
interface CommonI3 {}
class CommonA implements CommonI1 {}
class CommonB implements CommonI2 implements CommonI1 {}
class CommonC implements CommonI3 implements CommonI2 implements CommonI1 {}