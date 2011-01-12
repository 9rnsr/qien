module semant;

import parse, typ;
import trans;
import debugs;
import typecons.match, std.typecons;

debug = semant;

/// 
Ty transProg(AstNode n)
{
	auto tenv = trans.outermost_tenv;
	auto venv = new VarEnv();
	
	findEscape(venv, n);

	Ty ty;
	Ex ex;
	tie[ty, ex] <<= transExp(trans.outermost, tenv, venv, n);
	
	trans.procEntryExit(trans.outermost, ex);
	
	debug(semant)
	{
		debugout("========");
		debugout("transProg = %s", ty);
		
		debugout("transProg.frag[] = ");
		foreach (f; trans.getResult()){
			debugout("----");
			debugout("%s : ", f.p[1].name);
			f.debugOut();
		}
	}

	return ty;
}

/// 
void error(ref FilePos pos, string msg)
{
	static class SemantException : Exception
	{
		this(ref FilePos fpos, string msg)
		{
			super("SemanticError" ~ fpos.toString ~ ": " ~ msg);
		}
	}

	throw new SemantException(pos, msg);
}

VarEnv[AstNode] venvof;

/// 
class VarEnv
{
	struct Entry
	{
		uint	depth;
		bool	escape;
		
		Ty		ty;
		Access	access;
	}
	
	Entry[Symbol] tbl;
	
	VarEnv parent;
	
	this()
	{
		// do nothing
	}
	this(VarEnv p)
	in{ assert(p !is null); }
	body{
		parent = p;
	}
	
	bool add(Symbol s, uint dep, bool esc)
	{
		if (s in tbl)
			return false;
		
		tbl[s] = Entry(dep, esc, null, null);
		return true;
	}
	bool add(Symbol s, Access acc, Ty t)
	{
	//	if (s in tbl)
	//		return false;
	//	
	//	tbl[s] = Entry(t, acc);
		
		auto entry = s in tbl;
		if (entry && !entry.access && !entry.ty)
		{
			entry.access = acc;
			entry.ty = t;
			return true;
		}
		else
			return false;
	}
	Entry* opIn_r(Symbol s)
	{
		if (auto pentry = s in tbl)
			return pentry;
		else
			return parent ? (s in parent) : null;
	}

	string toString()
	{
		auto len = tbl.length;
		auto str = "[";
		if (parent)
			str ~= parent.toString() ~ ", ";
		foreach (sym, entry; tbl)
		{
			str ~= format("%s->%s", sym, entry.ty);
			if( --len > 0 )
				str ~= ", ";
		}
		return str ~ "]";
	}
}


