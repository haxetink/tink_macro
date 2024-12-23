package tink.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.PosInfos;
import haxe.macro.Printer;
import haxe.DynamicAccess as Dict;

using Lambda;
using StringTools;

using tink.macro.Positions;
using tink.macro.Exprs;
using tink.macro.Types;
using tink.CoreApi;

typedef VarDecl = { name : String, type : ComplexType, expr : Null<Expr> };
typedef ParamSubst = {
  var exists(default, null):String->Bool;
  var get(default, null):String->ComplexType;
  function iterator():Iterator<ComplexType>;
}

private class Heureka { public function new() {} }

class Exprs {

  static public function has(e:Expr, condition:Expr->Bool, ?options: { ?enterFunctions: Bool }) {
    var skipFunctions = options == null || options.enterFunctions != true;
    function seek(e:Expr)
      switch e {
        case { expr: EFunction(_) } if (skipFunctions):
        case _ if (condition(e)): throw new Heureka();
        default: haxe.macro.ExprTools.iter(e, seek);
      }

    return try {
      haxe.macro.ExprTools.iter(e, seek);
      false;
    }
    catch (e:Heureka) true;
  }

  static public inline function is(e:Expr, c:ComplexType)
    return e.as(c).typeof().isSuccess();

  static public inline function as(e:Expr, c:ComplexType)
    return ECheckType(e, c).at(e.pos);

  static public function eval(e:Expr):Dynamic {
    Context.typeof(macro tink.macro.Bouncer.eval(function () return $e));
    return Bouncer.lastEvaled;
  }

  static public function finalize(e:Expr, ?nuPos:Position, ?rules:Dict<String>, ?skipFields = false, ?callPos:PosInfos) {
    if (nuPos == null)
      nuPos = Context.currentPos();
    if (rules == null)
      rules = { };

    function replace(s:String):String
      return switch rules[s] {
        case null:
          if (s.startsWith('tmp')) {
            rules[s] = MacroApi.tempName(s.substr(3));
            replace(s);
          }
          else s;
        case v: v;
      }

    return e.transform(function (e:Expr) {
      return
        if (Context.getPosInfos(e.pos).file != callPos.fileName) e;
        else {
          e.pos = nuPos;
          switch (e.expr) {
            case EVars(vars):
              for (v in vars)
                v.name = replace(v.name);
              e;
            case EField(owner, field):
              if (skipFields) e;
              else owner.field(replace(field), e.pos);
            case EFunction(_, f):
              for (a in f.args)
                a.name = replace(a.name);
              e;
            case EObjectDecl(fields):
              if (!skipFields)
                for (f in fields)
                  f.field = replace(f.field);
              e;
            default:
              switch (e.getIdent()) {
                case Success(s): replace(s).resolve(e.pos);
                default: e;
              }
          }
        }
    });
  }

  static public function withPrivateAccess(e:Expr)
    return
      e.transform(function (e:Expr)
        return
          switch (e.expr) {
            case EField(owner, field):
              getPrivate(owner, field, e.pos);//TODO: this needs to leave types untouched
            default: e;
          }
      );

  static public function getPrivate(e:Expr, field:String, ?pos:Position)
    return macro @:pos(pos.sanitize()) @:privateAccess $e.$field;

  static public function substitute(source:Expr, vars:Dict<Expr>, ?pos)
    return
      transform(source, function (e:Expr) {
        return switch e {
          case macro $i{name}:
            switch vars[name] {
              case null: e;
              case v: v;
            }
          default: e;
        }
      }, pos);

  static public inline function ifNull(e:Expr, fallback:Expr)
    return
      switch e {
        case macro null: fallback;
        default: e;
      }

  static public function substParams(source:Expr, subst:ParamSubst, ?pos:Position):Expr {
    if (!subst.iterator().hasNext())
      return source;

    function replace(ct:ComplexType)
      return switch ct {
        case TPath({ pack: [], name: name }) if (subst.exists(name)):
          subst.get(name);
        default: ct;
      }

    return source
      .transform(
        function (e) return switch e {
          case macro $i{name} if (subst.exists(name)):
            switch subst.get(name) {
              case TPath({ pack: pack, name: name }):
                pack.concat([name]).drill(e.pos);
              default: e;//TODO: report an error?
            }
          default: e;
        })
      .mapTypes(replace);
  }

