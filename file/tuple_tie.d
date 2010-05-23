module file.tuple_tie;

public import std.typecons : Tuple;
public import std.typecons : tuple;

import std.typecons;
import std.typetuple;
import std.traits;
version(unittest){
	import std.stdio : wr=writefln;
}else{
	void wr(T...)(T args){}
}

private:
	template toPointers(T...)
	{
		static if( T.length > 0 ){
			alias TypeTuple!(T[0]*, toPointers!(T[1..$])) toPointers;
		}else{
			alias T[$..$] toPointers;
		}
	}
	
	struct Tie_Placeholder{}
	static Tie_Placeholder wildcard;
	alias wildcard _;
	
	template isTie(T)
	{
		template match(T : Tie!(U), U...){
			enum match = true;
		}
		template match(T)			{ enum match = false; }
		enum result = match!T;
		
	/+	static if( is(T U == Tie!U) ){
			enum result = true;
		}else{
			enum result = false;
		}+/
	}
	static assert(isTie!(Tie!(int)).result == true);
	static assert(isTie!(double)   .result == false);
	
	template isTuple(T)
	{
		template match(T : Tuple!(U), U...)	{ enum match = true; }
		template match(T)					{ enum match = false; }
		enum result = match!T;
	}
	
	
	template isPartialTemplate(alias T, U)
	{
		template match(V : T!(W), W...)	{ enum result = true; alias W params; }
		template match(V)				{ enum result = false; alias TypeTuple!() params; }
		enum result = match!U.result;
		alias match!U.params params;	//bug 空タプルになってしまう
	}
	version(unittest){
		static assert(isPartialTemplate!(Tie, Tie!(int)).result == true);
		static assert(isPartialTemplate!(Tie, double   ).result == false);
		static assert(isPartialTemplate!(Tie, Tie!(int,double)).result == true);
		
		static assert(isPartialTemplate!(Tuple, Tuple!(int)).result == true);
		static assert(isPartialTemplate!(Tuple, Tie!(int)  ).result == false);
		//static assert(0, "end test");
	}


public:
struct Tie(T...)
{
private:
	template satisfy(size_t i, U...)
	{
		static assert(T.length == i + U.length);
		static if( U.length == 0 ){
			enum satisfy = true;
		}else{
			//pragma(msg, "TieMatch.satisfy: i="~i.stringof~", T[i]="~T[i].stringof~", U[i]="~U[0].stringof);
			static if( is(T[i] == typeof(wildcard)) ){
				//wildcard
				//pragma(msg, "* Wildcard "~T[i].stringof);
				enum satisfy = true && satisfy!(i+1, U[1..$]);
			}else static if( isPartialTemplate!(.Tie, T[i]).result && isPartialTemplate!(Tuple, U[0]).result ){
		//	}else static if( is(T[i] V : Tie!V) && is(U[0] W : Tuple!W) ){	//is式だと現状タプルを取れない&DMDが落ちる
		//		pragma(msg, "* Pattern "~T[i].stringof);
		//		pragma(msg, "* Pattern.Params "~(isPartialTemplate!(Tuple, U[0]).params).stringof);
		//		enum satisfy = T[i].isMatchingTuple!W && satisfy!(i+1, U[1..$]);
				//pattern
				//isPartialTemplateでparamsが取れないため、NestしたTieのマッチ可能判定はopEquals内部でのCode生成時に行う
				enum satisfy = true && satisfy!(i+1, U[1..$]);
			}else static if( is(T[i] == U[0]) ){
				//value
				//pragma(msg, "* Value "~T[i].stringof);
				enum satisfy = true && satisfy!(i+1, U[1..$]);
			}else static if( is(T[i] == U[0]*) ){
				// capture
				//pragma(msg, "* Capture "~T[i].stringof);
				enum satisfy = true && satisfy!(i+1, U[1..$]);
			}else{
				//pragma(msg, "* Error "~T[i].stringof);
				enum satisfy = false;
			}
		}
	}
	template isMatchingTuple(U...)
	{
		enum isMatchingTuple = satisfy!(0, U);
		//pragma(msg, "isMatchingTuple: T="~T.stringof~", U="~U.stringof~", result="~isMatchingTuple.stringof);
	}

