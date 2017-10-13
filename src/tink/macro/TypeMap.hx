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
        Reflect.compare(stringify(k1), stringify(k2));//much to my surprise, this actually seems to work (at least with 3.4)
      case v: v;
    }
  }
  
  static var NESTED_NULL_REGEX = ~/Null<Null<([^>]*)>>/g; // a hack to flatten nested Null<T>
  function stringify(type:Type) {
    var s = type.toString();
    while(NESTED_NULL_REGEX.match(s))
      s = NESTED_NULL_REGEX.replace(s, "Null<$1>");
    return s;
  }
  
}