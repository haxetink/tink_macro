package tink.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import tink.macro.TypeMap;

using tink.MacroApi;
using haxe.macro.Tools;

typedef BuildContextN = {
  pos:Position,
  types:Array<Type>,
  usings:Array<TypePath>,
  name:String,
}


typedef BuildContext = {
  pos:Position,
  type:Type,
  usings:Array<TypePath>,
  name:String,
}

typedef BuildContext2 = {>BuildContext,
  type2:Type,
}

typedef BuildContext3 = {>BuildContext2,
  type3:Type,
}

class BuildCache { 
  
  static var cache = new Map();
  
  static public function getType3(name, ?types, ?pos:Position, build:BuildContext3->TypeDefinition) {
     if (types == null)
      switch Context.getLocalType() {
        case TInst(_.toString() == name => true, [t1, t2, t3]):
          types = { t1: t1, t2: t2, t3: t3 };
        default:
          throw 'assert';
      }  
      
    var t1 = types.t1.toComplexType(),
        t2 = types.t2.toComplexType(),
        t3 = types.t2.toComplexType();
        
    return getType(name, (macro : { t1: $t1, t2: $t2, t3: $t3 } ).toType(), pos, function (ctx) return build({
      type: types.t1,
      type2: types.t2,
      type3: types.t3,
      pos: ctx.pos,
      name: ctx.name,
      usings: ctx.usings
    }));   
  }
  
  static public function getTypeN(name, ?types, ?pos:Position, build:BuildContextN->TypeDefinition) {
    
    if (pos == null)
      pos = Context.currentPos();
    
    if (types == null)
      switch Context.getLocalType() {
        case TInst(_.toString() == name => true, params):
          types = params;
        default:
          throw 'assert';
      }  
      
    var compound = ComplexType.TAnonymous([for (i in 0...types.length) {
      name: 't$i',
      pos: pos,
      kind: FVar(switch types[i] {
        case TInst(_.get().kind => KExpr(e), _): 
          TPath('tink.macro.ConstParam'.asTypePath([TPExpr(e)]));
        case t: t.toComplex();
      }),
    }]).toType();
        
    return getType(name, compound, pos, function (ctx) return build({
      types: types,
      pos: ctx.pos,
      name: ctx.name,
      usings: ctx.usings
    }));
  }  
  
  static public function getType2(name, ?types, ?pos:Position, build:BuildContext2->TypeDefinition) {
    if (types == null)
      switch Context.getLocalType() {
        case TInst(_.toString() == name => true, [t1, t2]):
          types = { t1: t1, t2: t2 };
        default:
          throw 'assert';
      }  
      
    var t1 = types.t1.toComplexType(),
        t2 = types.t2.toComplexType();
        
    return getType(name, (macro : { t1: $t1, t2: $t2 } ).toType(), pos, function (ctx) return build({
      type: types.t1,
      type2: types.t2,
      pos: ctx.pos,
      name: ctx.name,
      usings: ctx.usings
    }));
  }

  static public function getParams(name:String, ?pos:Position)     
    return
      switch Context.getLocalType() {
        case TInst(_.toString() == name => true, v):
          Success(v);
        case TInst(_.get() => { pos: pos }, _):
          pos.makeFailure('Expected $name');
        case v:
          pos.makeFailure('$v should be a class');
      }  

  static public function getParam(name:String, ?pos:Position)     
    return
      getParams(name, pos)
        .flatMap(function (args:Array<Type>) return switch args {
          case [v]: Success(v);
          case []: pos.makeFailure('type parameter expected');
          default: pos.makeFailure('too many parameters');
        });

  static public function getType(name, ?type, ?pos:Position, build:BuildContext->TypeDefinition) {
    
    if (type == null)
      type = getParam(name, pos).sure();
      
    var forName = 
      switch cache[name] {
        case null: cache[name] = new Group(name);
        case v: v;
      }
    
    return forName.get(type, pos.sanitize(), build);  
  }
}

private typedef Entry = {
  name:String,
}

private class Group {
  
  var name:String;
  var counter = 0;
  var entries = new TypeMap<Entry>();
  
  public function new(name) {
    this.name = name;
  }
  
  public function get(type:Type, pos:Position, build:BuildContext->TypeDefinition):Type {
    
    function make(path:String) {
      var usings = [];
      var def = build({
        pos: pos, 
        type: type, 
        usings: usings, 
        name: path.split('.').pop()
      });

      entries.set(type, { name: path } );
      Context.defineModule(path, [def], usings);
      return Context.getType(path);
    }

    function doMake() 
      while (true) 
        switch '$name${counter++}' {
          case _.definedType() => Some(_):
          case v:
            return make(v);
        } 

    return 
      switch entries.get(type) {
        case null:
          doMake();
        case v:
          switch v.name.definedType() {
            case Some(v): v;
            default: doMake();
          }
      }
  }
}