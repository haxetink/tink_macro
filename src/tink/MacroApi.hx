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

//TODO: consider adding stuff from haxe.macro.Expr here
typedef MacroOutcome<D, F> = tink.core.Outcome<D, F>;
typedef MacroOutcomeTools = tink.core.Outcome.OutcomeTools;

typedef Option<T> = haxe.ds.Option<T>;

typedef Member = tink.macro.Member;
typedef Constructor = tink.macro.Constructor;
typedef ClassBuilder = tink.macro.ClassBuilder;

class MacroApi {
	
	static var idCounter = 0;	
	
	@:noUsing static public inline function tempName(?prefix:String = 'tmp'):String
		return '__tink_' + prefix + Std.string(idCounter++);
		
	static public function pos() 
		return haxe.macro.Context.currentPos();
	
	static public function onTypeNotFound(f:String->haxe.macro.Expr.TypeDefinition) 
		haxe.macro.Context.onTypeNotFound(function (name:String) {
			@:privateAccess Positions.errorFunc = @:privateAccess Positions.abortTypeBuild;
			
			var ret = 
				try f(name)
				catch (abort:tink.macro.Positions.AbortBuild) {
					var cl = macro class {
						static var __error = ${Positions.errorExpr(abort.pos, abort.message)};
					}
					var path = name.split('.');
					cl.name = path.pop();
					cl.pack = path;
					cl.pos = abort.pos;
					cl;
				}
				
			@:privateAccess Positions.errorFunc = @:privateAccess Positions.contextError;	
			
			return ret;
		});
	
}