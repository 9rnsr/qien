module semant;

public import parse, typ;
import trans;
import debugs;

import typecons.tuple_tie;

import frame : VmFrame;
alias Translate!VmFrame translate;	//FrameとTranslateを結びつける
alias translate.Exp		Exp;
alias translate.Access	Access;
alias translate.Level	Level;

/// 
Ty semant(AstNode n)
{
	auto tenv = new TyEnv();
	auto venv = new VarEnv();
	
	Ty	ty;
	Exp	exp;
	tie(ty, exp) = transExp(translate.outermost, tenv, venv, n);
	
	translate.procEntryExit(translate.outermost, exp);
	
	auto res = translate.getResult();
	
	debugout("semant.frag[] = ");
	foreach( frag; res ){
		frag.debugOut();
		debugout("----");
	}
	return ty;
}


/// 
class SemantException : Exception
{
	this(ref FilePos fpos, string msg){ super("SemanticError" ~ fpos.toString ~ ": " ~ msg); }
}

void error(ref FilePos pos, string msg){
	throw new SemantException(pos, msg);
}


/// 
class VarEnv
{
	struct VarEntry{ Ty ty;	Access access;	Object     isfun=null;	}
//	struct FunEntry{ Ty ty;	Level  level;	temp.Label label;		}
//	static assert(VarEntry.ty    .offsetof == FunEntry.ty   .offsetof);
//	static assert(VarEntry.access.offsetof == FunEntry.level.offsetof);
//	static assert(VarEntry.isfun .offsetof == FunEntry.label.offsetof);
	struct Entry
	{
		union{
//			FunEntry f;
			VarEntry v;
		}
		bool	isfun() const	{ return false/*v.isfun !is null*/; }
		Ty		ty()			{ return v.ty/*isfun ? f.ty : v.ty*/; }
	}
	
	
	Entry[Symbol] tbl;
	
	VarEnv parent;
	
	this(){
	}
	this(VarEnv p)
	in{ assert(p !is null); }
	body{
		parent = p;
	}
	
	bool add(Symbol s, Access access, Ty t){
		if( s in tbl ){
			return false;
		}else{
			Entry entry;
			entry.v = VarEntry(t, access);
			tbl[s] = entry;
			return true;
		}
	}
/+	bool add(Symbol s, Level level, temp.Label label, Ty t){
		if( s in tbl ){
			return false;
		}else{
			Entry entry;
			entry.f = FunEntry(t, level, label);
			tbl[s] = entry;
			return true;
		}
	}+/
	Entry* look(Symbol s){
		if( auto pentry = s in tbl ){
			return pentry;
		}else{
			return parent ? parent.look(s) : null;
		}
	}
	
	string toString(){
		auto len = tbl.length;
		auto str = "[";
		if( parent ) str ~= parent.toString() ~ ", ";
		foreach( sym, entry; tbl ){
			--len;
			if( len == 0 )	str ~= format("%s->%s", sym, entry.ty);
			else			str ~= format("%s->%s, ", sym, entry.ty);
		}
		return str ~ "]";
	}
}


