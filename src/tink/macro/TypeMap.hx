package tink.macro;

import haxe.Constraints.IMap;
import haxe.ds.BalancedTree;
import haxe.macro.Context;
import haxe.macro.Type;

using haxe.macro.Tools;
using tink.MacroApi;

class TypeMap<V> extends BalancedTree<Type, V> implements IMap<Type, V> {
  var follow:Bool;
  
  public function new(?noFollow:Bool) {
    this.follow = noFollow != true;
    super();
  }
  
  override function compare(k1:Type, k2:Type):Int {
    if (follow) {
      k1 = k1.reduce();
      k2 = k2.reduce();
    }
    //trace(k1.toString());
    //trace(k2.toString());
    return switch k1.getIndex() - k2.getIndex() {
      case 0: Reflect.compare(k1.toString(), k2.toString());//TODO: this may be rather expensive and not very reliable
      case v: v;
    }
  }
  
}