package tink.macro;

import haxe.macro.Printer;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.Tools;
using tink.MacroApi;
using tink.CoreApi;

import haxe.macro.Type.Ref;

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
        case AccNormal: 'default';
        case AccInline: if (read) 'default' else 'never';
        case AccNo: 'null';
        case AccNever #if haxe4 | AccCtor #end: 'never';
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

  static public function mapTypeParams(a:Array<TypeParam>, f)
    return
      if (a == null) null;
      else [for (p in a) switch p {
        case TPType(t): TPType(t.map(f));
        default: p;
      }];

  static public function mapTypeParamDecls(a:Array<TypeParamDecl>, f:ComplexType->ComplexType):Array<TypeParamDecl>
    return
      if (a == null) null;
      else [for (p in a) {
        name: p.name,
        meta: p.meta,
        params: mapTypeParamDecls(p.params, f),
        constraints: switch p.constraints {
          case null: null;
          case a: [for (t in a) map(t, f)];
        }
      }];

  static public function mapTypePath(p:TypePath, transform):TypePath
    return {
      name: p.name,
      pack: p.pack,
      sub: p.sub,
      params: mapTypeParams(p.params, transform),
    }

  static public function map(ct:ComplexType, transform:ComplexType->ComplexType) {
    if (ct == null)
      return null;
    inline function rec(ct)
      return map(transform(ct), transform);

    function mapFields(fields:Array<Field>):Array<Field>
      return [for (f in fields) {
        name: f.name,
        pos: f.pos,
        kind: switch f.kind {
          case FVar(t, e): FVar(rec(t), e);
          case FProp(get, set, t, e): FProp(get, set, rec(t), e);
          case FFun(f): FFun(Functions.mapSignature(f, transform));
        },
        access: f.access,
        meta: switch f.meta {
          case null: null;
          case a: [for (m in a) {
            name: m.name,
            pos: m.pos,
            params: [for (e in m.params) e.mapTypes(transform)],
          }];
        },
        doc: f.doc,
      }];
    return transform(switch ct {
      case TParent(t): TParent(rec(t));
      #if haxe4
      case TNamed(n, t): TNamed(n, rec(t));
      case TIntersection(tl): TIntersection([for (t in tl) rec(t)]);
      #end
      case TOptional(t): TOptional(rec(t));
      case TAnonymous(fields):
        TAnonymous(mapFields(fields));
      case TPath(p):
        TPath(mapTypePath(p, transform));
      case TExtend(paths, fields):
        TExtend([for (p in paths) mapTypePath(p, transform)], mapFields(fields));
      case TFunction(args, ret):
        TFunction([for (a in args) rec(a)], rec(ret));
    });
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
            ret = Success([
              for (field in ret.sure()) ({
                name: field.name,
                type: haxe.macro.TypeTools.applyTypeParameters(field.type, c.params, params),
                pos: field.pos,
                meta: field.meta,
                doc: field.doc,
                expr: function () return field.expr(),
                isPublic: field.isPublic,
                params: field.params,
                kind: field.kind,
                overloads: field.overloads,
                #if haxe4
                isExtern: field.isExtern,
                isFinal: field.isFinal,
                #if (haxe >= version("4.2.0-rc.1"))
                isAbstract: field.isAbstract,
                #end
                #end
              }:ClassField)
            ]);
          }
          #if !haxe4
          fieldsCache.remove(id);//TODO: find a proper solution to avoid stale cache
          #end
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

  static public function deduceCommonType(types:Array<Type>):Outcome<Type, Error> {
    var exprs = types.map(function(t) {
      var ct = t.toComplex();
      return macro (null:$ct);
    });

    return switch (macro $a{exprs}).typeof() {
      case Success(TInst(_, [v])): Success(v);
      case Success(_): throw 'unreachable';
      case Failure(e): Failure(new Error('Unable to deduce common type among $types'));
    }
  }

  /// like haxe.macro.TypeTools.toString, but not lossy
  static public function toExactString(t:Type)
    return Sisyphus.toExactString(t);

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
      case TLazy(_) | TType(_): rec(Context.follow(type, once));
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

    #if haxe4
    return Success(TIntersection(types));
    #end
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

  static public function compare(t1:Type, t2:Type, ?follow:Bool = true)
    return Sisyphus.compare(t1, t2, follow);

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