/// 
Tuple!(Ty, Ex) transExp(Level level, TypEnv tenv, VarEnv venv, AstNode n)
out(r){ assert(r.field[1] !is null); }body
{
	const unify = &tenv.unify;	//短縮名
	
	Tuple!(Ty, Ex) trexp(AstNode n)
	{
		final switch (n.tag)
		{
		case AstTag.NOP:
			assert(0);		//型検査の対象とならないdummy nodeなのでここに来るのはerror
		
		case AstTag.INT:
			return tuple(tenv.Int, trans.immediate(n.i));
		
		case AstTag.REAL:
			return tuple(tenv.Real, trans.immediate(n.r));
		
		case AstTag.STR:
			return tuple(tenv.Str, Ex.init);
		
		case AstTag.IDENT:
			if (auto entry = n.sym in venv)
			{
				auto inst_t = tenv.instantiate(entry.ty);
//				debug(semant) debugout("id %s -> %s", n.sym, entry.ty);
//				debug(semant) debugout("   instantiate -> %s", inst_t);
//			//	debug(semant) debugout("   venv = %s", venv);
				
				return tuple(inst_t, trans.getVar(level, entry.access));
			}
			else
			{
				error(n.pos, n.sym.name ~ " undefined");
			}
		
		case AstTag.FUN:
			assert(0);		//現状、関数リテラルは許可していないのでここには来ない
		
		case AstTag.ADD:
			Ty tl, tr;
			Ex xl, xr;
			tie[tl, xl] <<= trexp(n.lhs);
			tie[tr, xr] <<= trexp(n.rhs);
			
			if (unify(tl, tenv.Int) && unify(tr, tenv.Int))
				return tuple(tenv.Int, trans.binAddInt(xl, xr));
			else if (unify(tl, tenv.Real) && unify(tr, tenv.Real))
				return tuple(tenv.Real, Ex.init);
			else
				error(n.pos, "+ mismatch types");
		
		case AstTag.SUB:
			Ty tl, tr;
			Ex xl, xr;
			tie[tl, xl] <<= trexp(n.lhs);
			tie[tr, xr] <<= trexp(n.rhs);
			
			if (unify(tl, tenv.Int) && unify(tr, tenv.Int))
				return tuple(tenv.Int, trans.binSubInt(xl, xr));
			else if (unify(tl, tenv.Real) && unify(tr, tenv.Real))
				return tuple(tenv.Real, Ex.init);
			else
				error(n.pos, "- mismatch types");
		
		case AstTag.MUL:
			Ty tl, tr;
			Ex xl, xr;
			tie[tl, xl] <<= trexp(n.lhs);
			tie[tr, xr] <<= trexp(n.rhs);
			
			if (unify(tl, tenv.Int) && unify(tr, tenv.Int))
				return tuple(tenv.Int, trans.binMulInt(xl, xr));
			else if (unify(tl, tenv.Real) && unify(tr, tenv.Real))
				return tuple(tenv.Real, Ex.init);
			else
				error(n.pos, "* mismatch types");
		
		case AstTag.DIV:
			Ty tl, tr;
			Ex xl, xr;
			tie[tl, xl] <<= trexp(n.lhs);
			tie[tr, xr] <<= trexp(n.rhs);
			
			if (unify(tl, tenv.Int) && unify(tr, tenv.Int))
				return tuple(tenv.Int, trans.binDivInt(xl, xr));
			else if (unify(tl, tenv.Real) && unify(tr, tenv.Real))
				return tuple(tenv.Real, Ex.init);
			else
				error(n.pos, "/ mismatch types");
		
		case AstTag.CALL:
			Ty tf, tr;  Ty[] ta;
			Ex xf, xr;  Ex[] xa;
			
			tie[tf, xf] <<= trexp(n.lhs);
			foreach (arg ; each(n.rhs))
			{
				ta.length += 1;
				xa.length += 1;
				tie[ta[$-1], xa[$-1]] <<= trexp(arg);
			}
			tr = tenv.Meta(tenv.newmetavar());
			if (!unify(tf, tenv.Arrow(ta, tr)))
				assert(0, "type mismatch");
			
			xr = trans.callFun(xf, xa);
			return tuple(tr, xr);
		
		case AstTag.ASSIGN:
			error(n.pos, "*** to do impl ****/assign");
		
		case AstTag.DEF:
			auto id = n.lhs;
			if (n.rhs.tag == AstTag.FUN)
			{
				auto fn = n.rhs;
				auto fn_tenv = new TypEnv(tenv);
				auto fn_venv = venvof[n];	//new VarEnv(venv);
				
				auto fn_label = newLabel();
				auto fn_level = trans.newLevel(level, fn_label/*, []*/);
				
				Ty[] tp;
				foreach (prm; each(fn.prm))
				{
					auto prm_typ = fn_tenv.Meta(fn_tenv.newmetavar());
					auto prm_esc = (prm.sym in fn_venv).escape;
					auto prm_acc = fn_level.allocLocal(prm_typ, true/*prm_esc*/);	// 仮引数は常にFrameに割り当て
					
					tp ~= prm_typ;
					fn_venv.add(prm.sym, prm_acc, prm_typ);
				}
				
				Ty tr, tf;
				tr = fn_tenv.Meta(fn_tenv.newmetavar());
				tf = fn_tenv.Arrow(tp, tr);
				
				trans.procEntry(fn_level);
				
				Ty tb;
				Ex xb;
				tie[tb, xb] <<= transExp(fn_level, fn_tenv, fn_venv, fn.blk);
				if (!fn_tenv.unify(tr, tb))
					error(n.pos, "return type mismatch in def-fun");
				
				auto tf2 = fn_tenv.generalize(tf);
				
				auto esc = (id.sym in venv).escape;
				auto acc = level.allocLocal(tf, true);	// 関数値はsize>1wordなのでSlotは常にescapeさせる
				if (!venv.add(id.sym, acc, tf2))
					error(n.pos, id.toString ~ " is already defined");
				
//				debug(semant) debugout("fun tr = %s", tr);
//				debug(semant) debugout("    tf = %s", tf);
//				debug(semant) debugout("    tb = %s", tb);
//				debug(semant) debugout("    tf2 = %s", tf2);
//				debug(semant) debugout("    venv = %s", venv);
				
				trans.procEntryExit(fn_level, xb);
				
				if (esc)
					return tuple(tenv.Unit,
							trans.assign(
								level,
								acc,
								trans.makeClosure(level, fn_level, fn_label)));
				else
					return tuple(tenv.Unit,
							trans.assign(
								level,
								acc,
								trans.makeFunction(level, fn_level, fn_label)));
			}
			else
			{
				Ty ty;
				Ex ex;
				tie[ty, ex] <<= trexp(n.rhs);
				if (ty is tenv.Nil)
					error(n.pos, "infer error...");
				
				auto esc = (id.sym in venv).escape;
				auto acc = level.allocLocal(ty, esc);
				
				//if (used(id) ){//todo
				if (true)//todo
				{
					if (!venv.add(id.sym, acc, tenv.Poly([], ty)))
						error(n.pos, id.toString ~ " is already defined");
				}
				else
				{
					if (!venv.add(id.sym, acc, tenv.generalize(ty)))
						error(n.pos, id.toString ~ " is already defined");
				}
//				debug(semant) debugout("var ty = %s", ty);
//				debug(semant) debugout("    venv = %s", venv);
				
				//初期化式の結果を代入
				return tuple(tenv.Unit,
							trans.assign(level, acc, ex));
			}
		}
	}
	
	Ty ty;
	Ex ex, x;
  version(none){
	tie[ty, ex] <<= trexp(n);
	if (n.next is null)
		ex = trans.ret(ex);
	while ((n = n.next) !is null)
	{
		tie[ty, x] <<= trexp(n);
		
		if (n.next is null)
			x = trans.ret(x);
		
		ex = trans.sequence(ex, x);
	}
  }else{
	do{
		tie[ty, x] <<= trexp(n);
		if (n.next is null)
			x = trans.ret(x);
		ex = trans.sequence(ex, x);
	}while ((n = n.next) !is null)
  }

	return tuple(ty, ex);
}


