package tink.macro;

import haxe.macro.Printer;
import Type in Enums;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using tink.macro.Exprs;
using tink.macro.Positions;
using tink.macro.Functions;
using tink.CoreApi;

class Types {

  static public function definedType(typeName:String)
    return
      try {
        Some(Context.getType(typeName));
      }
      catch (e:Dynamic)
        if (Std.string(e) == 'Type not found \'$typeName\'') None;
        else tink.core.Error.rethrow(e);

  static var types = new Map<Int,Void->Type>();
  static var idCounter = 0;
  static public function getID(t:Type, ?reduced = true)
    return
      if (reduced)
        getID(reduce(t), false);
      else
        switch (t) {
          case TAbstract(t, _): t.toString();
          case TInst(t, _): t.toString();
          case TEnum(t, _): t.toString();
          case TType(t, _): t.toString();
          default: null;
        }

  static public function accessToName(v:VarAccess, ?read = true)
    return
      switch (v) {
        case AccNormal, AccInline: 'default';
        case AccNo: 'null';
        case AccNever: 'never';
        case AccCall: if (read) 'get' else 'set';
        default:
          throw 'not implemented';
      }

  static public function getMeta(type:Type)
    return switch type {
      case TInst(_.get().meta => m, _): [m];
      case TEnum(_.get().meta => m, _): [m];
      case TAbstract(_.get().meta => m, _): [m];
      case TType(_.get() => t, _): [t.meta].concat(getMeta(t.type));
      case TLazy(f): getMeta(f());
      default: [];
    }

  static function getDeclaredFields(t:ClassType, out:Array<ClassField>, marker:Map<String,Bool>) {
    for (field in t.fields.get())
      if (!marker.exists(field.name)) {
        marker.set(field.name, true);
        out.push(field);
      }
    if (t.isInterface)
      for (t in t.interfaces)
        getDeclaredFields(t.t.get(), out, marker);
    else if (t.superClass != null)
      getDeclaredFields(t.superClass.t.get(), out, marker);
  }

  static var fieldsCache = new Map();
  static public function getFields(t:Type, ?substituteParams = true)
    return
      switch (reduce(t)) {
        case TInst(c, params):
          var id = c.toString(),
              c = c.get();
          if (!fieldsCache.exists(id)) {
            var fields = [];
            getDeclaredFields(c, fields, new Map());
            fieldsCache.set(id, Success(fields));
          }
          var ret = fieldsCache.get(id);
          if (substituteParams && ret.isSuccess()) {
            var fields = Reflect.copy(ret.sure());

            for (field in fields)
              field.type = haxe.macro.TypeTools.applyTypeParameters(field.type, c.params, params);
          }
          fieldsCache.remove(id);//TODO: find a proper solution to avoid stale cache
          ret;
        case TAnonymous(anon): Success(anon.get().fields);
        default: Context.currentPos().makeFailure('type $t has no fields');
      }

  static public function getStatics(t:Type)
    return
      switch (reduce(t)) {
        case TInst(t, _): Success(t.get().statics.get());
        default: Failure('type has no statics');
      }

  static public function toString(t:ComplexType)
    return new Printer().printComplexType(t);

  static public function isSubTypeOf(t:Type, of:Type, ?pos)
    return
      ECheckType(ECheckType(macro null, toComplex(t)).at(pos), toComplex(of)).at(pos).typeof();

  static public function isDynamic(t:Type)
    return switch reduce(t) {
      case TDynamic(_): true;
      default: false;
    }

  static public function toType(t:ComplexType, ?pos:Position)
    return (macro @:pos(pos.sanitize()) {
      var v:$t = null;
      v;
    }).typeof();

  static public inline function instantiate(t:TypePath, ?args, ?pos)
    return ENew(t, args == null ? [] : args).at(pos);

  static public function asTypePath(s:String, ?params):TypePath {
    var parts = s.split('.');
    var name = parts.pop(),
      sub = null;
    if (parts.length > 0 && parts[parts.length - 1].charCodeAt(0) < 0x5B) {
      sub = name;
      name = parts.pop();
      if(sub == name) sub = null;
    }
    return {
      name: name,
      pack: parts,
      params: params == null ? [] : params,
      sub: sub
    };
  }

  static public inline function asComplexType(s:String, ?params)
    return TPath(asTypePath(s, params));

  static public inline function reduce(type:Type, ?once)
    return Context.follow(type, once);

  static public function isVar(field:ClassField)
    return switch (field.kind) {
      case FVar(_, _): true;
      default: false;
    }

  static public function register(type:Void->Type):Int {
    types.set(idCounter, type);
    return idCounter++;
  }

  static function paramsToComplex(params:Array<Type>):Array<TypeParam>
    return [for (p in params) TPType(toComplex(p))];

  static function baseToComplex(t:BaseType, params:Array<Type>)
    return asComplexType(t.module + '.' + t.name, paramsToComplex(params));

  static public function toComplex(type:Type, ?options:{ ?direct: Bool }):ComplexType {
    var ret =
      if (options == null || options.direct != true) tink.macro.Sisyphus.toComplexType(type);
      else null;
    if (ret == null)
      ret = lazyComplex(function () return type);
    return ret;
  }

  static public function lazyComplex(f:Void->Type)
    return
      TPath({
        pack : ['tink','macro'],
        name : 'DirectType',
        params : [TPExpr(register(f).toExpr())],
        sub : null,
      });

  static function resolveDirectType()
    return
      switch reduce(Context.getLocalType()) {
        case TInst(_, [TInst(_.get() => { kind: KExpr(e) }, _)]):
          types[e.getInt().sure()]();//When using compiler server, this call throws on occasion, in which case modifying this file (to update mtime and invalidate the cache) will solve the problem
        default:
          throw 'assert';
      }

}
