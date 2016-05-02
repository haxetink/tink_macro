package tink.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import tink.macro.TypeMap;

typedef BuildContext = {
  pos:Position,
  type:Type,
  usings:Array<TypePath>,
  name:String,
}

class BuildCache { 
  
  static var cache = init();
  
  static function init() {
    
    function refresh() {
      cache = new Map();
      return true;
    }
    
    Context.onMacroContextReused(refresh);
    refresh();
    
    return cache;
  }
  
  static public function getType(name, ?type, ?pos:Position, build:BuildContext->TypeDefinition) {
    
    if (pos == null)
      pos = Context.currentPos();
    
    if (type == null)
      switch Context.getLocalType() {
        case TInst(_.toString() == name => true, [v]):
          type = v;
        default:
          throw 'assert';
      }  
      
    var forName = 
      switch cache[name] {
        case null: cache[name] = new TypeMap();
        case v: v;
      }
          
    if (!forName.exists(type)) {
      var path = '$name${Lambda.count(forName)}',
          usings = [];
          
      var def = build({
        pos: pos, 
        type: type, 
        usings: usings, 
        name: path.split('.').pop()
      });
      
      Context.defineModule(path, [def], usings);
      forName.set(type, Context.getType(path));
    }
    
    return forName.get(type);  
  }
}