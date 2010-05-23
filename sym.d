module sym;

public import tok;
import std.conv;


/**
 * シンボル毎に対応するオブジェクトを生成するクラス、Poolも兼ねる
 */
class Symbol
{
private:
	static Symbol[string] internTbl;
	static anonymous_sym_count = 0;
	
	this(string s){ name = s; }

public:
	/**
	 * シンボル名に対応するオブジェクトを返す
	 * Params:
	 *   name : シンボル名、空文字の場合は呼び出し毎に異なる無名シンボルオブジェクトを返す
	 */
	static Symbol opCall(string name=null){
		if( !name.length ){
			//無名シンボル用の特殊処理
			anonymous_sym_count++;
			name = "__anon" ~ to!string(anonymous_sym_count);
		}else if( name.length>=6 && name[0..6]=="__anon" ){
			//無名シンボル用のPrefixで始まる名前は確保できない
			assert(0);
		}
		if( auto sym = name in internTbl ){
			return *sym;
		}else{
			return internTbl[name] = new Symbol(name);
		}
	}
	
	/**
	 * シンボル名
	 */
	const(string) name;
	
	/**
	 *
	 */
	string toString(){
		return "#"~name;
	}
}


/**
 * リテラル値毎に一意なオブジェクトを生成するクラス、Poolも兼ねる
 */
class Const(T)
{
private:
	static Const[T] pool;
	
	this(ref T v){ val = v; }

public:
	/**
	 * リテラル値に対応するオブジェクトを返す
	 */
	static Const opCall(ref T v){
		if( auto c = v in pool ){
			return *c;
		}else{
			return pool[v] = new Const(v);
		}
	}
	
	/**
	 * リテラル値
	 */
	const(T) val;
}


