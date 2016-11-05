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