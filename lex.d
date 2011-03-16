module lex;

private import xtk.device;
private import xtk.range;
private import std.typecons, std.typetuple;
private import std.ctype : isalpha, isalnum, isdigit, isxdigit, tolower;

private bool isbdigit(dchar c)	{ return c=='0' || c=='1'; }
private bool isodigit(dchar c)	{ return '0'<=c && c<='7'; }

private import std.conv : to;
private import xtk.format : format;
private import std.stdio : writefln;

//debug = Lex;
//debug = Num;

struct FilePos
{
	ulong line;
	ulong column;
	
	int opCmp(ref const(FilePos) rhs)
	{
		if (this.line == rhs.line)
		{
			if (this.column == rhs.column)
				return 0;
			else if (this.column < rhs.column)
				return -1;
			else
				return +1;
		}
		else if (this.line < rhs.line)
			return -1;
		else
			return +1;
	}
}

/// 
struct Token
{
public:
	enum Tag
	{
		NONE,
		NEWLINE,
		VAR, FUN,
		ADD,SUB,MUL,DIV,
		ASSIGN,
		INT, REAL, STR, IDENT,
		LPAR,	RPAR,
		LBRAC,	RBRAC,
		COMMA,
		EOF
	}
	alias Tag this;

private:
public:
	Tag     tag;
	FilePos pos;
	union
	{
		long	i;
		double	r;
		string	s;
	}

public:
	bool opEquals(ref const(Token) tok) const
	{
		return false;	//placeholder
	}
	bool opEquals(Tag tag) const
	{
		return this.tag == tag;
	}
	
	string toString() const
	{
		auto str = to!string(tag);
		switch (tag)
		{
		case Token.INT:		return format("%s:%s", str, i);
		case Token.REAL:	return format("%s:%s", str, r);
		case Token.STR:		return format("%s:%s", str, s);
		case Token.IDENT:	return format("%s:%s", str, s);
		default:			return str;
		}
	}
}

/// 
const Token.Tag[string] reservedSymbols;
static this()
{
	reservedSymbols = [
	//	"def":		Token.DEF,
		"var":		Token.VAR,
		"fun":		Token.FUN,
	//	"if":		Token.IF,
	//	"else":		Token.ELSE,
	//	"import":	Token.IMPORT,
		
		"":			Token.EOF		//dummy
	];
}

/// array operation
dchar nextFront(T)(ref T[] input)
{
	return input.popFront(), input.front;
}

/// array operation
/// Returns: true = skipped 1>= characteers.
bool skip_ws(T)(ref T[] input)
{
	bool result = false;
	while (!input.empty)
	{
		auto c = input.front;
		if (c!=' ' && c!='\t' && c!='\v' && c!='\f')
			break;		//改行はSkipしない -> TODO
		input.popFront();
		result = true;
	}
	return result;
}

/**
Toknizer constructs token range.
*/
struct Toknizer
{
private:
	alias typeof(
		(){ return zip(iota, lined!(const(char)[])(Sourced!File("", "r"))); }()
	) Input;
	Input input;
	const(char)[] line;
	ulong ln, col;
	Token token;
	bool eof;

public:
	this(string fname)
	{
		input = zip(iota, lined!(const(char)[])(Sourced!File(fname, "r")));
		ln = col = 0;
		eof = input.empty;
		if (!eof)
		{
			ln   = input.front[0];
			line = input.front[1];
			debug(Lex) writefln("lex = [%s, %s] %s", ln+1, col+1, line);
			popFront();
		}
		else
		{
			token.tag = Token.EOF;
			token.pos = FilePos(ln, col);
		}
	}
	
	/**
	*/
	@property bool empty() const
	{
		return eof;
	}
	
	/**
	*/
	@property ref const(Token) front() const
	{
		return token;
	}
	
