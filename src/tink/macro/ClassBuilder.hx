package tink.macro;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.Printer;

using tink.MacroApi;
using Lambda;

class ClassBuilder {

  var memberList:Array<Member>;
  var macros:Map<String,Field>;
  var constructor:Null<Constructor>;
  public var target(default, null):ClassType;
  var superFields:Map<String,Bool>;

  var initializeFrom:Array<Field>;

  public function new(?target, ?fields) {
    if (target == null)
      target = Context.getLocalClass().get();

    if (fields == null)
      fields = Context.getBuildFields();

    this.initializeFrom = fields;
    this.target = target;
  }

  function init() {
    if (initializeFrom == null) return;

    var fields = initializeFrom;
    initializeFrom = null;

    this.memberList = [];
    this.macros = new Map();

    for (field in fields)
      if (field.access.has(AMacro))
        macros.set(field.name, field)
      else if (field.name == 'new') {
        var m:Member = field;
        this.constructor = new Constructor(this, m.getFunction().sure(), m.isPublic, m.pos, field.meta);
      }
      else
        doAddMember(field);


  }

  public function getConstructor(?fallback:Function):Constructor {
    init();
    if (constructor == null)
      if (fallback != null)
        constructor = new Constructor(this, fallback);
      else {
        var sup = target.superClass;
        while (sup != null) {
          var cl = sup.t.get();
          if (cl.constructor != null) {
            try {
              var ctor = cl.constructor.get();
              var ctorExpr = ctor.expr();
              if (ctorExpr == null) throw 'Super constructor has no expression';
              var func = Context.getTypedExpr(ctorExpr).getFunction().sure();

              for (arg in func.args) //this is to deal with type parameter substitutions
                arg.type = null;

              func.expr = "super".resolve().call(func.getArgIdents());
              constructor = new Constructor(this, func);
              if (ctor.isPublic)
                constructor.publish();
            }
            catch (e:Dynamic) {//fails for unknown reason
              if (e == 'assert')
                tink.core.Error.rethrow(e);
              constructor = new Constructor(this, null);
            }
            break;
          }
          else sup = cl.superClass;
        }
        if (constructor == null)
          constructor = new Constructor(this, null);
      }

    return constructor;
  }

  public function hasConstructor():Bool {
    init();
    return this.constructor != null;
  }

  public function export(?verbose):Array<Field> {
    if (initializeFrom != null) return null;
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
  public function iterator():Iterator<Member> {
    init();
    return this.memberList.copy().iterator();
  }

  public function hasOwnMember(name:String):Bool {
    init();
    return
      macros.exists(name) || memberByName(name).isSuccess();
  }

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

  public function memberByName(name:String, ?pos:Position) {
    init();
    for (m in memberList)
      if (m.name == name)
        return Success(m);

    return pos.makeFailure('unknown member $name');
  }

  public function removeMember(member:Member):Bool {
    init();
    return
      memberList.remove(member);
  }

  public function hasMember(name:String):Bool
    return hasOwnMember(name) || hasSuperField(name);

  function doAddMember(m:Member, ?front:Bool = false):Member {
    init();

    if (m.name == 'new')
      throw 'Constructor must not be registered as ordinary member';

    //if (hasOwnMember(m.name))
      //m.pos.error('duplicate member declaration ' + m.name);

    if (front)
      memberList.unshift(m);
    else
      memberList.push(m);

    return m;
  }

  public function addMembers(td:TypeDefinition):Array<Member> {
    for (f in td.fields)
      addMember(f);
    return td.fields;
  }

  public function addMember(m:Member, ?front:Bool = false):Member {
    doAddMember(m, front);

    if (!m.isStatic && hasSuperField(m.name))
      m.overrides = true;

    return m;
  }

  static public function run(plugins:Array<ClassBuilder->Void>, ?verbose) {
    var builder = new ClassBuilder();
    for (p in plugins)
      p(builder);
    return builder.export(verbose);
  }
}