  static public function mapTypes(e:Expr, transformer:ComplexType->ComplexType, ?pos:Position) {
    return e.transform(
      function (e) return switch e {
        case { expr: ENew(p, args) }:
          switch TPath(p).map(transformer) {
            case TPath(nu):
              ENew(nu, args).at(e.pos);
            case v:
              pos.error(v.toString() + ' cannot be instantiated in ${e.pos}');
          }
        case macro cast($v, $ct):
          ct = ct.map(transformer);
          (macro @:pos(e.pos) cast($v, $ct));
        case { expr: ECheckType(v, ct) }: // cannot use reification, because that's `EParentheses(ECheckType)` and macros can (and apparently do) generate a non-wrapped one
          ECheckType(v, ct.map(transformer)).at(e.pos);
        case { expr: EVars(vars) }:
          EVars([for (v in vars) {
            name: v.name,
            type: v.type.map(transformer),
            expr: v.expr,
          }]).at(e.pos);
        case { expr: EFunction(kind, f) }:
          EFunction(kind, Functions.mapSignature(f, transformer)).at(e.pos);
        default: e;
      }
    );
  }

  static public function transform(source:Expr, transformer:Expr->Expr, ?pos):Expr {
    function apply(e:Expr)
      return switch e {
        case null | { expr: null }: e;
        default: transformer(haxe.macro.ExprTools.map(e, apply));
      }

    return apply(source);
  }

  static public function getIterType(target:Expr)
    return
      (macro @:pos(target.pos) {
        var t = null,
          target = $target;
        for (i in target)
          t = i;
        t;
      }).typeof();

  static public function yield(e:Expr, yielder:Expr->Expr, ?options: { ?leaveLoops: Bool }):Expr {
    inline function rec(e)
      return yield(e, yielder, options);

    if (options == null)
      options = { };

    var loops = options.leaveLoops != true;
    return
      if (e == null || e.expr == null) e;
      else switch (e.expr) {
        case EVars(_):
          e.pos.error('Variable declaration not supported here');
        case EBlock(exprs) if (exprs.length > 0):
          exprs = exprs.copy();
          exprs.push(rec(exprs.pop()));
          EBlock(exprs).at(e.pos);
        case EIf(econd, eif, eelse)
          ,ETernary(econd, eif, eelse):
          EIf(econd, rec(eif), rec(eelse)).at(e.pos);
        case ESwitch(e, cases, edef):
          ESwitch(e, [for (c in cases) {
            expr: rec(c.expr),
            guard: c.guard,
            values: c.values,
          }], rec(edef)).at(e.pos);
        case EFor(it, expr) if (loops):
          EFor(it, rec(expr)).at(e.pos);
        case EWhile(cond, body, normal) if (loops):
          EWhile(cond, rec(body), normal).at(e.pos);
        case EBreak, EContinue: e;
        case EBinop(OpArrow, value, jump) if (jump.expr == EContinue || jump.expr == EBreak):
          macro @:pos(e.pos) {
            ${rec(value)};
            $jump;
          }
        default: yielder(e);
      }
  }

  static public inline function iterate(target:Expr, body:Expr, ?loopVar:String = 'i', ?pos:Position)
    return macro @:pos(pos.sanitize()) for ($i{loopVar} in $target) $body;

  static public function toFields(object:Dict<Expr>, ?pos:Position)
    return EObjectDecl([for (field in object.keys())
      { field:field, expr: object[field] }
    ]).at(pos);

  static public inline function log(e:Expr, ?pos:PosInfos):Expr {
    haxe.Log.trace(e.toString(), pos);
    return e;
  }

  static public inline function reject(e:Expr, ?reason:String = 'cannot handle expression'):Dynamic
    return e.pos.error(reason);

  static public inline function toString(e:Expr):String
    return new haxe.macro.Printer().printExpr(e);

  static public inline function at(e:ExprDef, ?pos:Position)
    return {
      expr: e,
      pos: pos.sanitize()
    };

  static public inline function instantiate(s:String, ?args:Array<Expr>, ?params:Array<TypeParam>, ?pos:Position)
    return s.asTypePath(params).instantiate(args, pos);

  static public inline function assign(target:Expr, value:Expr, ?op:Binop, ?pos:Position)
    return binOp(target, value, op == null ? OpAssign : OpAssignOp(op), pos);

  static public inline function define(name:String, ?init:Expr, ?typ:ComplexType, ?pos:Position)
    return at(EVars([ { name:name, type: typ, expr: init } ]), pos);

  static public inline function add(e1:Expr, e2, ?pos)
    return binOp(e1, e2, OpAdd, pos);

  static public inline function unOp(e:Expr, op, ?postFix = false, ?pos)
    return EUnop(op, postFix, e).at(pos);

  static public inline function binOp(e1:Expr, e2, op, ?pos)
    return EBinop(op, e1, e2).at(pos);

  static public inline function field(e:Expr, field, ?pos)
    return EField(e, field).at(pos);

  static public inline function call(e:Expr, ?params, ?pos)
    return ECall(e, params == null ? [] : params).at(pos);