void findEscape(VarEnv outermost_venv, AstNode n)
{
	void traverse(VarEnv venv, uint depth, AstNode n)
	{
		final switch (n.tag)
		{
		case AstTag.NOP:
			assert(0);		//型検査の対象とならないdummy nodeなのでここに来るのはerror
		
		case AstTag.INT:
		case AstTag.REAL:
		case AstTag.STR:
			break;
		
		case AstTag.IDENT:
			if (auto entry = n.sym in venv)
			{
				if (entry.depth < depth)
				{
					entry.escape = true;
					debugout("escaped %s : depth %s < %s", n.sym, entry.depth, depth);
				}
			}
			else
				error(n.pos, n.sym.name ~ " undefined");
			break;
		
		case AstTag.FUN:
			assert(0);		//現状、関数リテラルは許可していないのでここには来ない
		
		case AstTag.ADD:
		case AstTag.SUB:
		case AstTag.MUL:
		case AstTag.DIV:
			traverse(venv, depth, n.lhs);
			traverse(venv, depth, n.rhs);
			break;
		
		case AstTag.CALL:
			traverse(venv, depth, n.lhs);
			foreach (arg ; each(n.rhs))
				traverse(venv, depth, arg);
			break;
		
		case AstTag.ASSIGN:
			error(n.pos, "*** to do impl ****/assign");
		
		case AstTag.DEF:
			auto id = n.lhs;
			if (n.rhs.tag == AstTag.FUN)
			{
				auto fn = n.rhs;
				auto fn_venv = venvof[n] = new VarEnv(venv);
				
				venv.add(id.sym, depth, false);
				foreach (prm; each(fn.prm))
					fn_venv.add(prm.sym, depth+1, false);
				traverse(fn_venv, depth+1, fn.blk);
			}
			else
				venv.add(id.sym, depth, false);
			break;
		}
		
		if (n.next)
			traverse(venv, depth, n.next);
	}

	traverse(outermost_venv, 0, n);
}



debug(semant)
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
