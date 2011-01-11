﻿module trans;

import sym, typ, tree;
import frame;		// 実行環境は仮想機械(VM)を使用する
import canon;
import debugs;
import std.algorithm, std.range;


/**
 * 最上位のLevelを表す定義済みオブジェクト
 */
TypEnv outermost_tenv;
Level  outermost;
static this()
{
	outermost_tenv = new TypEnv();
	outermost = newLevel(null, newLabel("__toplevel"));
	outermost.frame.procEntry();
}


/**
 * ネストした関数スコープを表すオブジェクト
 */
class Level
{
private:
	Level		parent;
	Frame		frame;
	Access[]	acclist;

	this(Level p, Frame f)
	{
		parent = p;
		frame = f;
	}

public:
	/**
	 * 割り当て済みローカル変数のリスト
	 */
	Access[] formals() @property
	{
		return acclist;
	}

	/**
	 * 新しいローカル変数を割り当てる
	 * Params:
	 *   escape
	 * Return:
	 *   割り当てたAccessを返す
	 */
	Access allocLocal(Ty ty, bool escape)
	{
		auto acc = new Access(this, frame.allocLocal(ty, escape));
		acclist ~= acc;
		return acc;
	}
}

/// 
Level newLevel(Level parent, Label name/*, bool[] formals*/)
{
	auto frame = newFrame(name/*, true ~ formals*/);
	frame.allocLocal(outermost_tenv.Int, true);		// static link用のSlotを追加
	frame.allocLocal(outermost_tenv.Int, true);		// frame  size用のSlotを追加
	return new Level(parent, frame);
}

/**
 * ネストした関数スコープにおける変数を表すオブジェクト
 */
class Access
{
private:
	Level	level;
	Slot	slot;

	this(Level lv, Slot sl)
	{
		level = lv;
		slot  = sl;
	}
}

void procEntry(Level level)
{
	level.frame.procEntry();
}

/**
 * 
 */
void procEntryExit(Level level, Ex bodyexp)
{
	auto ex = level.frame.procEntryExit1(unNx(bodyexp));
	
	auto lx = linearize(ex);
	frag ~= new Fragment(lx, level.frame);
}

/**
 * 
 */
static Fragment[] frag;

/**
 * 
 */
Retro!(Fragment[]) getResult()
{
	return retro(frag);
}

/**
 * Translateによる処理の結果として生成されるIR
 */
class Ex
{
	alias Stm delegate(Label t, Label f) GenCx;
	
private:
	enum Tag{ EX, NX, CX }
	Tag tag;
	union{
		Exp ex;
		Stm nx;
		GenCx cx;
	}

	this(Exp exp)	{ tag = Tag.EX; ex = exp; }
	this(Stm stm)	{ tag = Tag.NX; nx = stm; }
	this(GenCx cnd)	{ tag = Tag.CX; cx = cnd; }

public:
	void debugOut(TreeOut tout)
	{
		final switch (tag)
		{
		case Tag.EX:	return ex.debugOut(tout);
		case Tag.NX:	return nx.debugOut(tout);
		case Tag.CX:	return ;	//todo
		}
	}
	
	string toString()
	{
		final switch (tag)
		{
		case Tag.EX:	return ex.toString;
		case Tag.NX:	return nx.toString;
		case Tag.CX:	return "Cx";	//todo
		}
	}
}

/**
 * 整数値を即値IRに変換する
 */
Ex immediate(IntT v)
{
	return new Ex(VINT(v));
}
/**
 * 実数値を即値IRに変換する
 */
Ex immediate(RealT v)
{
	assert(0);
	return null;
	//return new Ex(VREAL(v));
}

/**
 * 変数値を取り出すIRに変換する
 */
Ex getVar(Level level, Access access)
{
	auto slink = frame_ptr;
//	debugout("* %s", slink);
	while (level !is access.level)
	{
		slink = level.frame.exp(slink, level.frame.formals[frame.static_link_index]);	//静的リンクを取り出す
		level = level.parent;
//		debugout("* %s", slink);
	}
	return new Ex(level.frame.exp(slink, access.slot));
}

/**
 * 関数値を取り出すIRに変換する
 */
Ex getFun(Level level, Level bodylevel, Label label)
{
	auto funlevel = bodylevel.parent;
	auto slink = frame_ptr;
	while (level !is funlevel)
	{
		slink = level.frame.exp(slink, level.frame.formals[frame.static_link_index]);	//静的リンクを取り出す
		level = level.parent;
	}
	return new Ex(VFUN(slink, label));
}

