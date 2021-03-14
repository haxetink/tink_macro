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
  var pos(default, never):Position;
  var type(default, never):Type;
  var usings(default, never):Array<TypePath>;
  var name(default, never):String;
}

typedef BuildContext2 = {>BuildContext,
  var type2(default, never):Type;
}

typedef BuildContext3 = {>BuildContext2,
  var type3(default, never):Type;
}

class BuildCache {

  @:persistent static var cache = new Map();

  static public function getType3(name, ?types, ?pos:Position, build:BuildContext3->TypeDefinition, ?normalizer:Type->Type) {
    return _getTypeN(name, 3, switch types {
      case null: null;
      case v: [types.t1, types.t2, types.t3];
    }, pos, ctx -> build({
      pos: ctx.pos,
      type: ctx.types[0],
      type2: ctx.types[1],
      type3: ctx.types[2],
      usings: ctx.usings,
      name: ctx.name
    }), normalizer);
  }

  static function _getTypeN(name, length, ?types, ?pos:Position, build:BuildContextN->TypeDefinition, ?normalizer:Type->Type) {

    if (pos == null)
      pos = Context.currentPos();

    if (types == null)
      switch Context.getLocalType() {
        case TInst(_.toString() == name => true, params):
          types = params;
        case t:
          pos.error('expected $name but found ${t.toString()}');
      }

    if (length != -1 && types.length != length)
      pos.error('expected $length parameter${if (length == 1) '' else 's'}');

    var forName =
      switch cache[name] {
        case null: cache[name] = new Group(name);
        case v: v;
      }

    var ret = forName.get(types, pos.sanitize(), build, normalizer);
    ret.getFields();// workaround for https://github.com/HaxeFoundation/haxe/issues/7905
    return ret;
  }

  static public function getType2(name, ?types, ?pos:Position, build:BuildContext2->TypeDefinition, ?normalizer:Type->Type)
    return _getTypeN(name, 2, switch types {
      case null: null;
      case v: [types.t1, types.t2];
    }, pos, ctx -> build({
      pos: ctx.pos,
      type: ctx.types[0],
      type2: ctx.types[1],
      usings: ctx.usings,
      name: ctx.name
    }), normalizer);

  static public function getParams(name:String, ?pos:Position, ?count:Int)
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

  static public function getType(name, ?type, ?pos:Position, build:BuildContext->TypeDefinition, ?normalizer:Type->Type) {
    return _getTypeN(name, 1, switch type {
      case null: null;
      case v: [v];
    }, pos, ctx -> build({
      pos: ctx.pos,
      type: ctx.types[0],
      usings: ctx.usings,
      name: ctx.name
    }), normalizer);
  }
}

private class Group {//TODO: this is somewhat obsolete

  var name:String;

  public function new(name) {
    this.name = name;
  }

  public function get(types:Array<Type>, pos:Position, build:BuildContextN->TypeDefinition, ?normalizer):Type {

    var normalized = switch normalizer {
      case null: function (t) return Context.follow(t);
      case f: f;
    }

    types = types.map(normalizer);

    var retName = name + Sisyphus.exactParams(types);

    return switch retName.definedType() {
      case Some(v): v;
      case None:
        var usings = [];
        var ret = build({
          pos: pos,
          types: types,
          usings: usings,
          name: retName
        });

        ret.meta.push({
          name: ':native',
          params: [macro $v{name + '_'+ Context.signature(name)}],
          pos: (macro null).pos,
        });

        Context.defineModule(retName, [ret], usings);
        Context.getType(retName);
    }
  }
}