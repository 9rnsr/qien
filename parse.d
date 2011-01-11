module parse;

public import lex, sym;
import debugs;

//debug = parse;

/// 
AstNode parse(Toknizer toknizer)
{
	scope ctxt = new ParseContext(toknizer);
	
	auto ast = ctxt.parse();
	
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
		n.i = t.i;
		return n;
	}
	static AstNode Real(ref Token t){
		auto n = new AstNode(t.pos, AstTag.REAL);
		n.r = t.r;
		return n;
	}
	static AstNode Str(ref Token t){
		auto n = new AstNode(t.pos, AstTag.STR);
		n.s = t.s;
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
	in{ assert(t == TokTag.ADD || t == TokTag.SUB); }
	body{
		auto n = new AstNode(t.pos, t == TokTag.ADD ? AstTag.ADD : AstTag.SUB);
		n.lhs = lhs, n.rhs = rhs;
		return n;
	}
	static AstNode MulDiv(ref Token t, AstNode lhs, AstNode rhs)
	in{ assert(t == TokTag.MUL || t == TokTag.DIV); }
	body{
		auto n = new AstNode(t.pos, t == TokTag.MUL ? AstTag.MUL : AstTag.DIV);
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
	
	string toString(){
//		return (cast(const)this).toString();
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
		if( next ){
			res ~= " " ~ next.toString();
		}
		return res;
	}
/+	string toString() const{
	}+/
}


/// AstNode#nextを辿って列挙する
int delegate(scope int delegate(ref AstNode)) each(AstNode n)
{
	return (scope int delegate(ref AstNode) dg){
		while( n ){
			if( n.tag == AstTag.NOP ) break;
			if( auto result = dg(n) ) return result;
			n = n.next;
		}
		return 0;
	};
}


//debug = TraceParse;
debug(TraceParse){
	void traceout(Args...)(Args args)	{ debugout(args); }
}else{
	void traceout(Args...)(Args args)	{  }
}


/// 
class ParseContext
{
	this(Toknizer tok){
		input = tok;
		/*t = */input_next();
	}
	
	AstNode parse(){
		/*t = */input_skip_ws();
		auto n = parseStmt();
		auto tail = n;
		while( tail ){
			tail.next = parseStmt();
			if( !tail.next ) break;
			tail = (tail.next);
		}
		if( t != TokTag.EOF ) error(t.pos, "Program shuld be terminated by EOF");
		
		return n;
	}
	
private:
	Toknizer input;
	Token t;
	
	void input_next(){
		t = input.take();
	}
	void input_skip_ws(){
		while( t == TokTag.NEWLINE ){ /*t = */input_next(); }
	}
	void input_next_ws(){
		//while( (/*t = */input_next()) == TokTag.NEWLINE ){}
		do{ input_next(); }while( t == TokTag.NEWLINE )
	}
	void error(ref FilePos pos, string msg){
		/// 
		static class ParseException : Exception
		{
			this(ref FilePos fpos, string msg){ super("ParseError" ~ fpos.toString ~ ": " ~ msg); }
		}
		throw new ParseException(pos, msg);
	}

	AstNode parseInt(){
		if( t == TokTag.INT ){
			auto n = AstNode.Int(t);
			/*t = */input_next();
			return n;
		}else{
			return null;
		}
	}
	AstNode parseReal(){
		if( t == TokTag.REAL ){
			auto n = AstNode.Real(t);
			/*t = */input_next();
			return n;
		}else{
			return null;
		}
	}
	AstNode parseStr(){
		if( t == TokTag.STR ){
			auto n = AstNode.Str(t);
			/*t = */input_next();
			return n;
		}else{
			return null;
		}
	}
	AstNode parseIdent(){
		if( t == TokTag.IDENT ){
			auto n = AstNode.Ident(t);
			/*t = */input_next();
			return n;
		}else{
			return null;
		}
	}
	AstNode parseFun(){
		if( t==TokTag.LPAR || t==TokTag.LBRAC ){
			// funリテラル本体のparse	... 以下の//で括られたところが対象
			//	fun f = /(){}/		定義
			//	fun f = /{ ... }/	定義
			//	fun/(x){ x*x }/(4)	式内リテラル
			//	fun/{ ... }/()		式内リテラル
			
			auto fun_tok = t;
			auto prm = AstNode.init;
			if( t == TokTag.LPAR ){
				/*t = */input_next_ws();
				//traceout("Fun1, t=%s%s", t, t.pos);
				prm = parseCommaList(&parseIdent);
				/*t = */input_skip_ws();
				//traceout("Fun2, t=%s%s", t, t.pos);
				if( t != TokTag.RPAR ) error(t.pos, "fun: params RPAR does not close");
				/*t = */input_next_ws();
				//traceout("Fun3, t=%s%s", t, t.pos);
			}
			
			auto blk = parseBlock();
			//traceout("Fun4, t=%s%s", t, t.pos);
			
			// 引数リストも関数本体もない場合はエラー
			if( !prm && !blk ) error(t.pos, "fun: missing function param and body");
			
			return AstNode.Fun(fun_tok, prm, blk);
		}else{
			return null;
		}
	}
	AstNode parsePrimary(){
		//traceout("parsePrimary0, t=%s%s", t, t.pos);
		if( auto n = parseInt() )	return n;
		if( auto n = parseReal() )	return n;
		if( auto n = parseStr() )	return n;
		if( auto n = parseIdent() )	return n;
		if( t == TokTag.LPAR ){
			//traceout("parsePrimary1, t=%s%s", t, t.pos);
			/*t = */input_next_ws();
			auto n = parseExpr();
			/*t = */input_skip_ws();
			if( t != TokTag.RPAR ){
				error(t.pos, "Expr RPAR does not close");
			}
			/*t = */input_next();
			return n;
		}else{
			return null;
		}
	}
	AstNode parseCall(){
		//traceout("parseCall0, t=%s%s", t, t.pos);
		if( auto n = parsePrimary() ){
			//traceout("parseCall1, t=%s%s", t, t.pos);
			if( t == TokTag.LPAR ){
				auto callee = n;
				auto call_tok = t;
				//traceout("Call(, t=%s%s", t, t.pos);
				/*t = */input_next_ws();
				auto args = parseCommaList(&parseExpr);
				//traceout("Call), t=%s%s", t, t.pos);
				if( t != TokTag.RPAR ) error(t.pos, "CallExpr ')' is not closed");
				/*t = */input_next();
				n = AstNode.Call(call_tok, callee, args);
			}
			return n;
		}else{
			return null;
		}
	}
	AstNode parseFactor(){
		//traceout("parseFactor0, t=%s%s", t, t.pos);
		if( auto n = parseCall() ){
			//traceout("parseFactor1, t=%s%s", t, t.pos);
			if( t == TokTag.MUL || t == TokTag.DIV ){
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
			if( t == TokTag.ADD || t == TokTag.SUB ){
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
		//traceout("parseAssignExpr0, t=%s%s", t, t.pos);
		if( auto n = parseTerm() ){
			//traceout("parseAssignExpr1, t=%s%s", t, t.pos);
			if( t == TokTag.ASSIGN ){
				if( n.tag != AstTag.IDENT ){
					error(t.pos, "AssinExpr lhs shuld be Ident");
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
		//traceout("parseExpr0, t=%s%s", t, t.pos);
		return parseAssignExpr();
	}
	AstNode parseDef(){
		if( t == TokTag.VAR ){
			auto def_tok = t;
			/*t = */input_next_ws();
			
			auto idt = parseIdent();
			auto val = AstNode.init;
			if( t == TokTag.ASSIGN ){
				/*t = */input_next_ws();
				val = parseExpr();
			}
			
			return AstNode.Def(def_tok, idt, val);
		}else if( t == TokTag.FUN ){
			// fun f=(){} 形式 || fun f={} 形式のみ
			
			auto def_tok = t;
			/*t = */input_next_ws();
			//traceout("DefFun1, t=%s%s", t, t.pos);
			
			auto idt = parseIdent();
			if( !idt ) error(t.pos, "def: ident does not exist");
			//traceout("DefFun2, t=%s%s", t, t.pos);
			
			if( t != TokTag.ASSIGN ) error(t.pos, "def: initializer does not exist[1]");
			/*t = */input_next_ws();
			//traceout("DefFun3, t=%s%s", t, t.pos);
			
			auto fun = parseFun();
			if( !fun ) error(t.pos, "def: initializer does not exist[2]");
			
			return AstNode.Def(def_tok, idt, fun);
		}else{
			return null;
		}
	}
	AstNode parseBlock(){
		//traceout("parseBlock0, t=%s%s", t, t.pos);
		if( t == TokTag.LBRAC ){
			/*t = */input_next_ws();
			auto n = parseStmt();
			auto tail = n;
			while( tail ){
				tail.next = parseStmt();
				tail = tail.next;
			}
			if( t != TokTag.RBRAC ) error(t.pos, "Block stmt shuld be terminated by '}'");
			/*t = */input_next();
			//traceout("parseBlock1, t=%s%s", t, t.pos);
			return n;
		}else{
			return null;
		}
	}
	AstNode parseStmt(){
		//traceout("parseStmt, t=%s%s", t, t.pos);
		AstNode parseS(){
			if( auto n = parseDef() )	return n;
			if( auto n = parseExpr() )	return n;
			if( auto n = parseBlock() )	return n;
			return null;
		}
		
		if( auto n = parseS() ){
			if( t != TokTag.NEWLINE ) error(t.pos, "Stmt shuld be terminated by NewLine");
			/*t = */input_next_ws();
			return n;
		}else{
			return null;
		}
	}
	
	
	AstNode parseCommaList(scope AstNode delegate() parseX){
		if( auto n = parseX() ){
			auto tail = n;
			while( t == TokTag.COMMA ){
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
