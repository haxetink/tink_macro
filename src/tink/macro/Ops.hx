package tink.macro;

import haxe.macro.Expr;

using tink.MacroApi;

class Binary {
  static public function get(o:Binop, e:Expr) 
    return
      switch e.expr {
        case EBinop(op, e1, e2):
          if (Type.enumEq(o, op)) 
            Success({ e1: e1, e2:e2, pos:e.pos });
          else 
            e.pos.makeFailure('expected ' + o + ' but found ' + op);
        default: 
          e.pos.makeFailure('expected binary operation ' + o);
      }
  
  static public function getBinop(e:Expr) 
    return
      switch e.expr {
        case EBinop(op, e1, e2):
          Success({ e1: e1, e2:e2, op:op, pos:e.pos });
        default:
          e.pos.makeFailure('expected binary operation but found ' + Type.enumConstructor(e.expr));          
      }
  
  static public inline function make(op:Binop, e1:Expr, e2:Expr, ?pos) 
    return Exprs.binOp(e1, e2, op, pos);
}

class Unary {
  static public function get(o:Unop, e:Expr, postfix:Bool = false)
    return
      switch e.expr {
        case EUnop(op, postFix, arg):
          if (postFix != postfix)
            e.pos.makeFailure(postfix ? 'expected postfix operator' : 'expected prefix operator');
          else if (!Type.enumEq(o, op)) 
            e.pos.makeFailure('expected ' + o + ' but found ' + op);
          else
            Success({ e: arg, pos:e.pos });
        default: 
          e.pos.makeFailure('expected unary operation ' + o);
      }

  static public function getUnop(e:Expr)
    return
      switch e.expr {
        case EUnop(op, postFix, arg):
          Success({ op: op, postfix: postFix, e: arg, pos: e.pos });
        default:
          e.pos.makeFailure('expected unary operation but found ' + Type.enumConstructor(e.expr));          
      }

  static public function make(op:Unop, e:Expr, ?postFix = false, ?pos)
    return EUnop(op, postFix, e).at(pos);
}