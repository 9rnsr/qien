module semant;

import parse, typ;
import trans;
import frame : Fragment;
import debugs;
import xtk.format : format;
import xtk.match;
import std.algorithm, std.array, std.exception, std.typecons;

//debug = semant;

/// 
Fragment[] transProg(AstNode n)
{
	Fragment[] frag;
	trans.initialize(frag);
	
	auto tenv = new TypEnv();
	auto venv = new VarEnv();
	
	// 最上位のLevelを表す定義済みオブジェクト
	auto outermost = newLevel(null, newLabel("__toplevel"));

	findEscape(n);

	Ty ty = transTyp(outermost, tenv, venv, null, n);
	std.stdio.writefln("transProg : %s", ty);

	outermost.procEntry();	// グローバルな変数定義を行う、現状では何もなし
	Ex ex = transExp(outermost, tenv, venv, n);
	outermost.procExit(ex);
	
	return frag.reverse;
}

/// 
Throwable error(FilePos pos, string msg)
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

private
{
	Tuple!(uint, "depth", bool, "escape")[Symbol] mapVarEsc;
	
	AstNode[][Symbol] mapVarVal;
	bool[AstNode] mapValEsc;	// 現状、関数値のみ登録している
	
	Tuple!(Level, "level", TypEnv, "tenv", VarEnv, "venv")[AstNode] fun_map;
	Ty[AstNode] callNodeType;
}

