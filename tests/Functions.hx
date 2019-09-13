import haxe.macro.Context;
import haxe.macro.Expr;
using tink.MacroApi;

class Functions extends Base {
  function test() {
    var f:Function = (macro function () {}).getFunction().sure();
    f.asExpr('foo');
    assertTrue(true);
  }
}