/// 
Tuple!(Ty, Exp) transExp(Level level, TyEnv tenv, VarEnv venv, AstNode n)
out(r){ assert(r.field[1] !is null); }body
{
	const unify = &tenv.unify;	//短縮名
	
	Tuple!(Ty, Exp) trexp(AstNode n){
		final switch( n.tag ){
		case AstTag.NOP:
			assert(0);		//型検査の対象とならないdummy nodeなのでここに来るのはerror
		
		case AstTag.INT:
			return tuple(tenv.Int, translate.constInt(n.i.val));
		
		case AstTag.REAL:
			return tuple(tenv.Real, Exp.init);
		
		case AstTag.STR:
			return tuple(tenv.Str, Exp.init);
		
		case AstTag.IDENT:
			if( auto entry = venv.look(n.sym) ){
				auto inst_t = tenv.instantiate(entry.ty);
				debugout("id %s -> %s", n.sym, entry.ty);
				debugout("   instantiate -> %s", inst_t);
				//debugout("   venv = %s", venv);
				
			//	if( !entry.isfun ){
					return tuple(inst_t, debugout("Ident.Var %s", translate.getVar(level, entry.v.access)));
			//	}else{
			//		return tuple(inst_t, debugout("Ident.Fun %s", translate.getFun(level, entry.f.level, entry.f.label)));
			//	}
			}else{
				error(n.pos, n.sym.name ~ " undefined");
			}
		
		case AstTag.FUN:
			assert(0);		//現状、関数リテラルは許可していないのでここには来ない
		
		case AstTag.ADD:
			Ty	tl, tr;
			Exp	xl, xr;
			tie(tl, xl) = trexp(n.lhs);
			tie(tr, xr) = trexp(n.rhs);
			
			if( unify(tl, tenv.Int) && unify(tr, tenv.Int) ){
				return tuple(tenv.Int, debugout("Add.Exp %s", translate.binAddInt(xl, xr)));
			}else if( unify(tl, tenv.Real) && unify(tr, tenv.Real) ){
				return tuple(tenv.Real, Exp.init);
			}else{
				error(n.pos, "+ mismatch types");
			}
		
		case AstTag.SUB:
			Ty	tl, tr;
			Exp	xl, xr;
			tie(tl, xl) = trexp(n.lhs);
			tie(tr, xr) = trexp(n.rhs);
			
			if( unify(tl, tenv.Int) && unify(tr, tenv.Int) ){
				return tuple(tenv.Int, translate.binSubInt(xl, xr));
			}else if( unify(tl, tenv.Real) && unify(tr, tenv.Real) ){
				return tuple(tenv.Real, Exp.init);
			}else{
				error(n.pos, "- mismatch types");
			}
		
		case AstTag.MUL:
			Ty	tl, tr;
			Exp	xl, xr;
			tie(tl, xl) = trexp(n.lhs);
			tie(tr, xr) = trexp(n.rhs);
			
			if( unify(tl, tenv.Int) && unify(tr, tenv.Int) ){
				return tuple(tenv.Int, translate.binMulInt(xl, xr));
			}else if( unify(tl, tenv.Real) && unify(tr, tenv.Real) ){
				return tuple(tenv.Real, Exp.init);
			}else{
				error(n.pos, "* mismatch types");
			}
		
		case AstTag.DIV:
			Ty	tl, tr;
			Exp	xl, xr;
			tie(tl, xl) = trexp(n.lhs);
			tie(tr, xr) = trexp(n.rhs);
			
			if( unify(tl, tenv.Int) && unify(tr, tenv.Int) ){
				return tuple(tenv.Int, translate.binDivInt(xl, xr));
			}else if( unify(tl, tenv.Real) && unify(tr, tenv.Real) ){
				return tuple(tenv.Real, Exp.init);
			}else{
				error(n.pos, "/ mismatch types");
			}
		
		case AstTag.CALL:
			Ty  tf, tr;  Ty [] ta;
			Exp xf, xr;  Exp[] xa;
			
			tie(tf, xf) = trexp(n.lhs);
			foreach( arg ; each(n.rhs) ){
				ta.length += 1;
				xa.length += 1;
				tie(ta[$-1], xa[$-1]) = trexp(arg);
			}
			tr = tenv.Meta(tenv.newmetavar());
			if( !unify(tf, tenv.Arrow(ta, tr)) ){
				debugout("type mismatch");
				assert(0);
			}
			xr = translate.callFun(xf, xa);
			
			return tuple(tr, xr);
		
		case AstTag.ASSIGN:
			error(n.pos, "*** to do impl ****/assign");
		
		case AstTag.DEF:
			auto id = n.lhs;
			if( n.rhs.tag == AstTag.FUN ){
				auto fn = n.rhs;
				scope fn_tenv = new TyEnv(tenv);
				scope fn_venv = new VarEnv(venv);
				
				auto fn_label = temp.newLabel();
				auto fn_level = translate.newLevel(level, fn_label, []);
				
				Ty[] tp;
				foreach( prm; each(fn.prm) ){
					auto prm_acc = fn_level.allocLocal(true);	//常にescapeするとする
					
					auto t = fn_tenv.Meta(fn_tenv.newmetavar());
					tp ~= t;
					fn_venv.add(prm.sym, prm_acc, t);
				}
				
				Ty  tr, tf;
				tr = fn_tenv.Meta(fn_tenv.newmetavar());
				tf = fn_tenv.Arrow(tp, tr);
				
				Ty  tb;
				Exp xb;
				tie(tb, xb) = transExp(fn_level, fn_tenv, fn_venv, fn.blk);
				if( !fn_tenv.unify(tr, tb) ){
					debugout("return type mismatch in def-fun");
					assert(0);
				}
				
				auto tf2 = fn_tenv.generalize(tf);
				
				auto acc = level.allocLocal(true);	//常にescapeするとする
			//	if( !venv.add(id.sym, fn_level, fn_label, tf2) ){		//todo xbをFunEntryに格納する必要がある？
				if( !venv.add(id.sym, acc, tf2) ){
					error(n.pos, id.toString ~ " is already defined");
				}
				
				debugout("fun tr = %s", tr);
				debugout("    tf = %s", tf);
				debugout("    tb = %s", tb);
				debugout("    tf2 = %s", tf2);
				debugout("    venv = %s", venv);
				
				translate.procEntryExit(fn_level, xb);
				
				return tuple(tenv.Unit, debugout("Def.Fun", translate.assign(level, acc, translate.makeClosure(level, fn_level, fn_label))));			//関数定義は実行処理を伴わない
				
			}else{
				Ty  ty;
				Exp exp;
				tie(ty, exp) = trexp(n.rhs);
				if( ty is tenv.Nil ) error(n.pos, "infer error...");
				
				auto acc = level.allocLocal(true);	//常にescapeするとする
				
				//if( used(id) ){//todo
				if( true ){//todo
					if( !venv.add(id.sym, acc, tenv.Poly([], ty)) )
						error(n.pos, id.toString ~ " is already defined");
				}else{
					if( !venv.add(id.sym, acc, tenv.generalize(ty)) )
						error(n.pos, id.toString ~ " is already defined");
				}
				debugout("var ty = %s", ty);
				debugout("    venv = %s", venv);
				
				return tuple(tenv.Unit, debugout("Def.Var %s", translate.assign(level, acc, exp)));	//初期化式の結果を代入
			}
		}
	}
	
	Ty  ty;
	Exp exp, x;
	tie(ty, exp) = trexp(n);
	while( (n = n.next) !is null ){
		tie(ty, x) = trexp(n);
		exp = translate.sequence(exp, x);
	}
	return tuple(ty, exp);
}



unittest{
	void code(string c){}
	
code(q"CODE
fun foo = (y){
	y*2
}
var a = foo(10)
a
CODE");

}
