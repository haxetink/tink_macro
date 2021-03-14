package tink.macro;

import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.Tools;
using tink.MacroApi;

class Sisyphus {

  static function nullable(complexType : ComplexType) : ComplexType return macro : Null<$complexType>;

  static function toField(cf : ClassField) : Field return {
    function varAccessToString(va : VarAccess, getOrSet : String) : String return {
      switch (va) {
        case AccNormal: "default";
        case AccNo: "null";
        case AccNever: "never";
        case AccResolve: throw "Invalid TAnonymous";
        case AccCall: getOrSet;
        case AccInline: "default";
        case AccRequire(_, _): "default";
        default: throw "not implemented";
      }
    }
    if (cf.params.length == 0) {
      name: cf.name,
      doc: cf.doc,
      access:
        (cf.isPublic ? [ APublic ] : [ APrivate ])
          #if haxe4 .concat(if (cf.isFinal) [AFinal] else []) #end
        ,
      kind: switch([ cf.kind, cf.type ]) {
        #if haxe4
        case [ FVar(_, _), ret ] if (cf.isFinal):
          FVar(toComplexType(ret), null);
        #end
        case [ FVar(read, write), ret ]:
          FProp(
            varAccessToString(read, "get"),
            varAccessToString(write, "set"),
            toComplexType(ret),
            null
          );
        case [ FMethod(_), TFun(args, ret) ]:
          FFun({
            args: [
              for (a in args) {
                name: a.name,
                opt: a.opt,
                type: toComplexType(a.t),
              }
            ],
            ret: toComplexType(ret),
            expr: null,
          });
        default:
          throw "Invalid TAnonymous";
      },
      pos: cf.pos,
      meta: cf.meta.get(),
    } else {
      throw "Invalid TAnonymous";
    }
  }

  static public function toComplexType(type : Null<Type>) : Null<ComplexType> return {
    inline function direct()
      return Types.toComplex(type, { direct: true });
    switch (type) {
      case null:
        null;
      case TEnum(_.get().isPrivate => true, _): direct();
      case TInst(_.get().isPrivate => true, _): direct();
      case TType(_.get().isPrivate => true, _): direct();
      case TAbstract(_.get().isPrivate => true, _): direct();
      case TMono(_): direct();
      case TEnum(_.get() => baseType, params):
        TPath(toTypePath(baseType, params));
      case TInst(_.get() => classType, params):
        switch (classType.kind) {
          case KTypeParameter(_):
            var ct = Types.asComplexType(classType.name);
            switch Types.toType(ct) {
              case Success(TInst(_.get() => cl, _)) if (
                cl.kind.match(KTypeParameter(_))
                && cl.module == classType.module
                && cl.pack.join('.') == classType.pack.join('.')
              ): ct;
              default:
                direct();
            }
          default:
            TPath(toTypePath(classType, params));
        }
      case TType(_.get() => baseType, params):
        TPath(toTypePath(baseType, params));
      case TFun(args, ret):
        TFunction(
          [for (a in args) {
            var t = #if haxe4 TNamed(a.name, #else ( #end toComplexType(a.t));
            if (a.opt) TOptional(t) else t;
          }],
          toComplexType(ret)
        );
      case TAnonymous(_.get() => { fields: fields }):
        TAnonymous([ for (cf in fields) toField(cf) ]);
      case TDynamic(t):
        if (t == null) {
          macro : Dynamic;
        } else {
          var ct = toComplexType(t);
          macro : Dynamic<$ct>;
        }
      case TLazy(f):
        toComplexType(f());
      case TAbstract(_.get() => baseType, params):
        TPath(toTypePath(baseType, params));
      default:
        throw "Invalid type";
    }
  }
  static function toTypePath(baseType : BaseType, params : Array<Type>) : TypePath return {
    var module = baseType.module;
    var name = module.substring(module.lastIndexOf(".") + 1);
    var sub = switch baseType.name {
      case _ == name => true: null;
      case v: v;
    }

    {
      pack: baseType.pack,
      name: name,
      sub: sub,
      params: [for (t in params) switch t {
        case TInst(_.get().kind => KExpr(e), _): TPExpr(e);
        default: TPType(toComplexType(t));
      }],
    }
  }

  static function exactBase<T:BaseType>(r:Ref<T>, params:Array<Type>) {
    var t = r.get();
    var isMain = !t.isPrivate && switch t.pack {
      case []: t.module == t.name || t.module == 'StdTypes';
      default: StringTools.endsWith(t.module, '.${t.name}');
    }

    return (
      if (isMain) t.pack.concat([t.name]).join('.')
      else t.module + '.' + t.name
    ) + switch params {
      case []: '';
      case params:
        '<${params.map(toExactString).join(', ')}>';
    }
  }

  static inline function isFinal(c:ClassField)
    return #if haxe4 c.isFinal #else false #end;

  static function exactAnonField(c:ClassField) {
    var kw =
      switch c.kind {
        case FMethod(_): 'function';
        case FVar(_):
          if (isFinal(c)) 'final' else 'var';
      }

    return [for (m in c.meta.get()) m.toString() + ' '].join('') + '$kw ${c.name}' + (switch c.kind {
      case FVar(read, write):
        (
          if (isFinal(c) || (read == AccNormal && write == AccNormal)) ''
          else '(${read.accessToName()}, ${read.accessToName(false)})'
        ) + ':' + c.type.toExactString();
      case FMethod(_):
        switch haxe.macro.Context.follow(c.type) {
          case TFun(arg, ret): exactSig(arg, ret, ':');
          default: throw 'assert';
        }
    }) + ';';
  }

  static function exactSig(args:Array<{name:String, opt:Bool, t:Type}>, ret:Type, sep:String)
    return '(${[for (a in args) (if (a.opt) '?' else '') + a.name + ':' + toExactString(a.t)].join(', ')})$sep${toExactString(ret)}';

  static public function toExactString(t:Type)
    return switch t {
      case TMono(t): t.toString();
      case TEnum(r, params): exactBase(r, params);
      case TInst(r, params): exactBase(r, params);
      case TType(r, params): exactBase(r, params);
      case TAbstract(r, params): exactBase(r, params);
      case TFun(args, ret): exactSig(args, ret, '->');
      case TAnonymous(a): '{ ${[for (f in a.get().fields) exactAnonField(f)].join(' ')} }';
      case TDynamic(null): 'Dynamic';
      case TDynamic(t): 'Dynamic<${toExactString(t)}>';
      case TLazy(f): toExactString(f());
    }

    static function eager(t:Type)
      return switch t {
        case TLazy(f): eager(f());
        default: t;
      }

    static public function compare(t1:Type, t2:Type, ?follow:Bool = true) {
      if (follow) {
        t1 = t1.reduce();
        t2 = t2.reduce();
      }
      else {
        t1 = eager(t1);
        t2 = eager(t2);
      }

      return switch t1.getIndex() - t2.getIndex() {
        case 0:
          switch Reflect.compare(t1.toString(), t2.toString()) {
            case 0: Reflect.compare(t1.toExactString(), t2.toExactString());
            case v: v;
          }
        case v: v;
      }
    }
}
