module semant;

import parse, typ;
import trans;
import frame : Fragment;
import debugs;
import xtk.format : format;
import xtk.match;
import std.typecons;

//debug = semant;

/// 
Fragment[] transProg(AstNode n)
{
	Fragment[] frag = [];

	void procEntryExit(Level lv, Ex ex)
	{
		frag ~= trans.procEntryExit(lv, ex);
	}
	.procEntryExit = &procEntryExit;
	
	trans.initialize();
	
	auto tenv = new TypEnv();
	auto venv = new VarEnv();
	
	// 最上位のLevelを表す定義済みオブジェクト
	auto outermost = newLevel(null, newLabel("__toplevel"));

	findEscape(n);

	Ty ty = transTyp(outermost, tenv, venv, null, n);
	std.stdio.writefln("transProg : %s", ty);
//	assert(0);
	Ex ex = transExp(outermost, tenv, venv, n);
	
	procEntryExit(outermost, ex);
	
	frag = frag.reverse;
	

	return frag;
}

private void delegate(Level, Ex) procEntryExit;

/// 
Throwable error(ref FilePos pos, string msg)
{
//	static class SemantError : Error
	static class SemantException : Exception
	{
		this(ref FilePos fpos, string msg)
		{
			super(format("%s SemantError : %s", fpos, msg));
		}
		override string toString()
		{
			return msg;
		}
	}
	return new SemantException(pos, msg);
}

Tuple!(uint, "depth", bool, "escape")[Symbol] mapVarEsc;

/// 
class VarEnv
{
	struct Entry
	{
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
	
