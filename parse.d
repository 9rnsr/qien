module parse;

public import lex, sym;
import std.range;
import debugs;
private import xtk.format : format;

//debug = parse;

/// 
AstNode parseProg(string fname/*Toknizer toknizer*/)
{
	scope ctxt = new ParseContext(fname/*toknizer*/);
	
	auto ast = ctxt.parseProg();
	
	debug(parse)
	{
		debugout("========");
		debugout("parse = %s", ast.toString);
	}

	return ast;
}


/// 
enum AstTag
{
	NOP,
	INT, REAL, STR, IDENT, FUN,
	ADD, SUB, MUL, DIV, CALL,
	ASSIGN, DEF
}


/// 
class AstNode
{
	FilePos	pos;
	AstTag	tag;
	
	union{
		IntT			i;			//INT
		RealT			r;			//REAL
		StrT			s;			//STR
		Symbol			sym;		//IDENT
		struct{AstNode	prm, blk;}	//FUN
		struct{AstNode	lhs, rhs;}	//ADD,SUB,MUL,DIV,CALL,ASSIGN,DEF
	}
	AstNode		next;
	
	this(){
		tag = AstTag.NOP;
	}
	this(FilePos p, AstTag t){
		pos = p;
		tag = t;
	}
	
	static AstNode Int(ref Token t){
		auto n = new AstNode(t.pos, AstTag.INT);
		n.i = IntT(t.i);
		return n;
	}
	static AstNode Real(ref Token t){
		auto n = new AstNode(t.pos, AstTag.REAL);
		n.r = RealT(t.r);
		return n;
	}
	static AstNode Str(ref Token t){
		auto n = new AstNode(t.pos, AstTag.STR);
		n.s = StrT(t.s);
		return n;
	}
	static AstNode Ident(ref Token t){
		auto n = new AstNode(t.pos, AstTag.IDENT);
		n.sym = newSymbol(t.s);
		return n;
	}
	static AstNode Fun(ref Token t, AstNode prm, AstNode blk){
		auto n = new AstNode(t.pos, AstTag.FUN);
		n.prm = prm ? prm : new AstNode();
		n.blk = blk ? blk : new AstNode();
		return n;
	}
	
	static AstNode AddSub(ref Token t, AstNode lhs, AstNode rhs)
	in{ assert(t == Token.ADD || t == Token.SUB); }
	body{
		auto n = new AstNode(t.pos, t == Token.ADD ? AstTag.ADD : AstTag.SUB);
		n.lhs = lhs, n.rhs = rhs;
		return n;
	}
	static AstNode MulDiv(ref Token t, AstNode lhs, AstNode rhs)
	in{ assert(t == Token.MUL || t == Token.DIV); }
	body{
		auto n = new AstNode(t.pos, t == Token.MUL ? AstTag.MUL : AstTag.DIV);
		n.lhs = lhs, n.rhs = rhs;
		return n;
	}
	static AstNode Call(ref Token t, AstNode lhs, AstNode rhs){
		auto n = new AstNode(t.pos, AstTag.CALL);
		n.lhs = lhs;
		n.rhs = rhs ? rhs : new AstNode();
		return n;
	}
	
	static AstNode Assign(ref Token t, AstNode lhs, AstNode rhs){
		auto n = new AstNode(t.pos, AstTag.ASSIGN);
		n.lhs = lhs, n.rhs = rhs;
		return n;
	}
	static AstNode Def(ref Token t, AstNode lhs, AstNode rhs){
		auto n = new AstNode(t.pos, AstTag.DEF);
		n.lhs = lhs, n.rhs = rhs;
		return n;
	}
	
