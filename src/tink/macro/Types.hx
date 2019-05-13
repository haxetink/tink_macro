package tink.macro;

import haxe.macro.Printer;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.Tools;
using tink.MacroApi;
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
      
      
  static public function getPosition(t:Type)
    return
      switch t {
        case TInst(_.get() => {pos: pos}, _)
        | TAbstract(_.get() => {pos: pos}, _)
        | TType(_.get() => {pos: pos}, _)
        | TEnum(_.get() => {pos: pos}, _) : Success(pos);
        case TMono(_.get() => t) if (t != null): getPosition(t);
        case TLazy(f): getPosition(f());
        case TDynamic(v) if(v != null): getPosition(v);
        default: Failure('type "$t" has no position');
      }
      
      

  static public function toString(t:ComplexType)
    return new Printer().printComplexType(t);

  static public function unifiesWith(from:Type, to:Type)
    return Context.unify(from, to);

  static public function isSubTypeOf(t:Type, of:Type, ?pos)
    return
      if (Context.unify(t, of)) ECheckType(ECheckType(macro null, toComplex(t)).at(pos), toComplex(of)).at(pos).typeof();
      else Failure(new Error(t.toString() + ' should be ' + of.toString(), pos.sanitize()));

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

  static public function reduce(type:Type, ?once) {
    function rec(t:Type)
      return if (once) t else reduce(t, false);
    return switch type {
      case TAbstract(_.get() => { name: 'Null', pack: [] }, [t]): rec(t);
      case TLazy(f): rec(f());
      case TType(_, _): rec(Context.follow(type, once));
      default: type;
    }
  }

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

  static public function intersect(types:Array<ComplexType>, ?pos:Position):Outcome<ComplexType, Error> {
    
    if (types.length == 1) return Success(types[1]);

    var paths = [],
        fields = [];

    for (t in types)
      switch t {
        case TPath(p): paths.push(p);
        case TAnonymous(f): 
          
          for (f in f) fields.push(f);

        case TExtend(p, f): 
          
          for (f in f) fields.push(f);
          for (p in p) paths.push(p);

        default:
          
          return Failure(new Error(t.toString() + ' cannot be interesected', pos));
      }

    return Success(TExtend(paths, fields));
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

  static public function compare(t1:Type, t2:Type, ?follow:Bool = true) {
    if (follow) {
      t1 = t1.reduce();
      t2 = t2.reduce();
    }
    
    return switch [t1, t2] {
      case [TMono(_.get() => t1), TMono(_.get() => t2)]:
        switch [t1, t2] {
          case [null, null]: 0;
          case [null, _]: -1;
          case [_, null]: 1;
          case _: compare(t1, t2, follow);
        }
      case [TInst(c1, p1), TInst(c2, p2)]:
        switch Reflect.compare(c1.toString(), c2.toString()) {
          case 0: compareMultiple(p1, p2, follow);
          case v: v;
        }
        
      case [TType(_.get() => {type: t1}, p1), TType(_.get() => {type: t2}, p2)]: 
        switch compare(t1, t2) {
          case 0: compareMultiple(p1, p2);
          case v: v;
        }
        
      case [TFun(a1, r1), TFun(a2, r2)]:
        switch compare(r1, r2) {
          case 0: compareMultiple([for(a in a1) a.t], [for(a in a2) a.t]);
          case v: v;
        }
        
      case [TAnonymous(_.get() => {fields: f1}), TAnonymous(_.get() => {fields: f2})]: 
        switch [f1.length, f2.length] {
          case [l1, l2] if(l1 == l2):
            f1.sort(function(f1, f2) return Reflect.compare(f1.name, f2.name));
            f2.sort(function(f1, f2) return Reflect.compare(f1.name, f2.name));
            compareArray(f1, f2, compareClassField);
          case [l1, l2]:
            l1 - l2;
        }
        
      case [TDynamic(null), TDynamic(null)]: 
        0;
      case [TDynamic(null), TDynamic(_)]:
        1;
      case [TDynamic(_), TDynamic(null)]: 
        -1;
      case [TDynamic(t1), TDynamic(t2)]: 
        compare(t1, t2);
      case [TLazy(f1), TLazy(f2)]: 
        compare(f1(), f2());
      case _:
        t1.getIndex() - t2.getIndex();
    }
  }
  
  static function compareClassField(f1:ClassField, f2:ClassField) {
    return switch Reflect.compare(f1.name, f2.name) {
      case 0:
        switch compare(f1.type, f2.type) {
          case 0:
            var m1 = [for(m in f1.meta.get()) m.toString()];
            var m2 = [for(m in f2.meta.get()) m.toString()];
            m1.sort(Reflect.compare);
            m2.sort(Reflect.compare);
            compareArray(m1, m2, function(m1, m2) return Reflect.compare(m1, m2));
          case v: v;
        }
      case v: v;
    }
  }
  
  static function compareMeta(m1:MetadataEntry, m2:MetadataEntry) {
    return switch Reflect.compare(m1.name, m2.name) {
      case 0: compareArray(m1.params, m2.params, function(e1, e2) return Reflect.compare(e1.toString(), e2.toString()));
      case v: v;
    }
  }
  
  static function compareArray<T>(a1:Array<T>, a2:Array<T>, compare:T->T->Int) {
    return switch [a1.length, a2.length] {
      case [l1, l2] if(l1 == l2):
        for(i in 0...l1) {
          switch compare(a1[i], a2[i]) {
            case 0: // skip
            case v: return v;
          }
        }
        0;
      case [l1, l2]:
        l1 - l2;
    }
  }
  
  static function compareMultiple(t1:Array<Type>, t2:Array<Type>, follow = true)  {
    return compareArray(t1, t2, function(t1, t2) return compare(t1, t2, follow));
  }

  static var SUGGESTIONS = ~/ \(Suggestions?: .*\)$/;

  static public function getFieldSuggestions(type:ComplexType, name:String):String 
    return switch (macro (null : $type).$name).typeof() {
      case Failure(SUGGESTIONS.match(_.message) => true): SUGGESTIONS.matched(0);
      default: '';
    }

  static public function toDecl(p:TypeParameter):TypeParamDecl 
    return {
      name: p.name,
      constraints: switch p.t {
        case TInst(_.get() => { kind: KTypeParameter(c)}, _): [for(c in c) c.toComplex()];
        case _: throw 'unreachable';
      }
    }

  static public function toTypeParam(p:TypeParameter):TypeParam
    return TPType(p.t.toComplex());

}