	bool add(Symbol s, Access acc, Ty t)
	{
		if (s in tbl)
			return false;
		
		tbl[s] = Entry(t, acc);
		return true;
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

Tuple!(Level, TypEnv, VarEnv)[AstNode] fun_map;
Ty[AstNode] callType;

Ty transTyp(Level level, TypEnv tenv, VarEnv venv, Ty type, AstNode n)
{
	const unify = &tenv.unify;	//短縮名
	
	Ty trtyp(Ty type, AstNode n)
	{
		Ty typecheck(Ty ty)
		{
			if (type is null)
				return ty;
			else if (unify(ty, type))
				return ty;
			else
				throw error(n.pos, format("cannot type inference : %s and %s", ty, type));
		}
		
		final switch (n.tag)
		{
		case AstTag.NOP:
			assert(0);		//型検査の対象とならないdummy nodeなのでここに来るのはerror
		
		case AstTag.INT:
			return typecheck(tenv.Int);
		
		case AstTag.REAL:
			return typecheck(tenv.Real);
		
		case AstTag.STR:
			return typecheck(tenv.Str);
		
		case AstTag.IDENT:
			if (auto entry = n.sym in venv)
			{
				auto ty = typecheck(tenv.instantiate(entry.ty));
				debug(semant) std.stdio.writefln("ident %s : %s (instantiated = %s)", n.sym, ty, ty.isInstantiated);
				std.stdio.writefln("DEBUG ident %s : access = %s", n.sym, entry.access);
				return ty;
			}
			else
				throw error(n.pos, n.sym.name ~ " undefined");
		
		case AstTag.FUN:
			assert(0);		//現状、関数リテラルは許可していないのでここには来ない
		
		case AstTag.ADD:	// FUTURE: built-in function CALLに統一
		case AstTag.SUB:	// FUTURE: built-in function CALLに統一
		case AstTag.MUL:	// FUTURE: built-in function CALLに統一
		case AstTag.DIV:	// FUTURE: built-in function CALLに統一
			auto tl = trtyp(type, n.lhs);	bool isLhsInferred = tl.isInferred;
			auto tr = trtyp(type, n.rhs);	bool isRhsInferred = tr.isInferred;
			
			debug(semant) std.stdio.writefln("BIN            = lhs : %s, rhs : %s", tl, tr);
			debug(semant) std.stdio.writefln("BIN isInferred = %s/%s", isLhsInferred, isRhsInferred);
			
			bool isLhsFixn = isLhsInferred ? unify(tl, tenv.Int) : true;
			bool isRhsFixn = isRhsInferred ? unify(tr, tenv.Int) : true;
			debug(semant) std.stdio.writefln("BIN isFixnum   = %s/%s", isLhsFixn, isRhsFixn);
			if (isLhsFixn && isRhsFixn)
			{
				if (!isLhsInferred) tl = trtyp(tenv.Int, n.lhs);
				if (!isRhsInferred) tr = trtyp(tenv.Int, n.rhs);
				debug(semant) std.stdio.writefln("BIN Fixnum ope = lhs : %s, rhs : %s", tl, tr);
				return tenv.Int;
			}

			bool isLhsFlon = isLhsInferred ? unify(tl, tenv.Real) : true;
			bool isRhsFlon = isRhsInferred ? unify(tr, tenv.Real) : true;
			if (isLhsFlon && isRhsFlon)
			{
				if (!isLhsInferred) tl = trtyp(tenv.Real, n.lhs);
				if (!isRhsInferred) tr = trtyp(tenv.Real, n.rhs);
				return tenv.Real;
			}
			
			throw error(n.pos, format("incompatible types for %s : %s and %s", n, tl, tr));
		
		case AstTag.CALL:
			Ty tf, tr;  Ty[] ta;
			bool isInferredArgs = true;
			
			debug(semant) std.stdio.writefln("call ----");
			foreach (arg ; n.rhs[])
			{
				ta.length += 1;
				ta[$-1] = trtyp(null, arg);
					// Each type of argumens is always inferred (May be Meta).
				isInferredArgs = isInferredArgs && ta[$-1].isInferred;
			}
			tr = type is null ? tenv.Meta() : type;
			tf = tenv.Arrow(ta, tr);
			tf = trtyp(tf, n.lhs);
			debug(semant) std.stdio.writefln("call = fun : %s, args.inferred = %s", tf, isInferredArgs);
			tr = typecheck(tf.returnType);
			callType[n] = tr;	// save
			return tr;
		
		case AstTag.ASSIGN:
			throw error(n.pos, "*** to do impl ****/assign");
		
		case AstTag.DEF:
			auto id = n.lhs;
			if (n.rhs.tag == AstTag.FUN)
			{
				auto fn = n.rhs;
				auto fn_level = trans.newLevel(level, newLabel());
				auto fn_tenv  = new TypEnv(tenv);
				auto fn_venv  = new VarEnv(venv);
				
				fun_map[fn] = tuple(fn_level, fn_tenv, fn_venv);
				
				Ty[] tp;
				foreach (prm; fn.prm[])
				{
					auto prm_typ = fn_tenv.Meta();
					auto prm_esc = mapVarEsc[prm.sym].escape;
					auto prm_acc = fn_level.allocLocal(prm_typ, true/*prm_esc*/);	// 仮引数は常にFrameに割り当て
					
					tp ~= prm_typ;
					fn_venv.add(prm.sym, prm_acc, prm_typ);
					
					debug(semant) std.stdio.writefln("fun_prm %s : %s", prm.sym, prm_typ);
				}
				
				Ty tr = fn_tenv.Meta();
				Ty tf = fn_tenv.Arrow(tp, tr);
				Ty tb = transTyp(fn_level, fn_tenv, fn_venv, tr, fn.blk);
				
				debug(semant) std.stdio.writefln("fun_def body : %s, fun : %s", tb, tf);
				tf = fn_tenv.generalize(tf);
				debug(semant) std.stdio.writefln("fun_def body : %s, fun : %s", tb, tf);
				if (!tf.isInstantiated)
					throw error(n.rhs.pos, "Cannot instantiate polymorphic function yet.");
				
				auto esc = mapVarEsc[id.sym].escape;
				auto acc = level.allocLocal(tf, true);	// 関数値はsize>1wordなのでSlotは常にescapeさせる
				if (!venv.add(id.sym, acc, tf))
					throw error(n.pos, id.toString ~ " is already defined");
				
				debug(semant) std.stdio.writefln("fun_def %s : %s", id.sym, tf);
				
				return typecheck(tenv.Unit);
			}
			else
			{
				Ty ty;
				ty = trtyp(null, n.rhs);
				if (ty is tenv.Nil)
					throw error(n.pos, "infer error...");
				
				auto esc = mapVarEsc[id.sym].escape;
				if (ty.isFunction) esc = true;	// alocation hack?
				
				//if (used(id) )	// TODO
				//{
					ty = tenv.generalize(ty);
					auto acc = level.allocLocal(ty, esc);
					if (!venv.add(id.sym, acc, ty))
						throw error(n.pos, id.toString ~ " is already defined");
				//}
				//debug(semant) std.stdio.writefln("var_def %s : %s", id.sym, ty);
				
				return typecheck(tenv.Unit);
			}
		}
	}
	
	Ty ty;
	do{
		bool isLast = n.next is null;
		ty = trtyp(isLast ? type : null, n);
	}while ((n = n.next) !is null)

	return ty;
}

/// 
Ex transExp(Level level, TypEnv tenv, VarEnv venv, AstNode n)
{
	Ex trexp(AstNode n)
	{
		final switch (n.tag)
		{
		case AstTag.NOP:
			assert(0);		//型検査の対象とならないdummy nodeなのでここに来るのはerror
		
		case AstTag.INT:
			return trans.immediate(n.i);
		
		case AstTag.REAL:
			return trans.immediate(n.r);
		
		case AstTag.STR:
			return Ex.init;
		
		case AstTag.IDENT:
			auto entry = n.sym in venv;
			auto xi = trans.variable(level, entry.access);
			std.stdio.writefln("DEBUG ident %s : access = %s", n.sym, entry.access);
			return xi;
		
		case AstTag.FUN:
			assert(0);		//現状、関数リテラルは許可していないのでここには来ない
		
		case AstTag.ADD:	// FUTURE: built-in function CALLに統一
			Ex xl = trexp(n.lhs);
			Ex xr = trexp(n.rhs);
			debug(semant) std.stdio.writefln("ADD = lhs = %s, rhs = %s", xl, xr);
		//	if (type == tenv.Int)
				return trans.binAddInt(xl, xr);
		//	else
		//		return Ex.init;
		
		case AstTag.SUB:	// FUTURE: built-in function CALLに統一
			Ex xl = trexp(n.lhs);
			Ex xr = trexp(n.rhs);
			debug(semant) std.stdio.writefln("SUB = lhs = %s, rhs = %s", xl, xr);
		//	if (type == tenv.Int)
				return trans.binSubInt(xl, xr);
		//	else
		//		return Ex.init;
		
		case AstTag.MUL:	// FUTURE: built-in function CALLに統一
			Ex xl = trexp(n.lhs);
			Ex xr = trexp(n.rhs);
			debug(semant) std.stdio.writefln("SUB = lhs = %s, rhs = %s", xl, xr);
		//	if (type == tenv.Int)
				return trans.binMulInt(xl, xr);
		//	else
		//		return Ex.init;
		
		case AstTag.DIV:	// FUTURE: built-in function CALLに統一
			Ex xl = trexp(n.lhs);
			Ex xr = trexp(n.rhs);
			debug(semant) std.stdio.writefln("SUB = lhs = %s, rhs = %s", xl, xr);
		//	if (type == tenv.Int)
				return trans.binDivInt(xl, xr);
		//	else
		//		return Ex.init;
		
		case AstTag.CALL:
			Ex[] xa;
			
			debug(semant) std.stdio.writefln("call ----");
			foreach (arg ; n.rhs[])
			{
				xa.length += 1;
				xa[$-1] = trexp(arg);
			}
			Ty tf = *(n in callType);
			Ex xf = trexp(n.lhs);
			debug(semant) std.stdio.writefln("call fun = %s : %s", xf, tf);
			Ex xr = trans.callFun(tf, xf, xa);
			return xr;
		
		case AstTag.ASSIGN:
			throw error(n.pos, "*** to do impl ****/assign");
		
		case AstTag.DEF:
			auto id = n.lhs;
			if (n.rhs.tag == AstTag.FUN)
			{
				auto fn = n.rhs;
			// transTyでfnに関連付けておいて、ここで取り出す
			//	auto fn_level = trans.newLevel(level, fn_label);
			//	auto fn_tenv = new TypEnv(tenv);
			//	auto fn_venv = new VarEnv(venv);
				Level  fn_level;
				TypEnv fn_tenv;
				VarEnv fn_venv;
				tie[fn_level, fn_tenv, fn_venv] <<= fun_map[fn];
				
				fn_level.allocLocal();	// 仮引数のSlotを確保させる
				
				Ex xb = transExp(fn_level, fn_tenv, fn_venv, fn.blk);
				procEntryExit(fn_level, xb);
				
				auto esc = mapVarEsc[id.sym].escape;
				auto acc = (id.sym in venv).access;
				acc.allocSlot();
				auto xf = trans.immediate(fn_level, esc);	// 関数値
				return trans.assign(level, acc, xf);
			}
			else
			{
				Ex xv = trexp(n.rhs);
				auto acc = (id.sym in venv).access;
				acc.allocSlot();
				return trans.assign(level, acc, xv);
			}
		}
	}
	
	Ex ex;
	do{
		bool isLast = n.next is null;
		Ex x = trexp(n);
		if (isLast)
			x = trans.ret(x);
		debugCodeMap(level, n, x);
		ex = trans.sequence(ex, x);
	}while ((n = n.next) !is null)

	return ex;
}



/+
/// 
Tuple!(Ty, Ex) transExp(Level level, TypEnv tenv, VarEnv venv, Ty type, AstNode n)
out(r){ assert(!(cast(Ty)r.field[0]).isInstantiated || r.field[1] !is null); }body
{
	const unify = &tenv.unify;	//短縮名
	
	Tuple!(Ty, Ex) trexp(Ty type, AstNode n)
	{
		Ty typecheck(Ty ty)
		{
			if (type is null)
				return ty;
			else if (unify(ty, type))
				return ty;
			else
				throw error(n.pos, format("cannot type inference : %s and %s", ty, type));
		}
		
		final switch (n.tag)
		{
		case AstTag.NOP:
			assert(0);		//型検査の対象とならないdummy nodeなのでここに来るのはerror
		
		case AstTag.INT:
			return tuple(typecheck(tenv.Int), trans.immediate(n.i));
		
		case AstTag.REAL:
			return tuple(typecheck(tenv.Real), trans.immediate(n.r));
		
		case AstTag.STR:
			return tuple(typecheck(tenv.Str), Ex.init);
		
		case AstTag.IDENT:
			if (auto entry = n.sym in venv)
			{
				auto ty = typecheck(tenv.instantiate(entry.ty));
				debug(semant) std.stdio.writefln("ident %s : %s (instantiated = %s)", n.sym, ty, ty.isInstantiated);
			//	return tuple(ty,
			//	             ty.isInstantiated ? trans.variable(level, entry.access)
			//	                               : null);
				auto ex = (ty.isInstantiated ? trans.variable(level, entry.access) : null);
				std.stdio.writefln("DEBUG ident %s : access = %s", n.sym, entry.access);
				return tuple(ty, ex);
			}
			else
				throw error(n.pos, n.sym.name ~ " undefined");
		
		case AstTag.FUN:
			assert(0);		//現状、関数リテラルは許可していないのでここには来ない
		
		case AstTag.ADD:	// FUTURE: built-in function CALLに統一
			Ty tl, tr;
			Ex xl, xr;
			tie[tl, xl] <<= trexp(type, n.lhs);		bool isLhsInferred = tl.isInferred;
			tie[tr, xr] <<= trexp(type, n.rhs);		bool isRhsInferred = tr.isInferred;
			
			debug(semant) std.stdio.writefln("ADD            = lhs = %s : %s, rhs = %s : %s", xl, tl, xr, tr);
			debug(semant) std.stdio.writefln("ADD isInferred = %s/%s", isLhsInferred, isRhsInferred);
			
			bool isLhsFixn = isLhsInferred ? unify(tl, tenv.Int) : true;
			bool isRhsFixn = isRhsInferred ? unify(tr, tenv.Int) : true;
			debug(semant) std.stdio.writefln("ADD isFixnum   = %s/%s", isLhsFixn, isRhsFixn);
			if (isLhsFixn && isRhsFixn)
			{
				if (!isLhsInferred) tie[tl, xl] <<= trexp(tenv.Int, n.lhs);
				if (!isRhsInferred) tie[tr, xr] <<= trexp(tenv.Int, n.rhs);
				debug(semant) std.stdio.writefln("ADD Fixnum ope = lhs = %s : %s, rhs = %s : %s", xl, tl, xr, tr);
				return tuple(tenv.Int, trans.binAddInt(xl, xr));
			}

			bool isLhsFlon = isLhsInferred ? unify(tl, tenv.Real) : true;
			bool isRhsFlon = isRhsInferred ? unify(tr, tenv.Real) : true;
			if (isLhsFlon && isRhsFlon)
			{
				if (!isLhsInferred) tie[tl, xl] <<= trexp(tenv.Real, n.lhs);
				if (!isRhsInferred) tie[tr, xr] <<= trexp(tenv.Real, n.rhs);
				return tuple(tenv.Real, Ex.init);
			}
			
			throw error(n.pos, format("incompatible types for %s : %s and %s", n, tl, tr));
		
		case AstTag.SUB:	// FUTURE: built-in function CALLに統一
			Ty tl, tr;
			Ex xl, xr;
			tie[tl, xl] <<= trexp(type, n.lhs);		bool isLhsInferred = tl.isInferred;
			tie[tr, xr] <<= trexp(type, n.rhs);		bool isRhsInferred = tr.isInferred;
			
			debug(semant) std.stdio.writefln("SUB            = lhs = %s : %s, rhs = %s : %s", xl, tl, xr, tr);
			debug(semant) std.stdio.writefln("SUB isInferred = %s/%s", isLhsInferred, isRhsInferred);
			
			bool isLhsFixn = isLhsInferred ? unify(tl, tenv.Int) : true;
			bool isRhsFixn = isRhsInferred ? unify(tr, tenv.Int) : true;
			debug(semant) std.stdio.writefln("SUB isFixnum   = %s/%s", isLhsFixn, isRhsFixn);
			if (isLhsFixn && isRhsFixn)
			{
				if (!isLhsInferred) tie[tl, xl] <<= trexp(tenv.Int, n.lhs);
				if (!isRhsInferred) tie[tr, xr] <<= trexp(tenv.Int, n.rhs);
				debug(semant) std.stdio.writefln("SUB Fixnum ope = lhs = %s : %s, rhs = %s : %s", xl, tl, xr, tr);
				return tuple(tenv.Int, trans.binSubInt(xl, xr));
			}

			bool isLhsFlon = isLhsInferred ? unify(tl, tenv.Real) : true;
			bool isRhsFlon = isRhsInferred ? unify(tr, tenv.Real) : true;
			if (isLhsFlon && isRhsFlon)
			{
				if (!isLhsInferred) tie[tl, xl] <<= trexp(tenv.Real, n.lhs);
				if (!isRhsInferred) tie[tr, xr] <<= trexp(tenv.Real, n.rhs);
				return tuple(tenv.Real, Ex.init);
			}
			
			throw error(n.pos, format("incompatible types for %s : %s and %s", n, tl, tr));
		
		case AstTag.MUL:	// FUTURE: built-in function CALLに統一
			Ty tl, tr;
			Ex xl, xr;
			tie[tl, xl] <<= trexp(type, n.lhs);		bool isLhsInferred = tl.isInferred;
			tie[tr, xr] <<= trexp(type, n.rhs);		bool isRhsInferred = tr.isInferred;
			
			debug(semant) std.stdio.writefln("MUL            = lhs = %s : %s, rhs = %s : %s", xl, tl, xr, tr);
			debug(semant) std.stdio.writefln("MUL isInferred = %s/%s", isLhsInferred, isRhsInferred);
			
			bool isLhsFixn = isLhsInferred ? unify(tl, tenv.Int) : true;
			bool isRhsFixn = isRhsInferred ? unify(tr, tenv.Int) : true;
			debug(semant) std.stdio.writefln("MUL isFixnum   = %s/%s", isLhsFixn, isRhsFixn);
			if (isLhsFixn && isRhsFixn)
			{
				if (!isLhsInferred) tie[tl, xl] <<= trexp(tenv.Int, n.lhs);
				if (!isRhsInferred) tie[tr, xr] <<= trexp(tenv.Int, n.rhs);
				debug(semant) std.stdio.writefln("MUL Fixnum ope = lhs = %s : %s, rhs = %s : %s", xl, tl, xr, tr);
				return tuple(tenv.Int, trans.binMulInt(xl, xr));
			}

			bool isLhsFlon = isLhsInferred ? unify(tl, tenv.Real) : true;
			bool isRhsFlon = isRhsInferred ? unify(tr, tenv.Real) : true;
			if (isLhsFlon && isRhsFlon)
			{
				if (!isLhsInferred) tie[tl, xl] <<= trexp(tenv.Real, n.lhs);
				if (!isRhsInferred) tie[tr, xr] <<= trexp(tenv.Real, n.rhs);
				return tuple(tenv.Real, Ex.init);
			}
			
			throw error(n.pos, format("incompatible types for %s : %s and %s", n, tl, tr));
		
		case AstTag.DIV:	// FUTURE: built-in function CALLに統一
			Ty tl, tr;
			Ex xl, xr;
			tie[tl, xl] <<= trexp(type, n.lhs);		bool isLhsInferred = tl.isInferred;
			tie[tr, xr] <<= trexp(type, n.rhs);		bool isRhsInferred = tr.isInferred;
			
			debug(semant) std.stdio.writefln("DIV            = lhs = %s : %s, rhs = %s : %s", xl, tl, xr, tr);
			debug(semant) std.stdio.writefln("DIV isInferred = %s/%s", isLhsInferred, isRhsInferred);
			
			bool isLhsFixn = isLhsInferred ? unify(tl, tenv.Int) : true;
			bool isRhsFixn = isRhsInferred ? unify(tr, tenv.Int) : true;
			debug(semant) std.stdio.writefln("DIV isFixnum   = %s/%s", isLhsFixn, isRhsFixn);
			if (isLhsFixn && isRhsFixn)
			{
				if (!isLhsInferred) tie[tl, xl] <<= trexp(tenv.Int, n.lhs);
				if (!isRhsInferred) tie[tr, xr] <<= trexp(tenv.Int, n.rhs);
				debug(semant) std.stdio.writefln("DIV Fixnum ope = lhs = %s : %s, rhs = %s : %s", xl, tl, xr, tr);
				return tuple(tenv.Int, trans.binDivInt(xl, xr));
			}

			bool isLhsFlon = isLhsInferred ? unify(tl, tenv.Real) : true;
			bool isRhsFlon = isRhsInferred ? unify(tr, tenv.Real) : true;
			if (isLhsFlon && isRhsFlon)
			{
				if (!isLhsInferred) tie[tl, xl] <<= trexp(tenv.Real, n.lhs);
				if (!isRhsInferred) tie[tr, xr] <<= trexp(tenv.Real, n.rhs);
				return tuple(tenv.Real, Ex.init);
			}
			
			throw error(n.pos, format("incompatible types for %s : %s and %s", n, tl, tr));
		
		case AstTag.CALL:
			Ty tf, tr;  Ty[] ta;
			Ex xf, xr;  Ex[] xa;
			bool isInferredArgs = true;
			
			debug(semant) std.stdio.writefln("call ----");
			foreach (arg ; n.rhs[])
			{
				ta.length += 1;
				xa.length += 1;
				tie[ta[$-1], xa[$-1]] <<= trexp(null, arg);
					// Each type of argumens is always inferred (May be Meta).
				isInferredArgs = isInferredArgs && ta[$-1].isInferred;
			}
			tr = type is null ? tenv.Meta() : type;
			tf = tenv.Arrow(ta, tr);
			tie[tf, xf] <<= trexp(tf, n.lhs);
			debug(semant) std.stdio.writefln("call = fun = %s : %s, args.inferred = %s", xf, tf, isInferredArgs);
			tr = typecheck(tf.returnType);
			if (xf)
			{
				debug(semant)
					foreach (i; 0 .. ta.length)
						std.stdio.writefln(" arg = %s : %s, <== %s", xa[i], ta[i], tf.argumentType(i));
				if (!isInferredArgs)
				{
					foreach (i, arg; n.rhs[])
					{
						if (xa[i] is null)
							tie[ta[i], xa[i]] <<= trexp(tf.argumentType(i), arg);
						debug(semant) std.stdio.writefln(" Arg = %s : %s", xa[i], ta[i]);
					}
				}
				xr = trans.callFun(tf, xf, xa);
				debug(semant) std.stdio.writefln("call tf = %s, isFunction = %s", tf, tf.isFunction);
				debug(semant) std.stdio.writefln("     xf = %s", xf);
				return tuple(tr, xr);
			}
			else
				return tuple(tr, Ex.init);
		
		case AstTag.ASSIGN:
			throw error(n.pos, "*** to do impl ****/assign");
		
		case AstTag.DEF:
			auto id = n.lhs;
			if (n.rhs.tag == AstTag.FUN)
			{
				auto fn = n.rhs;
				auto fn_tenv = new TypEnv(tenv);
				auto fn_venv = new VarEnv(venv);
				
				auto fn_label = newLabel();
				auto fn_level = trans.newLevel(level, fn_label);
				
				Ty[] tp;
				foreach (prm; fn.prm[])
				{
					auto prm_typ = fn_tenv.Meta();
					auto prm_esc = mapVarEsc[prm.sym].escape;
					auto prm_acc = fn_level.allocLocal(prm_typ, true/*prm_esc*/);	// 仮引数は常にFrameに割り当て
					
					tp ~= prm_typ;
					fn_venv.add(prm.sym, prm_acc, prm_typ);
					
					debug(semant) std.stdio.writefln("fun_prm %s : %s", prm.sym, prm_typ);
				}
				
				Ty tr = fn_tenv.Meta();
				Ty tf = fn_tenv.Arrow(tp, tr);
				
				Ty tb;
				Ex xb;
				tie[tb, xb] <<= transExp(fn_level, fn_tenv, fn_venv, tr, fn.blk);
				
				debug(semant) std.stdio.writefln("fun_def body : %s, fun : %s", tb, tf);
				tf = fn_tenv.generalize(tf);
				debug(semant) std.stdio.writefln("fun_def body : %s, fun : %s", tb, tf);
				if (!tf.isInstantiated)
					throw error(n.rhs.pos, "Cannot instantiate polymorphic function yet.");
				
				auto esc = mapVarEsc[id.sym].escape;
				auto acc = level.allocLocal(tf, true);	// 関数値はsize>1wordなのでSlotは常にescapeさせる
				if (!venv.add(id.sym, acc, tf))
					throw error(n.pos, id.toString ~ " is already defined");
				
				debug(semant) std.stdio.writefln("fun_def %s : %s", id.sym, tf);
				
				procEntryExit(fn_level, xb);
				
				auto xf = trans.immediate(fn_level, esc);	// 関数値
				return tuple(tenv.Unit, trans.assign(level, acc, xf));
			}
			else
			{
				Ty ty;
				Ex ex;
				tie[ty, ex] <<= trexp(null, n.rhs);
				if (ty is tenv.Nil)
					throw error(n.pos, "infer error...");
				
				auto esc = mapVarEsc[id.sym].escape;
				if (ty.isFunction) esc = true;	// alocation hack?
				
				//if (used(id) )	// TODO
				//{
					ty = tenv.generalize(ty);
					auto acc = level.allocLocal(ty, esc);
					if (!venv.add(id.sym, acc, ty))
						throw error(n.pos, id.toString ~ " is already defined");
				//}
				//debug(semant) std.stdio.writefln("var_def %s : %s", id.sym, ty);
				
				//初期化式の結果を代入
				return tuple(tenv.Unit, trans.assign(level, acc, ex));
			}
		}
	}
	
	Ty ty;
	Ex ex, x;
	do{
		bool isLast = n.next is null;
		
		tie[ty, x] <<= trexp(isLast ? type : null, n);
		if (x)
		{
			if (isLast)
				x = trans.ret(x);
			debugCodeMap(level, n, x);
			ex = trans.sequence(ex, x);
		}
	}while ((n = n.next) !is null)

	return tuple(ty, ex);
}
+/


void findEscape(AstNode n, uint depth=0)
{
	void traverse(AstNode n, uint depth)
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
			if (auto entry = n.sym in mapVarEsc)
			{
				if (entry.depth < depth)
				{
					entry.escape = true;
					debug(semant) std.stdio.writefln("escaped %s : depth %s < %s", n.sym, entry.depth, depth);
				}
			}
			else
				throw error(n.pos, "undefined identifier " ~ n.sym.name);
			break;
		
		case AstTag.FUN:
			assert(0);		//現状、関数リテラルは許可していないのでここには来ない
		
		case AstTag.ADD:
		case AstTag.SUB:
		case AstTag.MUL:
		case AstTag.DIV:
			traverse(n.lhs, depth);
			traverse(n.rhs, depth);
			break;
		
		case AstTag.CALL:
			traverse(n.lhs, depth);
			foreach (arg ; n.rhs[])
				traverse(arg, depth);
			break;
		
		case AstTag.ASSIGN:
			throw error(n.pos, "*** to do impl ****/assign");
		
		case AstTag.DEF:
			auto id = n.lhs;
			if (n.rhs.tag == AstTag.FUN)
			{
				auto fn = n.rhs;
				
				mapVarEsc[id.sym] = tuple(depth, false);
				foreach (prm; fn.prm[])
					mapVarEsc[prm.sym] = tuple(depth+1, false);
				findEscape(fn.blk, depth+1);
			}
			else
				mapVarEsc[id.sym] = tuple(depth, false);
			break;
		}
	}

	do{
		traverse(n, depth);
		if (n.next is null && n.tag == AstTag.IDENT)
		{
			if (auto entry = n.sym in mapVarEsc)
			{
				entry.escape = true;
				debug(semant) std.stdio.writefln("escaped %s : return depth %s", n.sym, depth);
			}
		}
	}while ((n = n.next) !is null)
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
