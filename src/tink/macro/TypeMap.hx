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
    
    return switch k1.getIndex() - k2.getIndex() {
      case 0: 
        if(Context.unify(k1, k2) && Context.unify(k2, k1))
          0
        else
          Reflect.compare(k1.toString(), k2.toString());//much to my surprise, this actually seems to work (at least with 3.4)
      case v: v;
    }
  }
  
}