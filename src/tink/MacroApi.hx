package tink;

typedef Positions = tink.macro.Positions;
typedef ExprTools = haxe.macro.ExprTools;
typedef Exprs = tink.macro.Exprs;
typedef Functions = tink.macro.Functions;
typedef Metadatas = tink.macro.Metadatas;
typedef Bouncer = tink.macro.Bouncer;
typedef Types = tink.macro.Types;
typedef Binops = tink.macro.Ops.Binary;
typedef Unops = tink.macro.Ops.Unary;

typedef MacroOutcome<D, F> = tink.core.Outcome<D, F>;
typedef MacroOutcomeTools = tink.core.Outcome.OutcomeTools;
//TODO: consider adding stuff from haxe.macro.Expr here

class MacroApi {
	static var idCounter = 0;	
	static public inline function tempName(?prefix = '__tinkTmp'):String
		return prefix + Std.string(idCounter++);
	static public function pos() 
		return haxe.macro.Context.currentPos();
}
