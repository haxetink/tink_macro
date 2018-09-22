package tink.macro;

import haxe.Constraints.IMap;
import haxe.ds.BalancedTree;
import haxe.macro.Context;
import haxe.macro.Type;

using tink.MacroApi;

class TypeMap<V> extends BalancedTree<Type, V> implements IMap<Type, V> {
  var follow:Bool;
  
  public function new(?noFollow:Bool) {
    this.follow = noFollow != true;
    super();
  }
  
  override function compare(k1:Type, k2:Type):Int
    return k1.compare(k2, follow);
  
}