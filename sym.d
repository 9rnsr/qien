module sym;

public import tok;
import std.conv, std.string;


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
	 * シンボル名
	 */
	const(string) name;
	
	/**
	 *
	 */
	string toString(){ return "#"~name; }
}

/**
 * シンボル名に対応するオブジェクトを返す
 * Params:
 *   name : シンボル名、空文字の場合は呼び出し毎に異なる無名シンボルオブジェクトを返す
 */
Symbol newSymbol(string name=null)
{
	if (!name.length)
	{
		//無名シンボル用の特殊処理
		Symbol.anonymous_sym_count++;
		name = "__anon" ~ to!string(Symbol.anonymous_sym_count);
	}
	else if (name.length>=6 && name[0..6]=="__anon")
	{
		//無名シンボル用のPrefixで始まる名前は確保できない
		assert(0);
	}
	
	if (auto sym = name in Symbol.internTbl)
		return *sym;
	else
		return Symbol.internTbl[name] = new Symbol(name);
}

/**
 * リテラル値毎に一意なオブジェクトを生成するクラス、Poolも兼ねる
 */
class Constant(T)
{
private:
	static Constant[T] pool;
	
	this(ref T v){ val = v; }

public:
	/**
	 * リテラル値に対応するオブジェクトを返す
	 */
	static Constant opCall(T v)
	{
		if (auto c = v in pool)
			return *c;
		else
			return pool[v] = new Constant(v);
	}
	
	/**
	 * リテラル値
	 */
	const(T) val;
	
	alias val this;
}

alias Constant!long		IntT;
alias Constant!double	RealT;
alias Constant!string	StrT;

/**
 *
 */
class Temp
{
private:
	static uniq_temp_count = 0;
	
	int num;
	string name;
	this(string s=null)
	{
		num = uniq_temp_count++;
		name = s;
	}

public:
	string toString()
	{
		if (name)
			return format("$%s:%s", num, name);
		else
			return format("$%s", num);
	}
}

Temp newTemp(string name=null)
{
	return new Temp(name);
}

//class Label:Symbol{}
alias Symbol Label;	//無名シンボル==ラベル

Label newLabel()
{
	return newSymbol();
}

Label namedLabel(string name)
{
	return newSymbol(name);
}