/**
 * 関数呼び出しのIRに変換する
 */
Ex callFun(Ex fun, Ex[] args)
{
	return new Ex(CALL(unEx(fun), array(map!unEx(args))));
}

/**
 * 二項加算のIRに変換する
 */
Ex binAddInt(Ex lhs, Ex rhs)
{
	return new Ex(BIN(BinOp.ADD, unEx(lhs), unEx(rhs)));
}

/**
 * 二項減算のIRに変換する
 */
Ex binSubInt(Ex lhs, Ex rhs)
{
	return new Ex(BIN(BinOp.SUB, unEx(lhs), unEx(rhs)));
}

/**
 * 二項乗算のIRに変換する
 */
Ex binMulInt(Ex lhs, Ex rhs)
{
	return new Ex(BIN(BinOp.MUL, unEx(lhs), unEx(rhs)));
}

/**
 * 二項除算のIRに変換する
 */
Ex binDivInt(Ex lhs, Ex rhs)
{
	return new Ex(BIN(BinOp.DIV, unEx(lhs), unEx(rhs)));
}

/**
 * 二項加算のIRに変換する
 */
Ex sequence(Ex s1, Ex s2)
{
	if (s1)
		return new Ex(SEQ([unNx(s1), unNx(s2)]));
	else
		return s2;
}

Ex ret(Ex x)
{
	return new Ex(MOVE(unEx(x), return_val));
}

/**
 * Params:
 *   level:		関数が定義されるレベル
 *   bodylevel:	関数本体のレベル
 *   label:		関数本体のラベル
 */
Ex makeFunction(Level level, Level bodylevel, Label label)
{
	return new Ex(
		VFUN(frame_ptr, label));	// 現在のframe_ptrと関数本体のラベルの組＝関数値
}

/**
 * Params:
 *   level:		クロージャが定義されるレベル
 *   bodylevel:	クロージャ本体のレベル
 *   label:		クロージャ本体のラベル
 */
Ex makeClosure(Level level, Level bodylevel, Label label)
{
	return new Ex(ESEQ(
		CLOS(label),				// クロージャ命令(escapeするFrameをHeapにコピーし、env_ptr==frame_ptrをすり替える)
		VFUN(frame_ptr, label)));	// 現在のframe_ptrとクロージャ本体のラベルの組＝クロージャ値
}

/**
 * 代入操作のIRに変換する
 */
Ex assign(Level level, Access access, Ex value)
{
	auto slink = frame_ptr;
	while (level !is access.level)
	{
		slink = level.frame.exp(slink, level.frame.formals[frame.static_link_index]);	//静的リンクを取り出す
		level = level.parent;
	}
	return new Ex(MOVE(unEx(value), level.frame.exp(slink, access.slot)));
}

Exp unEx(Ex exp)
{
	final switch (exp.tag)
	{
	case Ex.Tag.EX:
		return exp.ex;
	case Ex.Tag.NX:
		return ESEQ(exp.nx, VINT(0));	//文は式として0を返す
	case Ex.Tag.CX:
		auto r = newTemp();
		auto t = newLabel(), f = newLabel();
		return ESEQ(
			SEQ([
				MOVE(VINT(1), TEMP(r)),
				exp.cx(t, f),
				LABEL(f),
				MOVE(VINT(0), TEMP(r)),
				LABEL(t)
			]),
			TEMP(r)
		);
	}
	return null;
}

Stm unNx(Ex exp)
{
	final switch (exp.tag)
	{
	case Ex.Tag.EX:
		return MOVE(exp.ex, nilTemp);
	case Ex.Tag.NX:
		return exp.nx;
	case Ex.Tag.CX:
		auto l = newLabel();
		return SEQ([exp.cx(l, l), LABEL(l)]);
	}
}

Stm delegate(Label, Label) unCx(Ex exp)
{
	final switch (exp.tag)
	{
	case Ex.Tag.EX:
		auto x = exp.ex;
		return delegate(Label t, Label f){
			assert(0);
			return Stm.init;	//todo
		};
	case Ex.Tag.NX:
		return delegate(Label t, Label f){
			assert(0);
			return Stm.init;	//todo
		};
	case Ex.Tag.CX:
		return exp.cx;
	}
}

