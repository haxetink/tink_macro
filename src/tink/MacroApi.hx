package tink;

import haxe.macro.Expr.TypeDefinition;

using tink.CoreApi;
using tink.macro.Positions;

typedef Positions = tink.macro.Positions;
typedef ExprTools = haxe.macro.ExprTools;
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
  
  static var idCounter = 0;  
  
  @:noUsing static public inline function tempName(?prefix:String = 'tmp'):String
    return '__tink_' + prefix + Std.string(idCounter++);
    
  static public function pos() 
    return haxe.macro.Context.currentPos();

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