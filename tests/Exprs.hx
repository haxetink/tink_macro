package ;

import haxe.macro.Context;
import haxe.macro.Expr;
using tink.MacroApi;

class Exprs extends Base {
  function exprEq(e1:Expr, e2:Expr) {
    assertEquals(e1.toString(), e2.toString());
  }

  function testShort() {
    for (i in 0...100) {
      var id = (100 * i).shortIdent();
      Context.parseInlineString(id, (macro null).pos);
      assertTrue(id.length <= 3);
    }
  }

  function testEval() {
    var expr = macro (untyped {foo:[{bar:234},'bar']});
    var str = Std.string(untyped {foo:[{bar:234},'bar']});
    assertEquals(Std.string(expr.eval()), Std.string(untyped {foo:[{bar:234},'bar']}));

    // This doesn't work in Haxe 4.3, which is correct, because typeExpr types an expression into target context, rather than macro context
    // assertEquals(Std.string(Context.typeExpr(expr).eval()), Std.string(untyped {foo:[{bar:234},'bar']}));
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
    function test(x:Expr, e:Expr, ?options)
      exprEq(x, e.yield(yielder, options));

    test(macro @yield foo, macro foo);
    test(macro @yield (foo), macro (foo));
    test(macro for (_) @yield foo, macro for (_) foo);
    test(macro while (_) @yield foo, macro while (_) foo);
    test(macro @yield while (_) foo, macro while (_) foo, { leaveLoops: true });
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
    exprEq(
      macro {
        new Foo<Bar>(1, 2, 3);
        Bar.foo();
      },
      (macro {
        new X(1, 2, 3);
        Y.foo();
      }).substParams([
        'X' => macro : Foo<Bar>,
        'Y' => macro : Bar
      ])
    );
  }

  function testConcat() {
    exprEq(macro {a; b;}, (macro a).concat(macro b));
    exprEq(macro {a; b; c;}, (macro {a; b;}).concat(macro c));
    exprEq(macro {a; b; c;}, (macro a).concat(macro {b; c;}));
    exprEq(macro {a; b; c; d;}, (macro {a; b;}).concat(macro {c; d;}));
  }
}