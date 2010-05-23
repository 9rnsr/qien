module sym;

public import tok;
import std.conv;


/// 
class Symbol
{
private:
	static Symbol[string] internTbl;
	static anonymous_sym_count = 0;
	
	this(string s){ name = s; }

public:
	static Symbol opCall(string name=""){
		if( name == "" ){	//無名シンボル用の特殊処理
			anonymous_sym_count++;
			name = "__anon" ~ to!string(anonymous_sym_count);
		}else{
			if( name.length>=6 && name[0..6]=="__anon" ){	//無名シンボル用のPrefixで始まる名前は確保できない
				assert(0);
			}
		}
		if( auto sym = name in internTbl ){
			return *sym;
		}else{
			return internTbl[name] = new Symbol(name);
		}
	}
	
	const(string) name;
	
	string toString(){
		return "#"~name;
	}
}


/// 
class Const(T)
{
private:
	static Const[T] pool;
	
	this(ref T v){ val = v; }

public:
	static Const opCall(ref T v){
		if( auto c = v in pool ){
			return *c;
		}else{
			return pool[v] = new Const(v);
		}
	}
	
	const(T) val;
}