  static public inline function toExpr(v:Dynamic, ?pos:Position)
    return Context.makeExpr(v, pos.sanitize());

  static public inline function toArray(exprs:Iterable<Expr>, ?pos)
    return EArrayDecl(exprs.array()).at(pos);

  static public inline function toMBlock(exprs:Array<Expr>, ?pos)
    return EBlock(exprs).at(pos);

  static public inline function toBlock(exprs:Iterable<Expr>, ?pos)
    return toMBlock(Lambda.array(exprs), pos);

  static public function drill(parts:Array<String>, ?pos:Position, ?target:Expr) {
    if (target == null)
      target = at(EConst(CIdent(parts.shift())), pos);
    for (part in parts)
      target = field(target, part, pos);
    return target;
  }

  static public inline function resolve(s:String, ?pos)
    return drill(s.split('.'), pos);

  static var scopes = new Array<Array<Var>>();

  static function inScope<T>(a:Array<Var>, f:Void->T) {
    scopes.push(a);

    inline function leave()
      scopes.pop();
    try {
      var ret = f();
      leave();
      return ret;
    }
    catch (e:Dynamic) {
      leave();
      return Error.rethrow(e);
    }
  }

  static public function scoped<T>(f:Void->T)
    return inScope([], f);

  static public function inSubScope<T>(f:Void->T, a:Array<Var>)
    return inScope(switch scopes[scopes.length - 1] {
      case null: a;
      case v: v.concat(a);
    }, f);

  static public function typeof(expr:Expr, ?locals)
    return
      try {
        if (locals == null)
          locals = scopes[scopes.length - 1];
        if (locals != null)
          expr = [EVars(locals).at(expr.pos), expr].toMBlock(expr.pos);
        Success(Context.typeof(expr));
      }
      catch (e:haxe.macro.Expr.Error) {
        e.pos.makeFailure(e.message);
      }
      catch (e:Dynamic) {
        expr.pos.makeFailure(e);
      }

  static public inline function cond(cond:Expr, cons:Expr, ?alt:Expr, ?pos)
    return EIf(cond, cons, alt).at(pos);

  static public function isWildcard(e:Expr)
    return
      switch e {
        case macro _: true;
        default: false;
      }

  static public function getString(e:Expr)
    return
      switch (e.expr) {
        case EConst(c):
          switch (c) {
            case CString(string): Success(string);
            default: e.pos.makeFailure(NOT_A_STRING);
          }
        default: e.pos.makeFailure(NOT_A_STRING);
      }

  static public function getInt(e:Expr)
    return
      switch (e.expr) {
        case EConst(c):
          switch (c) {
            case CInt(id): Success(Std.parseInt(id));
            default: e.pos.makeFailure(NOT_AN_INT);
          }
        default: e.pos.makeFailure(NOT_AN_INT);
      }

  static public function getIdent(e:Expr)
    return
      switch (e.expr) {
        case EConst(c):
          switch (c) {
            case CIdent(id): Success(id);
            default: e.pos.makeFailure(NOT_AN_IDENT);
          }
        default:
          e.pos.makeFailure(NOT_AN_IDENT);
      }

  static public function getName(e:Expr)
    return
      switch (e.expr) {
        case EConst(c):
          switch (c) {
            case CString(s), CIdent(s): Success(s);
            default: e.pos.makeFailure(NOT_A_NAME);
          }
        default: e.pos.makeFailure(NOT_A_NAME);
      }

  static public function getFunction(e:Expr)
    return
      switch (e.expr) {
        case EFunction(_, f): Success(f);
        default: e.pos.makeFailure(NOT_A_FUNCTION);
      }

  static public function concat(e:Expr, with:Expr, ?pos) {
    if(pos == null) pos = e.pos;
    return
      switch [e.expr, with.expr] {
        case [EBlock(e1), EBlock(e2)]: EBlock(e1.concat(e2)).at(pos);
        case [EBlock(e1), e2]: EBlock(e1.concat([with])).at(pos);
        case [e1, EBlock(e2)]: EBlock([e].concat(e2)).at(pos);
        default: EBlock([e, with]).at(pos);
      }
  }

  static var FIRST = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static var LATER = FIRST + '0123456789';

  static public function shortIdent(i:Int) {
    var ret = FIRST.charAt(i % FIRST.length);

    i = Std.int(i / FIRST.length);

    while (i > 0) {
      ret += LATER.charAt(i % LATER.length);
      i = Std.int(i / LATER.length);
    }

    return ret;
  }

  static inline var NOT_AN_INT = "integer constant expected";
  static inline var NOT_AN_IDENT = "identifier expected";
  static inline var NOT_A_STRING = "string constant expected";
  static inline var NOT_A_NAME = "name expected";
  static inline var NOT_A_FUNCTION = "function expected";
}
