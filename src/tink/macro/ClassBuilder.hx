package tink.macro;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.Printer;

using tink.MacroApi;
using Lambda;

class ClassBuilder {
	
	var memberMap:Map<String,Member>;
	var memberList:Array<Member>;
	var macros:Map<String,Field>;
	var constructor:Null<Constructor>;
	public var target(default, null):ClassType;//TODO: this could be lazy
	var superFields:Map<String,Bool>;
	
	public function new() { 
		this.memberMap = new Map();
		this.memberList = [];
		this.macros = new Map();
		this.target = Context.getLocalClass().get();
		
		switch (target.kind) {
			case KAbstractImpl(a):
				//TODO: remove this whole workaround
				var meta = target.meta;
				for (tag in a.get().meta.get())
					if (!meta.has(tag.name)) 
						meta.add(tag.name, tag.params, tag.pos);					
			default:
		}
		
		for (field in Context.getBuildFields()) 
			if (field.access.has(AMacro))
				macros.set(field.name, field)
			else if (field.name == 'new') {
				var m:Member = field;
				this.constructor = new Constructor(m.getFunction().sure(), m.isPublic, m.pos);
			}
			else
				addMember(field);
	}
	
	public function getConstructor(?fallback:Function):Constructor {
		if (constructor == null) 
			if (fallback != null)
				new Constructor(fallback);
			else if (target.superClass != null && target.superClass.t.get().constructor != null) {
				try {
					var ctor = Context.getLocalClass().get().superClass.t.get().constructor.get();
					var func = Context.getTypedExpr(ctor.expr()).getFunction().sure();
					
					//TODO: Check that the code below is no longer necessary
					// for (arg in func.args)
						// arg.type = null;
						
					func.expr = "super".resolve().call(func.getArgIdents());
					constructor = new Constructor(func);
					if (ctor.isPublic)
						constructor.publish();					
				}
				catch (e:Dynamic) {//fails for unknown reason
					if (e == 'assert')
						neko.Lib.rethrow(e);
					constructor = new Constructor(null);
				}
			}
			else
				constructor = new Constructor(null);
		return constructor;
	}
	
	public function hasConstructor():Bool 
		return this.constructor == null;
		
	public function export(?verbose):Array<Field> {
		var ret = (constructor == null || target.isInterface) ? [] : [constructor.toHaxe()];
		for (member in memberList) {
			if (member.isBound)
				switch (member.kind) {//TODO: this seems like an awful place for a cleanup. If all else fails, this should go into a separate plugin (?)
					case FVar(_, _): if (!member.isStatic) member.isBound = null;
					case FProp(_, _, _, _): member.isBound = null;
					default:
				}
			ret.push(member);
		}
		for (m in macros)
			ret.push(m);
		
		if (verbose) 
			for (field in ret) 
				Context.warning(new Printer().printField(field), field.pos);
		
		return ret;		
	}
	public function iterator():Iterator<Member>
		return this.memberList.copy().iterator();
		
	public function hasOwnMember(name:String):Bool
		return 
			macros.exists(name) || memberMap.exists(name);
	
	public function hasSuperField(name:String):Bool {
		if (superFields == null) {
			superFields = new Map();
			var cl = target.superClass;
			while (cl != null) {
				var c = cl.t.get();
				for (f in c.fields.get())
					superFields.set(f.name, true);
				cl = c.superClass;
			}
		}
		return superFields.get(name);
	}
	
	public function removeMember(member:Member):Bool 
		return 
			member != null 
			&&
			memberMap.get(member.name) == member 
			&& 
			memberMap.remove(member.name) 
			&& 
			memberList.remove(member);
	
	public function hasMember(name:String):Bool 
		return hasOwnMember(name) || hasSuperField(name);
	
	public function addMember(m:Member, ?front:Bool = false):Member {
		if (m.name == 'new') 
			throw 'Constructor must not be registered as ordinary member';
			
		if (hasOwnMember(m.name)) 
			m.pos.error('duplicate member declaration ' + m.name);
		if (!m.isStatic && hasSuperField(m.name))
			m.overrides = true;
		memberMap.set(m.name, m);
		if (front) 
			memberList.unshift(m);
		else 
			memberList.push(m);				
			
		return m;
	}
	
	static public function run(plugins:Array<ClassBuilder->Void>, ?verbose) {
		var builder = new ClassBuilder();
		for (p in plugins)
			p(builder);
		return builder.export(verbose);
	}
}