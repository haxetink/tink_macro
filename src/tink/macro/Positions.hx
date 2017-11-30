package tink.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import tink.core.Error;

using tink.macro.Positions;
using tink.core.Outcome;

class Positions {
  static public function getOutcome<D, F>(pos:Position, outcome:Outcome<D, F>):D
    return 
      switch outcome {
        case Success(d): d;
        case Failure(f): pos.error(f);
      }
  
  static public function makeBlankType(pos:Position):ComplexType 
    return Types.toComplex(Context.typeof(macro @:pos(pos.sanitize()) null));
    
  static public inline function sanitize(pos:Position)
    return 
      if (pos == null) 
        Context.currentPos();
      else
        pos;

  static public function errorExpr(pos:Position, error:Dynamic)
    return Bouncer.bounce(function ():Expr {
      return Positions.error(pos, error);
    }, pos);    


  static public function error(pos:Position, error:Dynamic):Dynamic 
    return 
      switch Std.instance(error, tink.core.Error) {
        case null: errorFunc(sanitize(pos), Std.string(error));
        case error: 
          errorFunc(
            error.pos, 
            error.message + 
              if (pos == null) ''
              else ' (referenced from ' + Std.string(pos).substr(5)
          );
      }
  
  static function contextError(pos:Position, error:String):Dynamic 
    return Context.fatalError(error, pos);
  
  static function abortTypeBuild(pos:Position, error:String):Dynamic 
    return throw new AbortBuild(error, pos);
    
  static var errorFunc = contextError;
  
  static public inline function warning<A>(pos:Position, warning:Dynamic, ?ret:A):A {
    Context.warning(Std.string(warning), pos);
    return ret;
  }

  static public function makeFailure<A>(pos:Position, reason:String):Outcome<A, Error> 
    return Failure(new Error(reason, pos));
}

class AbortBuild extends tink.core.Error {
}