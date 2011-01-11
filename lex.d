module lex;

import sym;
import file.peek;
import std.exception;
import std.ctype : isalpha, isalnum, isdigit, isxdigit, toL=tolower;
import debugs;


public import file.peek : FilePos;

/// 
Toknizer toknize(string fname)
{
	return new Toknizer(fname);
	
}

/// 
enum TokTag
{
	EOF, NEWLINE,
	VAR, FUN,
	ADD,SUB,MUL,DIV,
	ASSIGN,
	INT, REAL, STR, IDENT,
	LPAR,	RPAR,
	LBRAC,	RBRAC,
	COMMA
}

/// 
struct Token
{
	FilePos	pos;
	TokTag	tag;
	union{
		IntT	i;
		RealT	r;
		StrT	s;
	}
	
	bool opEquals(ref const(Token) tok) const
	{
		return false;	//placeholder
	}
	bool opEquals(TokTag tag) const
	{
		return this.tag == tag;
	}
	
	string toString()
	{
		return (cast(const)this).toString();
	}
	string toString() const
	{
		auto str = to!string(tag);
		switch (tag)
		{
		case TokTag.INT:	return format("%s(%s)", str, i);
		case TokTag.REAL:	return format("%s(%s)", str, r);
		case TokTag.STR:	return format("%s(%s)", str, s);
		case TokTag.IDENT:	return format("%s(%s)", str, s);
		default:			return str;
		}
	}
}

/// 
static const TokTag[string] reservedSymbols;
static this()
{
	reservedSymbols = [
	//	"def":		TokTag.DEF,
		"var":		TokTag.VAR,
		"fun":		TokTag.FUN,
	//	"if":		TokTag.IF,
	//	"else":		TokTag.ELSE,
	//	"import":	TokTag.IMPORT,
		
		"":			TokTag.EOF		//dummy
	];
}

/// 
class Toknizer
{
public:
	/// 
	this(string fname)
	{
		//input = new PeekStream(new FilePosStream(s));
		//input = new PeekStream("", s);
		input = PeekSource(fname);
	}

	/// 
	Token take()
	{
		Token t;
		
		input_skip_whitespace();
		
		if (input.eof)
			t.tag = TokTag.EOF;
		else
		{
			t.pos = input.fpos;
			switch( input.top )
			{
			case '(':	eat;	t.tag = TokTag.LPAR;		break;
			case ')':	eat;	t.tag = TokTag.RPAR;		break;
			case '{':	eat;	t.tag = TokTag.LBRAC;		break;
			case '}':	eat;	t.tag = TokTag.RBRAC;		break;
			case ',':	eat;	t.tag = TokTag.COMMA;		break;
			case '=':	eat;	t.tag = TokTag.ASSIGN;		break;
			case '+':	eat;	t.tag = TokTag.ADD;			break;
			case '-':	eat;	t.tag = TokTag.SUB;			break;
			case '*':	eat;	t.tag = TokTag.MUL;			break;
			case '/':	eat;	t.tag = TokTag.DIV;			break;
			case '\n':	eat;	t.tag = TokTag.NEWLINE;		break;
			default:
				if (toknizeNum(t) || toknizeStr(t) || toknizeIdent(t))
					break;
				debugout("top == 0x%02X", input.top);
				error("parse error");
			}
		}
		
		return t;
	}
	

private:
//	PeekStream input;
	PeekSource input;
	//	LineNumStream		pos
	//	| PeekStream		eof, top, forward(), commit(), revert(), revertable
	//	| source
	
	void eat()
	{
		input.forward();
		input.commit();
	}
	
	void error(string msg)
	{
		/// 
		static class ToknizeException : Exception
		{
			this(FilePos fpos, string msg)
			{
				super("ToknizError" ~ fpos.toString ~ ": " ~ msg);
			}
		}
		
		throw new ToknizeException(input.fpos, msg);
	}
	
	char input_next()
	{
		return input.forward(), input.top;
	}
	bool input_skip_whitespace()
	{
		bool result = false;
		while (!input.eof)
		{
			auto c = input.top;
			if (c!=' ' && c!='\t' && c!='\v' && c!='\f')
				break;		//改行はSkipしない
			input.forward();
			result = true;
		}
		return result;
	}
	
