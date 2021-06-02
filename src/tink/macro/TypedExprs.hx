package tink.macro;

import haxe.macro.Context;
import haxe.macro.Type;
import haxe.ds.Option;
using haxe.macro.Tools;

class TypedExprs {

  static public function extractAll<T>(t:TypedExpr, f:TypedExpr->Option<T>):Array<T> {
    var out = [];
    function rec(t:TypedExpr)
      if (t != null) {
        switch f(t) {
          case Some(v): out.push(v);
          default:
        }
        t.iter(rec);
      }
    rec(t);
    return out;
  }

  static public function extract<T>(t:TypedExpr, f:TypedExpr->Option<T>):Option<T> {
    try extractAll(t, function (t) {
      var ret = f(t);
      if (ret != None)
        throw ret;
      return ret;
    })
    catch (e:Option<Dynamic>) return cast e;
    return None;
  }

  static public function eval(t:TypedExpr)
    return Exprs.eval(Context.storeTypedExpr(t));

  static public function isThis(t:TypedExpr):Bool
    return switch t {
      case null: false;
      case { expr: TConst(TThis) | TLocal({ name: '`this' })}: true;
      default: false;
    }

  static public inline function hasThis(t)
    return contains(t, isThis);

  static public function findAll(t:TypedExpr, f:TypedExpr->Bool):Array<TypedExpr>
    return extractAll(t, collect(f));

  static public function find(t:TypedExpr, f:TypedExpr->Bool):Option<TypedExpr>
    return extract(t, collect(f));

  static public function contains(t:TypedExpr, f:TypedExpr->Bool):Bool
    return find(t, f) != None;

  static inline function collect(f)
    return function (t) return if (f(t)) Some(t) else None;
}