package ;

import haxe.macro.Context;
import haxe.macro.Expr;
using tink.Macro;

class Positions extends Base {
	function stringCompare<A>(v1:A, v2:A) 
		assertEquals(Std.string(v1), Std.string(v2));
	
	function testSanitize() {
		var p:Position = null;
		stringCompare(Context.currentPos(), p.sanitize());
		p = Context.makePosition({ min: 0, max: 10, file: 'foo.txt' });
		stringCompare(p, p);
	}
	
	function testBlank() {
		var p:Position = null;
		var t = p.makeBlankType();
		stringCompare('TMono(<mono>)', cast t.toType().sure());
	}
}