	bool toknizeNum(ref Token token)
	in{ assert(!input.eof); }
	out(r){ if( r ) assert(input.revertable == false); }
	body{
		auto c = input.top;
		if( !isdigit(c) )
			return false;
		
		long i = 0;		//longがリテラルの制限
		
		if (c == '0')
		{
			c = input_next();
			
			debug(Number) p("0? top=%02x %s", input.top, input.top);
			if (c == 'x' || c == 'X')								//16進数(0x??... | 0X??...)
			{
				if (!isxdigit(c = tolower(input_next())))
					error("invalid hex literal.");
				do{
					i = (i * 16) + (isalpha(c) ? c-'a'+10 : c-'0');
					debug(Number) p("x=%X, %s", i, c);
				}while (isxdigit(c = tolower(input_next())))
			}
			else if (c == 'b' || c == 'B')							//2進数(0b??... | 0B??...)
			{
				if (!isbdigit(c = input_next()))
					error("invalid binary literal.");
				do{
					i = (i * 2) + (c - '0');
					debug(Number) p("b=%b", i);
				}while (isbdigit(c = input_next()))
			}
			else if (c == 'o' || isodigit(c))						//8進数(0o??... | 0??...)
			{
				if (c == 'o' && !isodigit(c = input_next()))
					error("invalid octet literal.");
				do{
					i = (i * 8) + (c - '0');
					debug(Number) p("o=%o", i);
				}while (isodigit(c = input_next()))
			}
			else	//整数の0
			{
				c = '0';
				input.revert();
				debug(Number) p("0int, top='%s'(%02x)", input.top, input.top);
				goto scan_integer;
			}
		}
		else
		{
		  scan_integer:
			//整数部をlexing
			debug(Number) p("top='%s'(%02x)", input.top, input.top);
			do{
				i = (i * 10) + (c - '0');
			//	debug(Number) p("i=%d top='%s'(%02x), pos=%s", i, input.top, input.top, input.position);
			}while (isdigit(c = input_next()))
			input.commit();
			
			//p("input.revertable=%s, eof=%s, top=(0x%02x)", input.revertable, input.eof, input.top);
			input_skip_whitespace();
			//p("input.revertable=%s, eof=%s, top=(0x%02x)", input.revertable, input.eof, input.top);
			if (input.top == '.')		//method呼び出し、または小数部
			{
				debug(Number) p(".");
				input.forward();
				input_skip_whitespace();
				
				debug(Number) p("top=%s", input.top);
				if (isdigit(c = input.top))
				{
					double f = i, r = 0.1;
					do{
						f += r * (c - '0');
						r /= 10.0;
						debug(Number) p("f=%s", f);
					}while (isdigit(c = input_next()))
					input.commit();
					
					token.tag = TokTag.REAL;
					token.r   = RealT(f);
					//debug(Lexer) p("lexer: Real(%s)", f);
					return true;
				}
				else
				{
					input.revert();
//					assert(input.top == '.');
				}
			}
			else
			{
				//p("input.revertable=%s, eof=%s, top=(0x%02x)", input.revertable, input.eof, input.top);
				input.revert();		//空白を戻す
				//p("input.revertable=%s, eof=%s, top=(0x%02x)", input.revertable, input.eof, input.top);
			}
		}
		input.commit();
		
		token.tag = TokTag.INT;
		token.i   = IntT(i);
		//debug(Lexer) p("lexer: Int(%d)", i);
		return true;
	}
	
	bool toknizeStr(ref Token token)
	in{ assert(!input.eof); }
	out(r){ if( r ) assert(input.revertable == false); }
	body{
		auto c = input.top;
		if (c != '\"')
			return false;
		input.forward();
		
		auto   vbuf = new char[8];	//サイズ可変
		size_t len = 0;
		bool esc = false;
		while ((c = input.top) != '\"')
		{
			if (input.eof) goto lex_error;
			
			input.forward();
			if (c == '\\')				//エスケープフラグON
				{ esc = true; continue; }
			if (len >= vbuf.length)		// バッファの拡張
				vbuf.length = vbuf.length * 2;
			if (esc)
				c = esc_char(c), esc = false;
			vbuf[len++] = c;
		}
		input.forward();	//最後の"を読み飛ばす
		input.commit();
		
		token.tag = TokTag.STR;
		token.s   = StrT(vbuf[0 .. len].assumeUnique);
		//debug(Lexer) p("lexer: String(\"%s\")", val.str);
		return true;
	
	lex_error:
		input.revert();
		return false;
	}
	
	bool toknizeIdent(ref Token token)
	in{ assert(!input.eof); }
	out(r){ if( r ) assert(input.revertable == false); }
	body{
		auto c = input.top;
		if (c != '_' && !isalpha(c))
			return false;
		
		char[] vbuf = new char[8];	//サイズ可変
		size_t len = 0;
		do{
			//p("lexIdent, c=%s(%x), top=%s(%x)", c,c, input.top,input.top);
			vbuf[len++] = c;
			if (len >= vbuf.length)
				vbuf.length = vbuf.length * 2;	// バッファの拡張
			input.forward();
		}while (!input.eof && (c = input.top, (isalnum(c) || c=='_')))
		//p("lexIdent, c=%s(%x), top=%s(%x)", c,c, input.top,input.top);
		input.commit();
		
		auto str = vbuf[0..len].assumeUnique;
		if (auto tag = str in reservedSymbols)
		{
			token.tag = *tag;
			//debug(Lexer) p("lexer: Reserved(%s)", str);
		}
		else
		{
			token.tag = TokTag.IDENT;
			token.s   = StrT(str);
			//writefln("lexer: IDENT(%s)", str);
		}
		return true;
	}
}

private int isbdigit(char c)	{ return c=='0' || c=='1'; }
private int isodigit(char c)	{ return '0'<=c && c<='7'; }

private char esc_char(char ch) pure
{
	switch (ch)
	{
	case 'n':	return '\n';
	case 't':	return '\t';
	default:	return ch;
	}
}
private T tolower(T)(T c)		{ return cast(T)toL(c); }
