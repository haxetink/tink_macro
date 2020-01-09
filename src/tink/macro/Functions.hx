package tink.macro;

import haxe.macro.Expr;

using tink.macro.Exprs;

#if haxe4
private abstract Kind(FunctionKind) from FunctionKind to FunctionKind {
  @:from static function ofString(s:String):Kind
    return FNamed(s);
}
#else
private typedef Kind = String;
#end

class Functions {
  static public inline function asExpr(f:Function, ?kind:Kind, ?pos)
    return EFunction(kind, f).at(pos);

  static public inline function toArg(name:String, ?t, ?opt = false, ?value = null):FunctionArg {
    return {
      name: name,
      opt: opt,
      type: t,
      value: value
    };
  }
  static public inline function func(e:Expr, ?args:Array<FunctionArg>, ?ret:ComplexType, ?params, ?makeReturn = true):Function {
    return {
      args: args == null ? [] : args,
      ret: ret,
      params: params == null ? [] : params,
      expr: if (makeReturn) EReturn(e).at(e.pos) else e
    }
  }

  static public function mapSignature(f:Function, transform):Function
    return {
      ret: Types.map(f.ret, transform),
      args: [for (a in f.args) {
        name: a.name,
        value: a.value,
        type: Types.map(a.type, transform),
        #if haxe4
        meta: a.meta,
        #end
      }],
      expr: f.expr,
      params: Types.mapTypeParamDecls(f.params, transform),
    }

  static public function getArgIdents(f:Function):Array<Expr> {
    var ret = [];
    for (arg in f.args)
      ret.push(arg.name.resolve());
    return ret;
  }
}