	T refs;

public:
	//void opAssign(string file=__FILE__, int line=__LINE__, U...)(Tuple!U rhs) if( isMatchingTuple!U )
	bool opAssign(U...)(Tuple!U rhs)
	{
		//pragma(msg, file~"("~line.stringof~"): " ~ "Tie.opAssign lvalue ver, U...="~U.stringof);
		
		static if( isMatchingTuple!U ){
			auto result = true;
			foreach( i,t; refs ){
				//pragma(msg, "Tie.opAssign, T[", cast(int)i, "]=", T[i].stringof);
				wr("Tie.opAssign, T[%s]=%s", i, T[i].stringof);
				static if( is(T[i] == typeof(wildcard)) ){			//wildcard
					wr("  wildcard");
					result = result && true;
				}else static if( isPointer!(T[i]) ){				// capture
					wr("  capture");
					wr("  refs[%s]=%s, rhs.field[%s]=%s", i, refs[i], i, rhs.field[i]);
					//pragma(msg, "* capture");
					*refs[i] = rhs.field[i];
					result = result && true;
			//	}else static if( is(T[i] U == Tie!U) ){				//pattern
				}else static if( isPartialTemplate!(.Tie, T[i]).result ){	//pattern
					wr("  pattern");
					//pragma(msg, "* pattern");
					result = result && t.opAssign(rhs.field[i]);
				}else{												//value
					wr("  value");
					//pragma(msg, "* value");
					result = result && (refs[i] == rhs.field[i]);
				}
			}
			return result;
		}else{
			return false;
		}
	}
	void opAssign(U...)(Tie!U rhs) if( is(T == U) ){
		this.tupleof = rhs.tupleof;	//コピー
	}
/+	//void opAssign(string file=__FILE__, int line=__LINE__, U:const(Tuple!V), V...)(ref U rhs) if( isMatchingTuple!V )
	void opAssign(U:const(Tuple!V), V...)(ref U rhs) if( isMatchingTuple!V )
	{
		//pragma(msg, file~"("~line.stringof~"): " ~ "Tie.opAssign rvalue ver, V...="~V.stringof);
		foreach( i,t; refs ){
			static if( !is(typeof(t) == typeof(wildcard)*) ) *refs[i] = rhs.field[i];
		}
	}+/
}

Tie!T tie(T...)(T tup)
{
	//pragma(msg, "tie[...]: T="~T.stringof);
	Tie!T ret;
	foreach( i,t; tup ){
		wr("tie, T[%s]=%s", i, T[i].stringof);
		static if( is(typeof(t) == typeof(wildcard)) ){
			wr("  wildcard");
		}else static if( isPointer!(T[i]) ){			// capture
			wr("  capture");
			ret.refs[i] = tup[i];
			wr("  ret.refs[%s]=%s, tup[%s]=%s", i, ret.refs[i], i, tup[i]);
		}else{											//pattern
			//pragma(msg, "Pattern: "~T[i].stringof);
			wr("  pattern");
			ret.refs[i] = tup[i];
		}
	}
	return ret;
}

unittest{	//キャプチャ
	int n = 10;
	double d = 3.14;
	if( tie(&n, &d) = tuple(20, 1.4142) ){
		assert(n == 20);
		assert(d == 1.4142);
	}else{
		assert(0);
	}
	wr("-> test ok");
}
unittest{	//ワイルドカード
	{	int n = 10;
		double d = 3.14;
		if( tie(&n, _) = tuple(20, 1.4142) ){
			assert(n == 20);
			assert(d == 3.14);
		}else{
			assert(0);
		}
	}
	{	int n = 10;
		double d = 3.14;
		if( tie(_, &d) = tuple(20, 1.4142) ){
			assert(n == 10);
			assert(d == 1.4142);
		}else{
			assert(0);
		}
	}
	wr("-> test ok");
}
unittest{	//値一致(基本型、tuple)
	{	int n = 10;
		if( tie(&n, 1.4142) = tuple(20, 1.4142) ){
			assert(n == 20);
		}else{
			assert(0);
		}
	}
	{	int n = 10;
		double d = 1.4142;
		if( tie(&n, tuple(d, "str")) = tuple(20, tuple(1.4142, "str")) ){
			assert(n == 20);
		}else{
			assert(0);
		}
	}
	wr("-> test ok");
}
unittest{	//ネストしたtie
	{	int n = 10;
		double d = 3.14;
		string s;
		if( tie(&n, tie(&d, &s)) = tuple(20, tuple(1.4142, "str")) ){
			assert(n == 20);
			assert(d == 1.4142);
			assert(s == "str");
		}else{
			assert(0);
		}
	}
	wr("-> test ok");
}
unittest{	//マッチ失敗
	{	int n = 10;
		double d = 3.14;
		if( tie(&n, d) = tuple(20, tuple(1.4142, "str")) ){
			assert(0);
		}else{
		}
	}
	wr("-> test ok");
}
