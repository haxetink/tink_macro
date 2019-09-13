package ;

import haxe.unit.*;

class Run {
  #if !macro 
  static function main() 
    test();//It compiles ...
  #else
  static var cases:Array<TestCase> = [
    new Exprs(),
    new Types(),
    new Positions(),
    new TypeMapTest(),
    new Functions(),
    new Misc(),
  ];
  #end
  macro static function test() {
    var runner = new TestRunner();
    tink.macro.ClassBuilder;
    for (c in cases)
      runner.add(c);
    runner.run();
    if (!runner.result.success)
      haxe.macro.Context.error(runner.result.toString(), haxe.macro.Context.currentPos());
    
    return macro {
      trace('Let\'s ship it!');
    }
  }
}