void findEscape(AstNode n, uint depth=0)
{
	void traverse(AstNode n, uint depth)
	{
		final switch (n.tag)
		{
		case AstTag.NOP:	assert(0);	//型検査の対象とならないdummy nodeなのでここに来るのはerror
		
		case AstTag.INT:
		case AstTag.REAL:
		case AstTag.STR:	break;
		
		case AstTag.IDENT:
			auto entry = enforce(n.sym in mapVarEsc, error(n.pos, "undefined identifier " ~ n.sym.name));
			if (entry.depth < depth)
				entry.escape = true;
			debug(semant) if (entry.escape) std.stdio.writefln("escaped %s : depth %s < %s", n.sym, entry.depth, depth);
			break;
		
		case AstTag.FUN:
			foreach (prm; n.prm[])
				mapVarEsc[prm.sym] = tuple(depth+1, false);
			findEscape(n.blk, depth+1);
			break;
		
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
			auto val = n.rhs;
			
			traverse(val, depth);
			
			mapVarVal[id.sym] = [val];
			mapVarEsc[id.sym] = tuple(depth, false);
			break;
		}
	}

	do{
		traverse(n, depth);
		if (n.next is null && n.tag == AstTag.IDENT)
		{
			if (auto values = n.sym in mapVarVal)
			{
				foreach (val; *values)
					mapValEsc[val] = true;
				debug(semant) std.stdio.writefln("escaped %s : return depth %s", n.sym, depth);
			}
		}
	}while ((n = n.next) !is null)
}

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
		case AstTag.NOP:	assert(0);	//型検査の対象とならないdummy nodeなのでここに来るのはerror
		
		case AstTag.INT:	return typecheck(tenv.Int);
		case AstTag.REAL:	return typecheck(tenv.Real);
		case AstTag.STR:	return typecheck(tenv.Str);
		case AstTag.IDENT:
			auto entry = enforce((n.sym in venv), error(n.pos, n.sym.name ~ " undefined"));
			auto ty = typecheck(tenv.instantiate(entry.ty));
			debug(semant) std.stdio.writefln("ident %s : %s (instantiated = %s)", n.sym, ty, ty.isInstantiated);
			return ty;
		
		case AstTag.FUN:
			auto fn_level = trans.newLevel(level, newLabel());
			auto fn_tenv  = new TypEnv(tenv);
			auto fn_venv  = new VarEnv(venv);
			
			fun_map[n] = tuple(fn_level, fn_tenv, fn_venv);
			
			Ty[] tp;
			foreach (prm; n.prm[])
			{
				auto prm_typ = fn_tenv.Meta();
				auto prm_esc = mapVarEsc[prm.sym].escape;
				auto prm_acc = fn_level.allocLocal(prm_typ, true/*prm_esc*/);	// 仮引数は常にFrameに割り当て
				
				tp ~= prm_typ;
				fn_venv.add(prm.sym, prm_acc, prm_typ);
				
				debug(semant) std.stdio.writefln("prm %s : %s", prm.sym, prm_typ);
			}
			
			Ty tr = fn_tenv.Meta();
			Ty tf = fn_tenv.Arrow(tp, tr);
			Ty tb = transTyp(fn_level, fn_tenv, fn_venv, tr, n.blk);
			
			debug(semant) std.stdio.writefln("fun : %s", tb);
			tf = fn_tenv.generalize(tf);
			debug(semant) std.stdio.writefln("fun : %s", tb);
			if (!tf.isInstantiated)
				throw error(n.rhs.pos, "Cannot instantiate polymorphic function yet.");
			
			return typecheck(tf);
		
		// FUTURE: built-in function CALLに統一
		case AstTag.ADD:
		case AstTag.SUB:
		case AstTag.MUL:
		case AstTag.DIV:
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
			callNodeType[n] = tr;	// save
			return tr;
		
		case AstTag.ASSIGN:
			throw error(n.pos, "*** to do impl ****/assign");
		
		case AstTag.DEF:
			auto id = n.lhs;
			auto tv = trtyp(null, n.rhs);
			
			// TODO: 束縛の定義が値のtraverseの後なので、関数値の場合再帰ができない問題がある
			auto esc = mapVarEsc[id.sym].escape;
			auto acc = level.allocLocal(tv, esc);
			enforce(venv.add(id.sym, acc, tv), error(n.pos, id.toString ~ " is already defined"));
			
			debug(semant) std.stdio.writefln("def %s : %s", id.sym, tv);
			return typecheck(tenv.Unit);
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
		case AstTag.NOP:	assert(0);	//型検査の対象とならないdummy nodeなのでここに来るのはerror
		
		case AstTag.INT:	return trans.immediate(n.i);
		case AstTag.REAL:	return trans.immediate(n.r);
		case AstTag.STR:	return Ex.init;
		case AstTag.IDENT:	return trans.variable(level, (n.sym in venv).access);
		
		case AstTag.FUN:
			auto fn = fun_map[n];	// transTyでfnに関連付けておいて、ここで取り出す
			
			fn.level.procEntry();	// 仮引数のSlotを確保させる
			Ex xb = transExp(fn.level, fn.tenv, fn.venv, n.blk);
			fn.level.procExit(xb);
			
			auto esc = (n in mapValEsc) !is null;
			return trans.immediate(fn.level, esc);
		
		// FUTURE: built-in function CALLに統一
		case AstTag.ADD:	return trans.binAddInt(trexp(n.lhs), trexp(n.rhs));
		case AstTag.SUB:	return trans.binSubInt(trexp(n.lhs), trexp(n.rhs));
		case AstTag.MUL:	return trans.binMulInt(trexp(n.lhs), trexp(n.rhs));
		case AstTag.DIV:	return trans.binDivInt(trexp(n.lhs), trexp(n.rhs));
		
		case AstTag.CALL:
			debug(semant) std.stdio.writefln("call ----");
			auto tr = *(n in callNodeType);
			auto xa = array(map!trexp(n.rhs[]));
			auto xf = trexp(n.lhs);
			debug(semant) std.stdio.writefln("call fun = %s : %s", xf, tr);
			auto xr = trans.callFun(tr, xf, xa);
			return xr;
		
		case AstTag.ASSIGN:
			assert(0);
		
		case AstTag.DEF:
			auto id = n.lhs;
			auto acc = trans.define((id.sym in venv).access);
			return trans.assign(level, acc, trexp(n.rhs));
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