	/**
	*/
	void popFront()
	{
		if (token.tag == Token.EOF)
		{
			eof = true;
			return;
		}
		
		auto linelen = line.length;
		line.skip_ws();
		col += linelen - line.length;
		linelen = line.length;
		
		if (line.empty)
		{
			if (input.empty)
			{
				token.tag = Token.EOF;
				token.pos = FilePos(ln, col);
			}
			else
			{
				token.tag = Token.NEWLINE;
				token.pos = FilePos(ln, col);
				
				input.popFront();
				ln   = input.front[0];
				line = input.front[1];
				col = 0;
			}
		}
		else
		{
			switch( line.front )
			{
			case '(':	line.popFront(), token.tag = Token.LPAR;	break;
			case ')':	line.popFront(), token.tag = Token.RPAR;	break;
			case '{':	line.popFront(), token.tag = Token.LBRAC;	break;
			case '}':	line.popFront(), token.tag = Token.RBRAC;	break;
			case ',':	line.popFront(), token.tag = Token.COMMA;	break;
			case '=':	line.popFront(), token.tag = Token.ASSIGN;	break;
			case '+':	line.popFront(), token.tag = Token.ADD;		break;
			case '-':	line.popFront(), token.tag = Token.SUB;		break;
			case '*':	line.popFront(), token.tag = Token.MUL;		break;
			case '/':	line.popFront(), token.tag = Token.DIV;		break;
			default:
				if (tryParseNum(this)
				 || tryParseStr(this)
				 || tryParseIdt(this))
					break;
				error("parse error");
			}
			
			token.pos = FilePos(ln, col);
			col += linelen - line.length;
		}
		
		debug(Lex) writefln("lex = %s [%s, %s] %s", token, ln+1, col+1, line);
		
		// ...
	}

private:
	void error(string msg)
	{
		/// 
		static class ToknizeException : Exception
		{
			this(FilePos pos, string msg)
			{
				super(format("ToknizError%s: %s", pos, msg));
			}
		}
		
		throw new ToknizeException(FilePos(ln, col), msg);
	}
}

version(unittest)
{
	struct MockToknizer
	{
		Token token;
		const(char)[] line;
		
		void error(string msg)
		{
			throw new Exception(msg);
		}
	}
}

bool tryParseNum(Context)(ref Context context)
in{ assert(!context.line.empty); }
body
{
	auto input = context.line;
	
	auto c = input.front;
	if( !isdigit(c) )
		return false;
	
	long i = 0;		//longがリテラルの制限
	
	if (c == '0')
	{
		input.popFront();
		if (input.empty)
			goto Zero;
		c = input.front;
		
		debug(Num) writefln("0? top=%02x %s", input.front, input.front);
		if (c == 'x' || c == 'X')								//16進数(0x??... | 0X??...)
		{
			if (!isxdigit(c = tolower(input.nextFront())))
				context.error("invalid hex literal.");
			do{
				i = (i * 16) + (isalpha(c) ? c-'a'+10 : c-'0');
				debug(Num) writefln("x=%X, %s", i, c);
			}while (isxdigit(c = tolower(input.nextFront())))
		}
		else if (c == 'b' || c == 'B')							//2進数(0b??... | 0B??...)
		{
			if (!isbdigit(c = input.nextFront()))
				context.error("invalid binary literal.");
			do{
				i = (i * 2) + (c - '0');
				debug(Num) writefln("b=%b", i);
			}while (isbdigit(c = input.nextFront()))
		}
		else if (c == 'o' || isodigit(c))						//8進数(0o??... | 0??...)
		{
			if (c == 'o' && !isodigit(c = input.nextFront()))
				context.error("invalid octet literal.");
			do{
				i = (i * 8) + (c - '0');
				debug(Num) writefln("o=%o", i);
			}while (isodigit(c = input.nextFront()))
		}
		else	//整数の0
		{
		  Zero:
			c = '0';
			input = context.line;	// revert
			debug(Num) writefln("0int, top='%s'(%02x)", input.front, input.front);
			goto scan_integer;
		}
	}
	else
	{
	  scan_integer:
		//整数部をlexing
		debug(Num) writefln("top='%s'(%02x)", input.front, input.front);
		while (!input.empty)
		{
			if (!isdigit(c = input.front)) break;
			i = (i * 10) + (c - '0');
			debug(Num) writefln("i=%d top='%s'(%02x)", i, input.front, input.front);
			input.popFront();
		}
		context.line = input;	//input.commit();
		
		input.skip_ws();
		if (!input.empty && input.front == '.')		//method呼び出し、または小数部
		{
			debug(Num) writefln(".");
			input.popFront();
			input.skip_ws();
			
			if (!input.empty && isdigit(c = input.front))
			{
				debug(Num) writefln("top=%s", input.front);
				double f = i, r = 0.1;
				do{
					f += r * (c - '0');
					r /= 10.0;
					debug(Num) writefln("f=%s", f);
					input.popFront();
				}while (!input.empty && isdigit(c = input.front))
				context.line = input;	//input.commit();
				
				context.token.tag = Token.REAL;
				context.token.r   = f;//RealT(f);
				return true;
			}
		}
	}
	context.line = input;	//input.commit();
	
	context.token.tag = Token.INT;
	context.token.i   = i;//IntT(i);
	return true;
}
unittest
{
	scope(success) std.stdio.writefln("unittest@%s:%s passed", __FILE__, __LINE__);
	scope(failure) std.stdio.writefln("unittest@%s:%s failed", __FILE__, __LINE__);
	
	bool test(const(char)[] line, double expect)
	{
		auto t = MockToknizer(Token(), line);
		try
		{
			if (tryParseNum(t))
				if (t.token.tag == Token.INT)
					return t.token.i == expect;
				else
					return t.token.r == expect;
			else
				return false;
		}
		catch (Throwable e)
			return false;
	}
	
	assert(test("0", 0));
	assert(test("1", 1));
	assert(test("1024", 1024));
	assert(test("0.0", 0.0));
	assert(test("1.0", 1.0));
	assert(test("3.1415", 3.1415));
}

