package tink.macro;

import haxe.macro.Expr;

class Metadatas {  
  static public function toMap(m:Metadata) {
    var ret = new Map<String,Array<Array<Expr>>>();
    if (m != null)
      for (meta in m) {
        if (!ret.exists(meta.name))
          ret.set(meta.name, []);
        ret.get(meta.name).push(meta.params);
      }
    return ret;
  }
  
  static public function getValues(m:Metadata, name:String)
    return 
      if (m == null) [];
      else [for (meta in m) if (meta.name == name) meta.params];  
}