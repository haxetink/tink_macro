package tink.macro;

import haxe.macro.Expr;
import haxe.macro.Context;
import tink.core.Pair;
using tink.MacroApi;

enum FieldInit {
  Value(e:Expr);
  Arg(?t:ComplexType, ?noPublish:Bool);
  OptArg(?e:Expr, ?t:ComplexType, ?noPublish:Bool);
}

class Constructor {
  var oldStatements:Array<Expr>;
  var nuStatements:Array<Expr>;
  var beforeArgs:Array<FunctionArg>;
  var args:Array<FunctionArg>;
  var afterArgs:Array<FunctionArg>;
  var pos:Position;
  var onGenerateHooks:Array<Function->Void>;
  var superCall:Expr;
  var owner:ClassBuilder;
  var meta:Metadata;
  public var isPublic:Null<Bool>;
  
  public function new(owner:ClassBuilder, f:Function, ?isPublic:Null<Bool> = null, ?pos:Position, ?meta:Metadata) {
    this.nuStatements = [];
    this.owner = owner;
    this.isPublic = isPublic;
    this.pos = pos.sanitize();
    
    this.onGenerateHooks = [];
    this.args = [];
    this.beforeArgs = [];
    this.afterArgs = [];
    this.meta = meta;
    
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
  
  public function addArg(name:String, ?t:ComplexType, ?e:Expr, ?opt = false) 
    args.push( { name : name, opt : opt || e != null, type : t, value: e } );
  
  public function init(name:String, pos:Position, with:FieldInit, ?options:{ ?prepend:Bool, ?bypass:Bool }) {
    if (options == null) 
      options = {};
    var e =
      switch with {
        case Arg(t, noPublish):
          if (noPublish != true) 
            publish();
          args.push( { name : name, opt : false, type : t } );
          name.resolve(pos);
        case OptArg(e, t, noPublish):
          if (noPublish != true) 
            publish();
          args.push( { name : name, opt : true, type : t, value: e } );
          name.resolve(pos);
        case Value(e): e;
      }
      
    var tmp = MacroApi.tempName();
    
    if (options.bypass) {
      switch owner.memberByName(name) {
        case Success(member): member.addMeta(':isVar');
        default:
      }
      addStatement(macro @:pos(pos) (cast this).$name = if (true) $e else this.$name, options.prepend);//TODO: this seems to report type errors here rather than at the declaration position
    }
    else 
      addStatement(macro @:pos(pos) this.$name = $e, options.prepend);
  }
  public inline function publish() 
    if (isPublic == null) 
      isPublic = true;
  
  function toBlock() 
    return [superCall]
      .concat(nuStatements)
      .concat(oldStatements)
      .toBlock(pos);
  
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
    onGenerateHooks = [];
    return {
      name: 'new',
      doc : null,
      access : isPublic ? [APublic] : [],
      kind :  FFun(f),
      pos : pos,
      meta : this.meta,
    }
  }
}