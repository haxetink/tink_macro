package ;

#if !macro
	import haxe.unit.TestCase;
	import haxe.unit.TestRunner;
	import neko.Lib;
#else
	import tink.macro.Member;
	import tink.macro.Constructor;
	import tink.macro.ClassBuilder;
	using tink.macro.Tools;
#end

class Run {
	#if !macro 
		static var tests:Array<TestCase> = [];
		static function main() {
			test();//it compiles!!!
		}
	#end
	macro static function test() {
		return macro null;
	}
}