	string toShortString()
	{
		string res;
		final switch( tag ){
			case AstTag.NOP:	res = "#";									break;
			case AstTag.INT:	res = format("(int %s)",     i.val);		break;
			case AstTag.REAL:	res = format("(real %s)",    r.val);		break;
			case AstTag.STR:	res = format("(str %s)",     s.val);		break;
			case AstTag.IDENT:	res = format("(id %s)",      sym.name);		break;
			case AstTag.FUN:	res = format("(fun %s %s)",  prm, blk);		break;
			case AstTag.ADD:	res = format("(+ %s %s)",    lhs, rhs);		break;
			case AstTag.SUB:	res = format("(- %s %s)",    lhs, rhs);		break;
			case AstTag.MUL:	res = format("(* %s %s)",    lhs, rhs);		break;
			case AstTag.DIV:	res = format("(/ %s %s)",    lhs, rhs);		break;
			case AstTag.CALL:	res = format("(call %s %s)", lhs, rhs);		break;
			case AstTag.ASSIGN:	res = format("(= %s %s)",    lhs, rhs);		break;
			case AstTag.DEF:	res = format("(def %s %s)",  lhs, rhs);		break;
		}
		return res;
	}
	string toString(){
//		return (cast(const)this).toString();
		auto res = toShortString();
		if( next ){
			res ~= " " ~ next.toString();
		}
		return res;
	}
/+	string toString() const{
	}+/
	
	/// AstNode#nextを辿って列挙する
	AstNode[] opSlice()
	{
		static struct NodeList
		{
			AstNode node;
			@property AstNode front()	{ return node; }
			@property bool empty() const{ return !node || node.tag == AstTag.NOP; }
			void popFront()				{ node = node.next; }
		}
		return array(NodeList(this));
	}
}


/// 
class ParseContext
{
	this(string fname/*Toknizer tok*/){
		//input = tok;
		input = Toknizer(fname);
		/*t = */input_next();
		Trace.context = this;
	}
		
	AstNode parseProg(){
		/*t = */input_skip_ws();
		auto n = parseStmt();
		auto tail = n;
		while( tail ){
			tail.next = parseStmt();
			if( !tail.next ) break;
			tail = (tail.next);
		}
		if( t != Token.EOF ) error(t.pos, "Program should be terminated by EOF");
		
		return n;
	}
	
private:
	Toknizer input;
	Token t;
	
	void input_next(){
		assert(!input.empty);
		t = input.front;
		input.popFront();
	}
	void input_skip_ws(){
		while( t == Token.NEWLINE ){ /*t = */input_next(); }
	}
	void input_next_ws(){
		//while( (/*t = */input_next()) == Token.NEWLINE ){}
		do{ input_next(); }while( t == Token.NEWLINE )
	}
	void error(ref FilePos pos, string msg){
		/// 
		static class ParseException : Exception
		{
			this(ref FilePos fpos, string msg)
			{
				super(format("ParseError%s: %s", fpos, msg)); }
		}
		throw new ParseException(pos, msg);
	}

