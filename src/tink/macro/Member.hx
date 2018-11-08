package tink.macro;

import haxe.macro.Expr;
using tink.MacroApi;

abstract Member(Field) from Field to Field {
  static public function prop(name:String, t:ComplexType, pos, ?noread = false, ?nowrite = false):Member {
    var ret:Field = {
      name: name,
      pos: pos,
      access: [APublic],
      kind: FProp(noread ? 'null' : 'get', nowrite ? 'null' : 'set', t),
    }
    return ret;
  }
    
  static public function getter(field:String, ?pos, e:Expr, ?t:ComplexType) 
    return method('get_' + field, pos, false, e.func(t));
  
  static public function setter(field:String, ?param = 'param', ?pos, e:Expr, ?t:ComplexType) 
    return method('set_' + field, pos, false, [e, param.resolve(pos)].toBlock(pos).func([param.toArg(t)], t));
  
  static public function method(name:String, ?pos, ?isPublic = true, f:Function) {
    var f:Field = {
      name: name,
      pos: if (pos == null) f.expr.pos else pos,
      kind: FFun(f)
    };
    var ret:Member = f;
    ret.isPublic = isPublic;
    return ret;
  }
  
  public var name(get, set):String;
  public var meta(get, set):Metadata;
  public var doc(get, set):Null<String>;
  public var kind(get, set):FieldType;
  public var pos(get, set):Position;
  public var overrides(get, set):Bool;
  public var isStatic(get, set):Bool;
  public var isPublic(get, set):Null<Bool>;
  public var isBound(get, set):Null<Bool>;
  
  public function getFunction()
    return
      switch kind {
        case FFun(f): Success(f);
        default: pos.makeFailure('Field should be function');
      }
      
  public function getVar(?pure = false) 
    return
      switch kind {
        case FVar(t, e): Success({ get: 'default', set: 'default', type: t, expr: e });
        case FProp(get, set, t, e) if (!pure): Success({ get: get, set: set, type: t, expr: e });
        default: pos.makeFailure('Field should be a variable ' + if (pure) '' else 'or property');
      }
  
  public function addMeta(name, ?pos, ?params):Member {
    if (this.meta == null)
      this.meta = [];
    this.meta.push({
      name: name,
      pos: if (pos == null) this.pos else pos,
      params: if (params == null) [] else params
    });
    return this;
  }
    
  public function extractMeta(name) {
    if (this.meta != null)
      for (tag in this.meta) {
        if (tag.name == name) {
          this.meta.remove(tag);
          return Success(tag);
        }
      }
    return pos.makeFailure('missing @$name');
  }

  public function metaNamed(name) 
    return 
      if (this.meta == null) [];
      else [for (tag in this.meta) if (tag.name == name) tag];
  
  public inline function asField():Field return this;
  public function publish() 
    if (this.access == null) this.access = [APublic];
    else {
      for (a in this.access)
        if (a == APrivate || a == APublic) return;
      this.access.push(APublic);
    }
  
  inline function get_meta() return switch this.meta {
    case null: this.meta = [];
    case v: v;
  }
  inline function set_meta(param) return this.meta = param;

  inline function get_name() return this.name;
  inline function set_name(param) return this.name = param;
  
  inline function get_doc() return this.doc;
  inline function set_doc(param) return this.doc = param;
  
  inline function get_kind() return this.kind;
  inline function set_kind(param) return this.kind = param;
  
  inline function get_pos() return this.pos;
  inline function set_pos(param) return this.pos = param;
  
  inline function get_overrides() return hasAccess(AOverride);
  inline function set_overrides(param) {
    changeAccess(
      param ? AOverride : null, 
      param ? null : AOverride
    );
    return param;
  }
  inline function get_isStatic() return hasAccess(AStatic);
  function set_isStatic(param) {
    changeAccess(
      param ? AStatic : null, 
      param ? null : AStatic
    );
    return param;
  }
  
  function get_isPublic() {
    if (this.access != null)    
      for (a in this.access) 
        switch a {
          case APublic: return true;
          case APrivate: return false;
          default:
        }
    return null;
  }
  
  function set_isPublic(param) {
    if (param == null) {
      changeAccess(null, APublic);
      changeAccess(null, APrivate);
    }
    else if (param) 
      changeAccess(APublic, APrivate);
    else 
      changeAccess(APrivate, APublic);
    return param;
  }
  
  function get_isBound() {
    if (this.access != null)
      for (a in this.access) 
        switch a {
          case AInline: return true;
          case ADynamic: return false;
          default:
        }
    return null;
  }
  function set_isBound(param) {
    if (param == null) {
      changeAccess(null, AInline);
      changeAccess(null, ADynamic);
    }
    else if (param) 
      changeAccess(AInline, ADynamic);
    else 
      changeAccess(ADynamic, AInline);
    return param;
  }
  //TODO: add some sanitazation stuff to normalize / report invalid access combinations
  
  function hasAccess(a:Access) {
    if (this.access != null)
      for (x in this.access)
        if (x == a) return true;
    return false;
  }
  
  function changeAccess(add:Access, remove:Access) {
    var i = 0;
    if (this.access == null)
      this.access = [];
    while (i < this.access.length) {
      var a = this.access[i];
      if (a == remove) {
        this.access.splice(i, 1);
        if (add == null) return;
        remove = null;
      }
      else {
        i++;
        if (a == add) {
          add = null;
          if (remove == null) return;
        }
      }
    }
    if (add != null)
      this.access.push(add);
  }
}
