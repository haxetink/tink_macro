package tink.macro;

import haxe.Constraints.IMap;
import haxe.ds.BalancedTree;
import haxe.macro.Context;
import haxe.macro.Type;

using tink.MacroApi;

class TypeMap<V> extends BalancedTree<Type, V> implements IMap<Type, V> {
  var normalize:Type->Type;

  public function new(?normalize:Type->Type) {
    this.normalize = switch normalize {
      case null: function (t) return t.reduce();
      case fn: fn;
    }
    super();
  }

  override function compare(k1:Type, k2:Type):Int
    return normalize(k1).compare(normalize(k2), false);

  static public function noFollow(t:Type)
    return t;

  static public function keepNull(t:Type):Type
    return switch t {
      case TAbstract(_.get() => { name: 'Null', pack: [] }, [t])
        #if !haxe4 | TType(_.get() => { name: 'Null', pack: []}, [t]) #end
        :
        var ct = keepNull(t).toComplex({ direct: true });
        (macro : Null<$ct>).toType().sure();

      case TLazy(f): keepNull(f());
      case TType(_, _): keepNull(Context.follow(t, true));
      default: t;
    }

}