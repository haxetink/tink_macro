# Tinkerbell Macro Library

[![Build Status](https://travis-ci.org/haxetink/tink_macro.svg?branch=master)](https://travis-ci.org/haxetink/tink_macro)
[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/haxetink/public)

Explained in current marketing speak, `tink_macro` is *the* macro toolkit ;)

### History and Mission

Historically, this library's predecessor for Haxe 2 started out when macros were a completely new feature. Boldly titled "the ultimate macro utility belt" it implemented reification and expression pattern matching before they were Haxe language features, and added a higher level macro tooling API (for string conversion, expression traversal and what not) to fill in the holes that the standard library left.

As Haxe evolved and some of the functionality has been integrated/reimplemented/superceeded in the standard library or even as first class language feature, the mission of `tink_macro` has shifted. Rather than being a standalone solution for macro programming, it is now a complement to all the things the Haxe language and the `haxe.macro` package can do out of the box.

### Overview

The library is build on top of the haxe macro API and `tink_core`, having three major parts:

<!-- START INDEX -->
- [Macro API](#macro-api)
	- [Expression Tools](#expression-tools)
		- [Basic Helpers](#basic-helpers)
		- [Extracting Constants](#extracting-constants)
		- [Shortcuts](#shortcuts)
		- [Type Inspection](#type-inspection)
		- [Advanced Transformations](#advanced-transformations)
	- [Position Tools](#position-tools)
	- [Type Tools](#type-tools)
	- [Function Tools](#function-tools)
	- [Operation Tools](#operation-tools)
	- [Metadata Tools](#metadata-tools)
- [Build Infrastructure](#build-infrastructure)
	- [Member](#member)
	- [ClassBuilder](#classbuilder)
	- [Constructor](#constructor)
		- [Creation](#creation)
		- [Visibility](#visibility)
		- [Initial Super Call](#initial-super-call)
		- [Simple Modifications](#simple-modifications)
		- [Field Initialization](#field-initialization)
			- [Setter Bypass](#setter-bypass)
			- [Initialization Options](#initialization-options)
		- [Expression Level Transformation](#expression-level-transformation)
- [TypeMap](#typemap)

<!-- END INDEX -->

# Macro API

It is suggested to use this API by `using tink.MacroApi;`

Apart form `tink_macro` specific things, it will also use `haxe.macro.ExprTools` and `tink.core.Outcome`.

## Expression Tools

### Basic Helpers

- `at(e:ExprDef, ?pos:Position):Expr`  
A short hand for creating expression as for example `EReturn(value).at(position)`, instead of the more verbose `{ expr: EReturn(value), pos: position }`.
If `pos` is omitted, it defaults to `Context.currentPos()`
- `ifNull(e:Expr, fallback:Expr):Expr`  
Because optional arguments to macros actually are not `null`, but in fact `EConst(CIdent('null'))`, you can use this to easily substitute those against a default value.
- `reject(e:Expr, ?reason:String):Dynamic`  
Rejects an expression and displays a generic or custom error message
- `toString(e:Expr):String`  
Converts an expression into the corresponding Haxe source code
- `log(e:Expr, ?pos:Position):Expr`  
Traces the string representation of an expression and returns it.
- `concat(e1:Expr, e2:Expr):Expr`
Concats two expressions into a block. If either sub-expression is a block itself, it gets flattened into the resulting block.

### Extracting Constants

- `isWildcard(e:Expr):Bool`  
Checks whether an expression is the identifier `_`
- `getInt(e:Expr):Outcome<Int, tink.core.Error>`  
Attempts extracting an integer constant from an expression
- `getString(e:Expr):Outcome<String, tink.core.Error>`  
Attempts extracting a string constant from an expression
- `getIdent(e:Expr):Outcome<String, tink.core.Error>`  
Attempts extracting an identifier from an expression. Note that an identifier can be a CIdent or CType, with the only difference being the capitalization of the first letter.
- `getName(e:Expr):Outcome<String, tink.core.Error>`  
Attempts extracting a name, i.e. a string constant or identifier from an expression

### Shortcuts

Often reification is prefereable to these shortcuts - if applicable. Unlike reification, the position of these expressions will default to `Context.currentPos()` rather than the position where they were created.

- `toExpr(v:Dynamic, ?pos:Position):Expr`  
Converts a constant to a corresponding haXe expression. For example `5` would become `{ expr: EConst(CInt('5'), pos: pos }`
- `field(e:Expr, field:String, ?pos:Position):Expr`  
Creates a field access to a given expression.
- `call(e:Expr, ?params:Array<Expr>, ?pos:Position):Expr`  
Creates a call to a given expression.
- `unOp(e:Expr, op:UnOp, ?postFix:Bool = false, ?pos:Position):Expr`  
Creates a unary operation on a given expression.
- `binOp(e1:Expr, e2:Expr, op:BinOp, ?pos:Position):Expr`  
Creates a binary operation on a given expression.
- `drill(parts:Array<String>, ?pos:Position):Expr`  
Creates an expression, that "drills" through an array of Strings as a chain of identifiers. For example `['foo', 'bar', 'baz'].drill()` will generate the code `foo.bar.baz`.
- `resolve(s:String, ?pos:Position):Expr`  
A shortcut to drill, only with a '.'-separated path. Especially helpful when calling global functions: `"haxe.Log.trace".resolve().call(["Hello world".toExpr()])`
- `add(e1:Expr, e2:Expr, ?pos:Position):Expr`  
A shorthand to return the sum of two expressions
- `assign(target:Expr, value:Expr, ?pos:Position):Expr`
Generates an assign statement.
- `toBlock(exprs:Iterable<Expr>, ?pos:Position):Expr`  
Takes multiple expressions and turns them into a block
- `toMBlock(exprs:Array<Block>, ?pos:Position):Expr`  
Takes multiple expressions and turns them into a *mutable* block, i.e. if you modify the `exprs` given to this function, the expression will be affected. Use this with care! Especially, do not return expressions to client code that you intend to modify further. This can lead to weird behavior and errors that are hard to track, even more so because all this happens at macro time.
- `toArray(exprs:Iterable<Expr>, ?pos:Position):Expr`  
Takes multiple expressions and turns them into an array declaration.
- `toFields(object:Dynamic<Expr>, ?pos:Position):Expr`  
Takes a key-value-map and turns it into an object declaration.
- `define(name:String, ?init:Expr, ?typ:ComplexType, ?pos:Position):Expr`  
Generates a variable declaration. Please note that the parent expression of a variable declaration must be a block.
- `cond(cond:ExprRequire<Bool>, cons:Expr, ?alt:Expr, ?pos:Position):Expr`  
Generates a simple if statement.
- `iterate(target:Expr, body:Expr, ?loopVar:String = 'i', ?pos:Position):Expr`  
Will loop over `target` with a loop variable called `loopVar` using `body`-

### Type Inspection

- `is(e:Expr, c:ComplexType):Bool`  
Tells you whether a given expression has a given type. 
If you have a `Type` at hand, use `toComplex` to convert it to a complex type.
- `getIterType(target:Expr):Outcome<Type, tink.core.Error>`  
Inspects, whether an expression can be iterated over and if so returns the element type.
- `typeof(expr:Expr, ?locals:Array<Var>):Outcome<Type, tink.core.Error>`  
Attempts to determine the type of an expression. Note that you can use `locals` to hint the compiler the type of certain identifiers. For example if you are in a build macro, and you want to get the type of a subexpression of a method body, you could "fake" the other members of the class as local variables, because in that context, the other members do not yet exists from the compiler's perspective.

### Advanced Transformations

- `has(e:Expr, condition:Expr->Bool, ?options: { ?enterFunctions: Bool })`
This function actually does no transformation, but is very close to the rest of these functions. It allows you to check whether an expression has a sub-expression that satisfies `condition`. By default, it does not enter nested functions. 
- `transform(source:Expr, transformer:Expr->Expr, ?pos:Position):Expr`  
Will traverse an expression inside out and build a new one through the supplied transformer.
- `substitute(source:Expr, vars:Dynamic<Expr>, ?pos:Position):Expr`  
Will build a new expression substituting identifiers given found as fields of `vars` through the corresponding expressions.
- `substParams(source:Expr, rule: ParamSubst, ?pos:Position):Expr`  
Traverse an expression and replace any *type* that looks like a type parameter following the given `rule` of the following structure:

	```haxe
	typedef ParamSubst = { 
		var exists(default, null):String->Bool; 
		var get(default, null):String->ComplexType; 
	}
	```
	
	A `StringMap` is a natural fit here, but you can do whatever you want.
	Note that if the type for a given name is a `TPath`, it will also be substituted for class names in `new` statements and for identifiers of that name.
- `typedMap(source:Expr, f:Expr->Array<Var>->Expr, ?ctx:Array<Var>, ?pos:Position):Expr`  
Similar to transform, but handles expressions in top-down order and keeps track of variable declarations, function arguments etc. Only expressions that are not changed by the transformer function `f` are traversed further. The second argument to `f` is the current context that you can use in `typeof` to determine the type of a subexpression.
- `bounce(f:Void->Expr, ?pos:Position):Expr`  
This is a way to "bounce" out of a macro for a while. Assume you have this expression: `{ var a = 5, b = 6; a + b; }` and you want to analyze the second statement, you either have to track variables manually or do a `typedMap` but that may be too much work. What you would do here is something like this (stupid example):  

	```haxe
	function onBounce() { trace(block[1].typeof().sure()); return block[1]; }
	[block[0], onBounce.bounce(block[1].pos)].toBlock();
	```

- `yield(source:Expr, yielder:Expr->Expr, ?options:{ ?leaveLoops:Bool }):Expr`  
This will traverse an expression and will apply the `yielder` to the "leafs", which in this context are the subexpressions that determine a return value. Example:

	```haxe
	yield(
		macro if (foo) bar else { var x = y; for (i in a) bla; }, 
		function (e) return macro trace($e)
	); 
	//becomes
	if (foo) trace(bar) else { var x = y; for (i in a) trace(bla); }
	```
	
	To implement array comprehensions yourself with this you would do:
	
	```haxe
	e.transform(function (e) return switch e {
		case macro [for ($it) $body]:
			macro {
				var __ret = [];
				for ($it) ${body.yield(function (e) return macro __ret.push(e))};
				__ret;
			}
		default: e;
	});
	```

	If you set `options.leaveLoops` to `true`, then loops (both for and while) will be considered leafs. 
	
## Position Tools

- `sanitize(pos:Position):Position`  
Returns the position ITself or `Context.currentPos()` if it's null.
- `makeBlankType(pos:Position):ComplexType`  
Builds a "blank type", i.e. `Unknown`. Useful when you want to defer work to type inference.
- `error(pos:Position, error:Dynamic):Dynamic`  
Raises an error at the given position.
- `errorExpr(pos:Position, error:Dynamic):Expr`  
Returns an expression, the later compilation of which will cause an error to be raised. This will let your macro continue normally unlike `error`, which causes execution to stop and can lead to more errors, because other "processable" code is never transformed to valid Haxe code and the user is burried in tons of error messages.
- `makeFailure<A, Reason>(pos:Position, reason:Reason):Outcome<A, tink.core.Error>`  
Creates a failed `Outcome` associated with the supplied position.
- `getOutcome<D, F>(pos:Position, outcome:Outcome<D, F>):D`  
Attempts getting the result of the supplied outcome. If it is a failure, it will cause an error at the given position.

## Type Tools

- `getID(t:Type, ?reduced = true):Null<String>`  
Returns a String identifier for a type if available. By default, the type will be reduced prior to getting its name (typedefs are resolved etc.). With `reduced = false` you can also get the name of a typedef.
- `getFields(t:Type, ?substituteParams = true):Outcome<Array<ClassField>, Outcome<String>>`  
Attempts to get all fields of a type. By default, this call will perform a parameter substitution, i.e. called on `Array<Int>`, `pop` will be of type `Void->Int`. With `substituteParams = false`, `pop` will be of type `Void->Array.T` instead. 
- `toString(t:ComplexType):String`  
Converts a `ComplextType` to corresponding Haxe code. No such thing exists for `Type` as it is actually is automatically converted to rather readable strings.
- `isSubTypeOf(t:Type, of:Type, ?pos:Position):Outcome < Type, tink.core.Error >`  
Checks whether one type is a subtype of another. Returns an `Outcome` to give back information on *why* `t` is not a subtype of `of`.
- `toType(t:ComplexType, ?pos:Position):Outcome<Type, tink.core.Error>`  
Attempts converting a `ComplextType` to a `Type`. This can fail for a number of reasons, such as no actual type being known for a supplied path.
- `asTypePath(s:String, ?params:Array<TypeParam>):TypePath`  
Will build a `TypePath` from a '.'-separated path.
- `asComplexType(s:String, ?params:Array<TypeParam>):ComplexType`  
A shortcut to `asTypePath` to build a `ComplexType` from a '.'-separated path.
- `reduce(type:Type, ?once:Bool):Type`  
Reduces a type by following `TType` and resolving `TLazy`.
- `isVar(field:ClassField):Bool`  
Will tell you whether a field is a variable or not. Signature is likely to change soon.
- `toComplex(type:Type, ?option:{ ?direct: Bool }):ComplexType`  
Will convert a `Type` to a `ComplexType`. Ideally this is done with `Context.toComplexType` but for monomorphs and the like, this builtin method fails and `tink_macro` uses a hack to make it work none the less. You can also use `{ direct : true }` to force this hack in case the translation fails (which can be the case with private types).

## Function Tools

- `asExpr(f:Function, ?name:String, ?pos:Position):Expr`  
Converts a function to an expression, i.e. a local function definition.
- `func(body:Expr, ?args, ?ret:ComplexType, ?params:Array<TypeParamDecl>, ?makeReturn = true):Function`  
Builds a `Function` from an expression. By default, the body is returned.
- `toArg(name:String, ?t:ComplexType, ?opt = false, ?value:Expr = null):FunctionArg`  
A shorthand to create function arguments.
- `getArgIdents(f:Function):Array<Expr>`  
Will extract the argument list of a function as an expression list of identifiers (usefull when writing call-forwarding macros or the like).

## Operation Tools

- `get(o:Binop, e:Expr):Outcome<{ e1:Expr, e2:Expr, pos:Position }, tink.core.Error>`  
Attempts to extract a specific binary operation from an expression.
- `getBinop(e:Expr):Outcome<{ e1:Expr, e2:Expr, pos:Position, op:Binop }, tink.core.Error>`  
Attempts to decompose an expression into the parts of a binary operation.
- `make(op:Binop, e1:Expr, e2:Expr, ?pos:Position):Expr`  
Builds a binary operation. Just syntactic sugar for the `Expr::binOp` listed above. It's often easier to read.

- `get(o:Unop, e:Expr, postfix:Bool = false):Outcome<{ e:Expr, pos:Position }, tink.core.Error>`  
Attempts to extract a specific unary operation from an expression.
- `getUnop(e:Expr):Outcome<{ op:Unop, e:Expr, postFix:Bool, pos:Position }, tink.core.Error>`  
Attempts to decompose an expression into the parts of a unary operation.

## Metadata Tools

- `toMap(m:Metadata):Map<String, Array<Array<Expr>>`
Will deconstruct an array of metadata tags to a `Map` mapping the tag names to an array of the argument lists of each tag with that name. So `@foo(1) @foo(2) @bar` becomes `["foo" => [[1], [2]], "bar" => [[]]]`
- `getValues(m:Metadata, name:String):Array<Array<Expr>>`  
Will construct an array of the of the arguments lists of all occurences of the tag `name` in a given `Metadata`. The result is the same as `m.toMap()[name]` only it's far more efficient.

# Build Infrastructure

Writing build macros can sometimes be a little tedious. But `tink_macro` is here to help!

## Member

Let's have a look at the most important type involved in build macros:

```haxe
typedef Field = {
	var name : String;
	@:optional var doc : Null<String>;
	@:optional var access : Array<Access>;
	var kind : FieldType;
	var pos : Position;
	@:optional var meta : Metadata;
}
```

No doubt, it gets the job done. There's a few things that could be nicer though. For one, if you want to add something to access and meta, you have to look whether it's not `null`. Secondly, you can use it to construct non-sensical things like `[AInline, ADynamic]` or `[APublic, APrivate]`, the former leading to a compiler error and the latter simply being interpreted as `private`, no matter how many occurrences of `APublic` you have. And as it is unspecified behavior, it may even change.

For this reason and more, we have `tink.macro.Member` which looks like this:

```haxe
abstract Member from Field to Field {
	var name(get, set):String;
	var doc(get, set):Null<String>;
	var kind(get, set):FieldType;
	var pos(get, set):Position;
	var overrides(get, set):Bool;
	var isStatic(get, set):Bool;
	var isPublic(get, set):Null<Bool>;
	var isBound(get, set):Null<Bool>;
	
	function getFunction():Outcome<Function, Error>;			
	function getVar(?pure = false):Outcome<{ get: String, set: String, type: ComplexType, expr:Expr }, tink.core.Error>;	
	function addMeta(name:String, ?pos:Position, ?params:Array<Expr>):Void;	
	function extractMeta(name:String):Outcome<MetadataEntry, tink.core.Error>;
	
	function publish():Bool;
	function asField():Field;
}
```

Most of the API should be self-explaining. The `isBound` property is a bad name to convey the concept that a field can be either `inline` (`true`) or `dynamic` (`false`) or neither (`null`). Equally, `isPublic` is nullable which means that normally defaults to `private`.

The `publish` method will make a field `public` if it is not explicitly marked as `private`. This can also be done with `if (m.isPublic == null) m.isPublic = true;` but the implementation is far more efficient - for what its worth.

The `extractMeta` method will "peel of" the first tag with a given `name` - if available. Note that the tag will be removed from the member.

The `getVar` method will get information about the field if it is a variable or yield failure otherwise. If `pure` is set to true, it will fail for properties also.

At any time you can also use `asField` to interact with the data the good old way. Converting between `Member` and `Field` is without overhead.

## ClassBuilder

To make handling multiple fields easier, we have the `ClassBuilder` with the following API:

```haxe
class ClassBuilder {	
	var target(default, null):ClassType;
	function new():Void;
	
	function getConstructor(?fallback:Function):Constructor;
	function hasConstructor():Bool;
	
	function export(?verbose = false):Array<Field>;
	function iterator():Iterator<Member>;	
	
	function hasSuperField(name:String):Bool;
	function hasOwnMember(name:String):Bool;
	function hasMember(name:String):Bool; 
	function removeMember(member:Member):Bool;
	function addMember(m:Member, ?front:Bool = false):Member;
	
	static public function run(plugins:Array<ClassBuilder->Void>, ?verbose = false)
}
```

The first thing to point out is that constructors are handled separately. This is covered in the documentation of `Constructor`.

As for the rest of the members, you can just iterate over them. It's worth noting that the iterator runs over a snapshot made at the time of its creation, so removing and adding fields during iteration has no effect on the iteration itself.

You can add a member. If you try adding a member named `"new"`, you'll get an exception - so don't. Find out about how tink_macro handles constructors below. If you add a member that already exists in the super class, the `override` is added automatically.

And when you're done, you can `export` everything to an array of fields. If you set `verbose` to true, you will get compiler warnings for every generated field at the position of the field. This is way you can see the generated code even if the application cannot compile for some reason.

The intended use is with `run` that will send the same `ClassBuilder` through a number of functions, exporting once at the end. This reduces the overhead introduced by the `ClassBuilder`.

## Constructor

Constructors are relatively tricky, especially when you have inheritance. If you do not specify a constructor, than that of the the super class is used. If you do specify one, then it needn't be compatible with the super class, but it needs to call it. Macros represent them as an instance field called `new` that must be a function. However if you think about it, a constructor belongs to a class, not an instance. So this is all a little dodgy. The constructor API is an attempt to create a more rigid solution.

The `Constructor` API is the result of countless struggles with constructors. Still it may not be for you. In that case feedback is appreciated and currently the suggested method is to deal with the constructor after you've exported all fields from the `ClassBuilder`.

Constructors are represented by this API:

```haxe
class Constructor {
	var isPublic:Null<Bool>;
	function publish():Void; 
	function addStatement(e:Expr, ?prepend = false):Void;
	function addArg(name:String, ?t:ComplexType, ?e:Expr, ?opt = false)
	function init(name:String, pos:Position, with:FieldInit, ?options:{ ?prepend:Bool, ?bypass:Bool }):Void;
	function onGenerate(hook:Function->Void):Void;
}
```

### Creation

You get a `Constructor` by calling `getConstructor` on a `ClassBuilder`. If the class that you're operating on has a constructor, the `Constructor` will be created from that. If not, it will be created on demand. The `hasConstructor` method indicates whether a constructor has already been created.

When a `Constructor` is created automatically and without `fallback` a call to the super constructor is auto-generated (assuming the class has a super class that has a constructor) forwarding all arguments. 

### Visibility

The constructor starts out without `private` or `public`. Use `isPublic` and `publish` to control visibility analogously to `Member`.

### Initial Super Call

If the first statement in a constructor is a `super` call (which is true for automatically generated ones), then modification of the constructor through this API will maintain that property. Generally, that's also the suggested way to go. If you *need* to execute things *before* that's a symptom of a [fragile base class](http://en.wikipedia.org/wiki/Fragile_base_class). Still, if *absolutely* want to do it, the slightest modification can be used to not match the `super` call detection. If the first statement is `@later super(...)` or `(super(...))` or whatever that is not an immediate call to super, then it will not be detected as a super call and will not be treated specially.

### Simple Modifications

Adding any statements to the constructor is unsurprisingly achieved by `addStatement`. Setting `prepend` to true, you can add the statement at the very beginning of the constructor, but after the `super` call if one was detected. Again, relying on order can be indicative of a fragile design.

To add a constructor argument, you can just use `addArg`.

### Field Initialization

The `init` method is the swiss army knife of initializing fields. The `options.prepend` flag works the same as `prepend` for `addStatement`. As for `options.bypass`, the behavior is somewhat magical.

#### Setter Bypass

It is important to know that when you initialize a field with `options.bypass` set to true, existing setters will be bypassed. That's particularly helpful if your setter triggers a side effect that you don't want triggered. This is achieved by generating the assignment as `(untyped this).$name = $value`. To make the code typesafe again, this is prefixed with `if (false) { var __tmp = this.$name; __tmp = $value; }`. This code is later thrown out by the compiler. Its role is to ensure type safety without interfering with the normal typing order.

Setter bypass also causes the field to gain an `@:isVar`. And currently, with `-dce full`, additional code will be generated to avoid the field to be eliminated.

Please do note, that `value` will be in the generated code twice, therefore if it is an expression that calls a macro, the macro will be called twice.

#### Initialization Options

The different options for initialization are as follows:

```haxe
enum FieldInit {
	Value(e:Expr);
	Arg(?t:ComplexType, ?noPublish:Bool);
	OptArg(?e:Expr, ?t:ComplexType, ?noPublish:Bool);
}
```

Here, `Value` will just use a plain expression, whereas `Arg` and `OptArg` will use a mandatory or optional argument respectively. Buth have a `noPublish` field. If left to default, their use will cause an implicit `publish()`

### Expression Level Transformation

Because the state of a constructor is rather delicate, the API prohibits you to just mess around with the whole constructor body at an expression level. For that to happen, you can register `onGenerate` hooks. These will be called when the corresponding `ClassBuilder` does its export. The hooks are cleared after the export.

#  TypeMap

You can find a type map, i.e. a map where the keys are `haxe.macro.Type`, in `tink.macro.TypeMap`. It's pretty much an ordinary map. Currently, it relies rather strongly on [`haxe.macro.TypeTools.toString()`](http://api.haxe.org/haxe/macro/TypeTools.html#toString) and it remains to be determined whether that is a reliable choice. Please report any issues you might face.