	AstNode parseInt(){
		if( t == Token.INT ){
			auto n = AstNode.Int(t);
			/*t = */input_next();
			return n;
		}else{
			return null;
		}
	}
	AstNode parseReal(){
		if( t == Token.REAL ){
			auto n = AstNode.Real(t);
			/*t = */input_next();
			return n;
		}else{
			return null;
		}
	}
	AstNode parseStr(){
		if( t == Token.STR ){
			auto n = AstNode.Str(t);
			/*t = */input_next();
			return n;
		}else{
			return null;
		}
	}
	AstNode parseIdent(){
		if( t == Token.IDENT ){
			auto n = AstNode.Ident(t);
			/*t = */input_next();
			return n;
		}else{
			return null;
		}
	}
	AstNode parseFun(){
		auto trace = Trace("parseFun");
		if( t==Token.LPAR || t==Token.LBRAC ){
			// funリテラル本体のparse	... 以下の//で括られたところが対象
			//	fun f = /(){}/		定義
			//	fun f = /{ ... }/	定義
			//	fun/(x){ x*x }/(4)	式内リテラル
			//	fun/{ ... }/()		式内リテラル
			
			auto fun_tok = t;
			auto prm = AstNode.init;
			if( t == Token.LPAR ){
				/*t = */input_next_ws();
				trace.opCall("Fun1, t=%s%s", t, t.pos);
				prm = parseCommaList(&parseIdent);
				/*t = */input_skip_ws();
				trace.opCall("Fun2, t=%s%s", t, t.pos);
				if( t != Token.RPAR ) error(t.pos, "fun: params RPAR does not close");
				/*t = */input_next_ws();
				trace.opCall("Fun3, t=%s%s", t, t.pos);
			}
			
			auto blk = parseBlock();
			trace.opCall("Fun4, t=%s%s", t, t.pos);
			
			// 引数リストも関数本体もない場合はエラー
			if( !prm && !blk ) error(t.pos, "fun: missing function param and body");
			
			return AstNode.Fun(fun_tok, prm, blk);
		}else{
			return null;
		}
	}
	AstNode parsePrimary(){
		auto trace = Trace("parsePrimary0");
		if( auto n = parseInt() )	return n;
		if( auto n = parseReal() )	return n;
		if( auto n = parseStr() )	return n;
		if( auto n = parseIdent() )	return n;
		if( t == Token.LPAR ){
			trace.opCall("parsePrimary1, t=%s%s", t, t.pos);
			/*t = */input_next_ws();
			auto n = parseExpr();
			/*t = */input_skip_ws();
			if( t != Token.RPAR ){
				error(t.pos, "Expr RPAR does not close");
			}
			/*t = */input_next();
			return n;
		}else{
			return null;
		}
	}
	AstNode parseCall(){
		auto trace = Trace("parseCall0");
		if( auto n = parsePrimary() ){
			trace.opCall("parseCall1, t=%s%s", t, t.pos);
			if( t == Token.LPAR ){
				auto callee = n;
				auto call_tok = t;
				trace.opCall("Call{, t=%s%s", t, t.pos);
				/*t = */input_next_ws();
				auto args = parseCommaList(&parseExpr);
				trace.opCall("}Call, t=%s%s", t, t.pos);
				if( t != Token.RPAR ) error(t.pos, "CallExpr ')' is not closed");
				/*t = */input_next();
				n = AstNode.Call(call_tok, callee, args);
			}
			return n;
		}else{
			return null;
		}
	}
	AstNode parseFactor(){
		auto trace = Trace("parseFactor0");
		if( auto n = parseCall() ){
			trace.opCall("parseFactor1, t=%s%s", t, t.pos);
			if( t == Token.MUL || t == Token.DIV ){
				auto bin_tok = t;
				auto lhs = n;
				/*t = */input_next_ws;
				auto rhs = parseFactor();
				if( !rhs ) error(t.pos, "factor rhs does not exist");
				n = AstNode.MulDiv(bin_tok, lhs, rhs);
			}
			return n;
		}else{
			return null;
		}
	}
	AstNode parseTerm(){
		if( auto n = parseFactor() ){
			if( t == Token.ADD || t == Token.SUB ){
				auto bin_tok = t;
				auto lhs = n;
				/*t = */input_next_ws;
				auto rhs = parseTerm();
				if( !rhs ) error(t.pos, "term rhs does not exist");
				n = AstNode.AddSub(bin_tok, lhs, rhs);
			}
			return n;
		}else{
			return null;
		}
	}
	AstNode parseAssignExpr(){
		auto trace = Trace("parseAssignExpr0");
		if( auto n = parseTerm() ){
			trace.opCall("parseAssignExpr1, t=%s%s", t, t.pos);
			if( t == Token.ASSIGN ){
				if( n.tag != AstTag.IDENT ){
					error(t.pos, "AssinExpr lhs should be Ident");
				}
				auto lhs_tok = t;
				auto lhs = n;
				/*t = */input_next_ws();
				
				auto rhs_pos = t.pos;
				auto rhs = parseTerm();
				if( !rhs ) error(rhs_pos, "AssignExpr rhs does not exist");
				
				n = AstNode.Assign(t, lhs, rhs);
			}
			return n;
		}else{
			return null;
		}
	}
	AstNode parseExpr(){
		auto trace = Trace("parseExpr0");
		return parseAssignExpr();
	}
	AstNode parseDef(){
		auto trace = Trace("parseDef");
		if( t == Token.VAR ){
			auto def_tok = t;
			/*t = */input_next_ws();
			
			auto idt = parseIdent();
			auto val = AstNode.init;
			if( t == Token.ASSIGN ){
				/*t = */input_next_ws();
				val = parseExpr();
			}
			
			return AstNode.Def(def_tok, idt, val);
		}else if( t == Token.FUN ){
			// fun f=(){} 形式 || fun f={} 形式のみ
			
			auto def_tok = t;
			/*t = */input_next_ws();
			trace.opCall("DefFun1, t=%s%s", t, t.pos);
			
			auto idt = parseIdent();
			if( !idt ) error(t.pos, "def: ident does not exist");
			trace.opCall("DefFun2, t=%s%s", t, t.pos);
			
			if( t != Token.ASSIGN ) error(t.pos, "def: initializer does not exist[1]");
			/*t = */input_next_ws();
			trace.opCall("DefFun3, t=%s%s", t, t.pos);
			
			auto fun = parseFun();
			if( !fun ) error(t.pos, "def: initializer does not exist[2]");
			
			return AstNode.Def(def_tok, idt, fun);
		}else{
			return null;
		}
	}
	AstNode parseBlock(){
		auto trace = Trace("parseBlock");
		if( t == Token.LBRAC ){
			/*t = */input_next_ws();
			auto n = parseStmt();
			auto tail = n;
			while( tail ){
				tail.next = parseStmt();
				tail = tail.next;
			}
			if( t != Token.RBRAC ) error(t.pos, "Block stmt should be terminated by '}'");
			/*t = */input_next();
			//trace.opCall("parseBlock1, t=%s%s", t, t.pos);
			return n;
		}else{
			return null;
		}
	}
	AstNode parseStmt(){
		auto trace = Trace("parseStmt");
		AstNode parseS(){
			if( auto n = parseDef() )
			{
				if (t != Token.NEWLINE ) error(t.pos, "Stmt should be terminated by NewLine");
				return n;
			}
			if( auto n = parseExpr() )
			{
				trace.opCall("parseStmt/parseExpr t=%s%s", t.pos, t);
				if (t != Token.NEWLINE && t != Token.RBRAC) error(t.pos, "Stmt should be terminated by NewLine/}");
				return n;
			}
			if( auto n = parseBlock() )
			{
				if (t != Token.NEWLINE ) error(t.pos, "Stmt should be terminated by NewLine");
				return n;
			}
			return null;
		}
		
		if( auto n = parseS() ){
		//	if( t != Token.RBRAC &&
		//		t != Token.NEWLINE ) error(t.pos, "Stmt should be terminated by NewLine");
		//	/*t = */input_next_ws();
			input_skip_ws();
			trace.opCall("parseSmt end : t = %s", t);
			return n;
		}else{
			return null;
		}
	}
	
	
	AstNode parseCommaList(scope AstNode delegate() parseX){
		if( auto n = parseX() ){
			auto tail = n;
			while( t == Token.COMMA ){
				/*t = */input_next_ws();
				tail.next = parseX();
				if( !tail.next ) error(t.pos, "Comma separated error");
				tail = (tail.next);
			}
			return n;
		}else{
			return null;
		}
	}

}

