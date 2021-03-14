import haxe.macro.Context;
import haxe.macro.Context.typeof;
using tink.MacroApi;

class ExactStrings extends Base {
  function test() {
    function expect(s:String, e, ?pos)
      assertEquals(s, typeof(e).toExactString(), pos);

    expect('Dummy', macro new Dummy());
    expect('nested.Dummy', macro new nested.Dummy());
    expect('Dummy.Private', macro Dummy.p);
    expect('nested.Dummy.Private', macro nested.Dummy.p);
    expect('{ @foo var x:Int; }', macro (null:{@foo var x:Int;}));
    expect('{ @bar var x:Int; }', macro (null:{@bar var x:Int;}));
    expect('{ var x:Int; var y:Int; }', macro (null:{x:Int,y:Int}));
    expect('{ var x:Int; var y:Int; }', macro (null:{y:Int,x:Int}));
    expect('{ function foo(x:Int, ?y:Int):Void; }', macro (null:{ function foo(x:Int, ?y:Int):Void; }));
  }
}