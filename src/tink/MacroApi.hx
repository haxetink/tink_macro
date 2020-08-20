package tink;

import haxe.macro.Expr.TypeDefinition;

using tink.CoreApi;
using tink.macro.Positions;
using StringTools;

typedef Positions = tink.macro.Positions;
typedef ExprTools = haxe.macro.ExprTools;
typedef TypedExprTools = haxe.macro.TypedExprTools;
typedef TypedExprs = tink.macro.TypedExprs;
typedef Exprs = tink.macro.Exprs;
typedef Functions = tink.macro.Functions;
typedef Metadatas = tink.macro.Metadatas;
typedef Bouncer = tink.macro.Bouncer;
typedef Types = tink.macro.Types;
typedef Binops = tink.macro.Ops.Binary;
typedef Unops = tink.macro.Ops.Unary;
typedef TypeMap<T> = tink.macro.TypeMap<T>;

//TODO: consider adding stuff from haxe.macro.Expr here
typedef MacroOutcome<D, F> = tink.core.Outcome<D, F>;
typedef MacroOutcomeTools = tink.OutcomeTools;

typedef Member = tink.macro.Member;
typedef Constructor = tink.macro.Constructor;
typedef ClassBuilder = tink.macro.ClassBuilder;

typedef TypeResolution = Ref<Either<String, TypeDefinition>>;

class MacroApi {

  static var MAIN_CANDIDATES = ['-main', '-x', '--run'];
  static public function getMainClass():Option<String> {
    var args = Sys.args();

    for (c in MAIN_CANDIDATES)
      switch args.indexOf(c) {
        case -1:
        case v: return Some(args[v+1]);
      }

    return None;
  }

  @:persistent static var idCounter = 0;

  @:noUsing static public inline function tempName(?prefix:String = 'tmp'):String
    return '__tink_' + prefix + Std.string(idCounter++);

  static public function pos()
    return haxe.macro.Context.currentPos();

  static public var completionPoint(default, null):Option<{
    var file(default, never):String;
    var content(default, never):Null<String>;
    var pos(default, never):Int;
  }>;

  static public function getBuildFields():Option<Array<haxe.macro.Expr.Field>>
    return switch completionPoint {
      case Some(v) if (v.content != null && (v.content.charAt(v.pos - 1) == '@' || (v.content.charAt(v.pos - 1) == ':' && v.content.charAt(v.pos - 2) == '@'))): None;
      default: Some(haxe.macro.Context.getBuildFields());
    }

  static public var args(default, null):Iterable<String>;
  static var initialized = initArgs();

  static function initArgs() {
    var sysArgs = Sys.args();
    args = sysArgs;
    completionPoint = switch sysArgs.indexOf('--display') {
      case -1: None;
      case sysArgs[_ + 1] => arg:
        if (arg.startsWith('{"jsonrpc":')) {
          var payload:{
            jsonrpc:String,
            method:String,
            params:{
              file:String,
              offset:Int,
              contents:String,
            }
          } = haxe.Json.parse(arg);

          switch payload {
            case { jsonrpc: '2.0', method: 'display/completion' }:
              Some({
                file: payload.params.file,
                content: payload.params.contents,
                pos: payload.params.offset,
              });
            default: None;
          }
        }
        else None;
    }
    try haxe.macro.Context.onMacroContextReused(initArgs)
    catch (all:Dynamic) {}
    return true;
  }

}


#if (haxe_ver >= 4)
  typedef ObjectField = haxe.macro.Expr.ObjectField;
  typedef QuoteStatus = haxe.macro.Expr.QuoteStatus;
#else
  enum QuoteStatus {
    Unquoted;
    Quoted;
  }
  private typedef F = {
    var field:String;
    var expr:haxe.macro.Expr;
  }

  @:forward
  abstract ObjectField(F) to F {

    static var QUOTED = "@$__hx__";

    inline function new(o) this = o;

    public var field(get, never):String;

    function get_field()
      return
        if (quotes == Quoted)
          this.field.substr(QUOTED.length);
        else this.field;

    public var quotes(get, never):QuoteStatus;

    function get_quotes()
      return if (StringTools.startsWith(this.field, QUOTED)) Quoted else Unquoted;

    @:from static function ofFull(o:{>F, quotes:QuoteStatus }):ObjectField
      return switch o.quotes {
        case null | Unquoted:
          new ObjectField({ field: o.field, expr: o.expr });
        default:
          new ObjectField({ field: QUOTED + o.field, expr: o.expr });
      }

    @:from static function ofOld(o:F):ObjectField
      return new ObjectField(o);
  }
#end