debug(parse)
{
	struct Trace
	{
		string msg;
		Token tok;
		uint stacklen;
		static uint indent = 0;
		static string[] msgstack;
		static ParseContext context;
		this(string s)
		{
			msg = s;
			tok = context.t;
			stacklen = msgstack.length;
			++indent;
		}
		/+static Trace opCall(string s)
		{
			Trace tr;
			tr.msg = s;
			tr.tok = t;
			tr.stacklen = msgstack.length;
			++indent;
			return tr;
		}+/
		void opCall(Args...)(Args args)	// isue4253,4678
		{
			msgstack ~= 
				format("%s..%s\t%s%s",
						tok.pos, context.t.pos,
						debugs.repeat("  ", indent), format(args));
		}
		~this()
		{
			--indent;
			if (context.t!is tok)
			{
				msgstack = 
					msgstack[0 .. stacklen]
					~ format("%s..%s\t%s%s (%s .. %s)",
							tok.pos, context.t.pos,
							debugs.repeat("  ", indent), msg, tok, context.t)
					~ msgstack[stacklen .. $];
					
				if (indent == 0)
				{
					foreach (msg; msgstack)
						writefln("%s", msg);
					msgstack = [];
				}
			}
		}
	}
}
else
{
	struct Trace
	{
		static ParseContext context;
		this(string s){}
		void opCall(Args...)(Args args){}
		~this(){}
	}
}
