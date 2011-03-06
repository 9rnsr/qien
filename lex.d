﻿module lex;

//import sym;
//import file.peek;
//import std.exception;


/+/// 
Toknizer toknize(string fname)
{
	return new Toknizer(fname);
	
}+/

private import xtk.device;
private import xtk.range;
private import std.typecons, std.typetuple;
private import std.ctype : isalpha, isalnum, isdigit, isxdigit, tolower;
private bool isbdigit(dchar c)	{ return c=='0' || c=='1'; }
private bool isodigit(dchar c)	{ return '0'<=c && c<='7'; }

private import std.conv : to;
private import xtk.workaround : format;
private import std.stdio : writefln;

//debug = Lex;
//debug = Num;

/+void main(string[] args)
{
	if (args.length != 2)
		return;
	
	auto fname = args[1];
	
	foreach (tok; Toknizer(fname))
	{
//		writefln("tok = %s", tok);
	}
	
}+/

struct FilePos
{
	ulong line;
	ulong column;
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
	//struct Tag{ int n; alias n this; }
	
	Tag     tag;
	FilePos pos;
	union{
		long	i;
		double	r;
		string	s;
//		IntT	i;
//		RealT	r;
//		StrT	s;
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
				if (tryParseNum() || tryParseStr() || tryParseIdent())
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
	
	bool tryParseNum()
	in{ assert(!line.empty); }
	body
	{
		alias line result;
		auto input = result;
		
		auto c = input.front;
		if( !isdigit(c) )
			return false;
		
		long i = 0;		//longがリテラルの制限
		
		if (c == '0')
		{
			c = input.nextFront();
			
			debug(Num) writefln("0? top=%02x %s", input.front, input.front);
			if (c == 'x' || c == 'X')								//16進数(0x??... | 0X??...)
			{
				if (!isxdigit(c = tolower(input.nextFront())))
					error("invalid hex literal.");
				do{
					i = (i * 16) + (isalpha(c) ? c-'a'+10 : c-'0');
					debug(Num) writefln("x=%X, %s", i, c);
				}while (isxdigit(c = tolower(input.nextFront())))
			}
			else if (c == 'b' || c == 'B')							//2進数(0b??... | 0B??...)
			{
				if (!isbdigit(c = input.nextFront()))
					error("invalid binary literal.");
				do{
					i = (i * 2) + (c - '0');
					debug(Num) writefln("b=%b", i);
				}while (isbdigit(c = input.nextFront()))
			}
			else if (c == 'o' || isodigit(c))						//8進数(0o??... | 0??...)
			{
				if (c == 'o' && !isodigit(c = input.nextFront()))
					error("invalid octet literal.");
				do{
					i = (i * 8) + (c - '0');
					debug(Num) writefln("o=%o", i);
				}while (isodigit(c = input.nextFront()))
			}
			else	//整数の0
			{
				c = '0';
				input = result;	// revert
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
			//	debug(Num) writefln("i=%d top='%s'(%02x), pos=%s", i, input.top, input.top, input.position);
				input.popFront();
			}
			result = input;	//input.commit();
			
			input.skip_ws();
			if (!input.empty && input.front == '.')		//method呼び出し、または小数部
			{
				debug(Num) writefln(".");
				input.popFront();
				input.skip_ws();
				
				debug(Num) writefln("top=%s", input.front);
				if (!input.empty && isdigit(c = input.front))
				{
					double f = i, r = 0.1;
					do{
						f += r * (c - '0');
						r /= 10.0;
						debug(Num) writefln("f=%s", f);
					}while (isdigit(c = input.nextFront()))
					result = input;	//input.commit();
					
					token.tag = Token.REAL;
					token.r   = f;//RealT(f);
					return true;
				}
			}
		}
		result = input;	//input.commit();
		
		token.tag = Token.INT;
		token.i   = i;//IntT(i);
		return true;
	}

	bool tryParseStr()
	in{ assert(!line.empty); }
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
		
		alias line result;
		auto input = line;
		
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
				result = input;	//input.commit();
				
				token.tag = Token.STR;
				token.s   = buf.data;//StrT(buf.data);
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
	
	bool tryParseIdent()
	in{ assert(!line.empty); }
	body
	{
		alias line result;
		auto input = line;
		
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
		result = input;	//input.commit();
		
		auto str = buf.data;
		if (auto tag = str in reservedSymbols)
		{
			token.tag = *tag;
		}
		else
		{
			token.tag = Token.IDENT;
			token.s   = str;//StrT(str);
		}
		return true;
	}
}