bool tryParseStr(Context)(ref Context context)
in{ assert(!context.line.empty); }
body
{
	static dchar esc_char(dchar c) pure nothrow
	{
		switch (c)
		{
		case 'n':	return '\n';
		case 't':	return '\t';
		default:	return c;
		}
	}
	
	auto input = context.line;
	
	if (input.front != '\"')
		return false;
	input.popFront();
	
	auto buf = appender!string();
	bool esc = false;
	while (!input.empty)
	{
		auto c = input.front;
		input.popFront();
		if (c == '\"')
		{
			context.line = input;	//input.commit();
			
			context.token.tag = Token.STR;
			context.token.s   = buf.data;//StrT(buf.data);
			return true;
		}
		else if (c == '\\')
		{
			esc = true;
			continue;
		}
		
		if (esc)
			c = esc_char(c), esc = false;
		buf.put(c);
	}
	return false;
}
unittest
{
	scope(success) std.stdio.writefln("unittest@%s:%s passed", __FILE__, __LINE__);
	scope(failure) std.stdio.writefln("unittest@%s:%s failed", __FILE__, __LINE__);
	
	bool test(const(char)[] line, string expect=null)
	{
		auto t = MockToknizer(Token(), line);
		try
			return tryParseStr(t) && (t.token.s == expect);
		catch (Throwable e)
			return false;
	}
	
	assert( test(`""`,			""));
	assert( test(`"string"`,	"string"));
	assert( test(`"test\t\n"`,	"test\t\n"));
	assert(!test(`"test`));
	assert(!test(`123`));
	assert(!test(`ident`));
}

bool tryParseIdt(Context)(ref Context context)
in{ assert(!context.line.empty); }
body
{
	auto input = context.line;
	
	auto c = input.front;
	if (c != '_' && !isalpha(c))
		return false;
	
	auto buf = appender!string;
	do{
		//writefln("lexIdent, c=%s(%x), top=%s(%x)", c,c, input.top,input.top);
		buf.put(c);
		input.popFront();
	}while (!input.empty && (c = input.front, (isalnum(c) || c=='_')))
	//writefln("lexIdent, c=%s(%x), top=%s(%x)", c,c, input.top,input.top);
	context.line = input;	//input.commit();
	
	auto str = buf.data;
	if (auto tag = str in reservedSymbols)
	{
		context.token.tag = *tag;
	}
	else
	{
		context.token.tag = Token.IDENT;
		context.token.s   = str;//StrT(str);
	}
	return true;
}
unittest
{
	scope(success) std.stdio.writefln("unittest@%s:%s passed", __FILE__, __LINE__);
	scope(failure) std.stdio.writefln("unittest@%s:%s failed", __FILE__, __LINE__);
	
	bool test(const(char)[] line, string expect=null)
	{
		auto t = MockToknizer(Token(), line);
		try
			return tryParseIdt(t) && (t.token.s == expect);
		catch (Throwable e)
			return false;
	}
	
	assert( test("_name",	"_name"));
	assert( test("name",	"name"));
	assert( test("Name",	"Name"));
	assert( test("name012",	"name012"));
	assert(!test(`"name"`));
	assert(!test("0name"));
	assert(!test("~name"));
}
