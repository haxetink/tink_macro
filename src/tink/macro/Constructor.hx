package tink.macro;

import haxe.macro.Expr;

using tink.Macro;

class Constructor {
	var oldStatements:Array<Expr>;
	var nuStatements:Array<Expr>;
	var beforeArgs:Array<FunctionArg>;
	var args:Array<FunctionArg>;
	var afterArgs:Array<FunctionArg>;
	var pos:Position;
	var onGenerateHooks:Array<Function->Void>;
	var superCall:Expr;
	public var isPublic:Null<Bool>;
	
	public function new(f:Function, ?isPublic:Null<Bool> = null, ?pos:Position) {
		this.nuStatements = [];
		this.isPublic = isPublic;
		this.pos = pos.getPos();
		
		this.onGenerateHooks = [];
		this.args = [];
		this.beforeArgs = [];
		this.afterArgs = [];
		
		this.oldStatements = 
			if (f == null) [];
			else {
				for (i in 0...f.args.length) {
					var a = f.args[i];
					if (a.name == '_') {
						afterArgs = f.args.slice(i + 1);
						break;
					}
					beforeArgs.push(a);
				}
					
				if (f.expr == null) [];
				else
					switch (f.expr.expr) {
						case EBlock(exprs): exprs;
						default: oldStatements = [f.expr]; 
					}
			}
		superCall = 
			if (oldStatements.length == 0) [].toBlock();
			else switch oldStatements[0] {
				case macro super($a{_}): oldStatements.shift();
				default: [].toBlock();
			}
	}
	public function addStatement(e:Expr, ?prepend) 
		if (prepend)
			this.nuStatements.unshift(e)
		else
			this.nuStatements.push(e);
			
	public function init(name:String, pos:Position, ?e:Expr, ?def:Expr, ?prepend:Bool, ?t:ComplexType) {
		if (e == null) {
			e = name.resolve(pos);
			args.push( { name : name, opt : def != null, type : t, value : def } );
			if (isPublic == null) 
				isPublic = true;
		}
		if (t != null)
			e = ECheckType(e, t).at(e.pos);
		var s = EUntyped('this'.resolve(pos)).at(pos).field(name, pos).assign(e, pos);
			
		addStatement(s, prepend);
	}
	public inline function publish() 
		if (isPublic == null) 
			isPublic = true;
	
	function toBlock() 
		return [superCall].concat(nuStatements).concat(oldStatements).toBlock(pos);
	
	public function onGenerate(hook) 
		this.onGenerateHooks.push(hook);
		
	public function toHaxe():Field {
		var f:Function = {
			args: this.beforeArgs.concat(this.args).concat(this.afterArgs),
			ret: 'Void'.asComplexType(),
			expr: toBlock(),
			params: []
		};
		for (hook in onGenerateHooks) hook(f);
		return {
			name: 'new',
			doc : null,
			access : isPublic ? [APublic] : [],
			kind :  FFun(f),
			pos : pos,
			meta : []
		}
	}
}