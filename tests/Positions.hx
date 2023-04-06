package ;

import haxe.macro.Context;
import haxe.macro.Expr;

using tink.MacroApi;

class Positions extends Base {
  
  function testSanitize() {
    var p:Position = null;
    stringCompare(Context.currentPos(), p.sanitize());
    p = Context.makePosition({ min: 0, max: 10, file: 'foo.txt' });
    stringCompare(p, p);
  }
  
  function testBlank() {
    var p:Position = null;
    var t = p.makeBlankType();
    stringCompare('TMono(<mono>)', cast t.toType().sure().reduce());
  }
}