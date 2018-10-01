package tink.macro;

import haxe.macro.Expr;
import haxe.macro.Type;

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
      access: cf.isPublic ? [ APublic ] : [ APrivate ],
      kind: switch([ cf.kind, cf.type ]) {
        case [ FVar(read, write), ret ]:
          FProp(
            varAccessToString(read, "get"),
            varAccessToString(write, "set"),
            toComplexType(ret),
            null);
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


  public static function toComplexType(type : Null<Type>) : Null<ComplexType> return {
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
          [ for (a in args) a.opt ? nullable(toComplexType(a.t)) : toComplexType(a.t) ],
          toComplexType(ret));
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
}
