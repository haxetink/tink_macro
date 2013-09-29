package ;

import haxe.macro.Expr;
using tink.MacroApi;

class Exprs extends Base {
	function exprEq(e1:Expr, e2:Expr) {
		assertEquals(e1.toString(), e2.toString());
	}
	function testGet() {
		assertEquals('foo', (macro foo).getIdent().sure());
		assertEquals('foo', (macro "foo").getString().sure());
		assertEquals('foo', (macro foo).getName().sure());
		assertEquals('foo', (macro "foo").getName().sure());
		assertEquals(5, (macro 5).getInt().sure());
		
		exprEq(macro [a, b, c], (macro function (a, b, c) [a, b, c]).getFunction().sure().expr);
		assertEquals('a,b,c', [for (arg in (macro function (a, b, c) [a, b, c]).getFunction().sure().args) arg.name].join(','));
		
		assertFalse((macro 'foo').getIdent().isSuccess());
		assertFalse((macro foo).getString().isSuccess());
		assertFalse((macro 5).getName().isSuccess());
		assertFalse((macro 5.1).getInt().isSuccess());
		assertFalse((macro foo).getFunction().isSuccess());
	}
	
	function testShortcuts() {
		assertTrue(true);
	}
	
	function testIterType() {
		assertEquals('Int', (macro [1, 2]).getIterType().sure().getID());
		assertEquals('Int', (macro [1, 2].iterator()).getIterType().sure().getID());
		assertEquals('Int', ECheckType(macro null, macro: Arrayish).at().getIterType().sure().getID());
	}
	
	function testYield() {
		function yielder(e) return macro @yield $e;
		function test(x:Expr, e:Expr)
			exprEq(x, e.yield(yielder));
			
		test(macro @yield foo, macro foo);
		test(macro @yield (foo), macro (foo));
		test(macro for (_) @yield foo, macro for (_) foo);
		test(macro while (_) @yield foo, macro while (_) foo);
		test(macro @yield [while (_) foo], macro [while (_) foo]);
	}
	
	function testSubstitute() {
		exprEq(
			macro foo.call(arg1, arg2), 
			(macro bar.call(x, y)).substitute({ x: macro arg1, y: macro arg2, bar: macro foo })
		);
		
		exprEq(
			macro {
				var x:Map<Int, String> = new Map(),
					y:Array<Float> = [];
			},
			(macro {
				var x:Map<A, B> = new Map(),
					y:C = [];
			}).substParams([
				'A' => macro : Int,
				'B' => macro : String,
				'C' => macro : Array<Float>
			])
		);
	}
}