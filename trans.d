module trans;

import sym, typ;
import canon;
import frame;
import T = tree;
import std.algorithm, std.range;
import xtk.match;
import debugs;


/**
 * 
 */

void initialize()
{
	frame.initialize();
}


/**
 * ネストした関数スコープを表すオブジェクト
 */
class Level
{
private:
	Level		parent;
	Frame		frame;
		// Future: 仮引数用frameと、bodyのローカル変数用frameを分ける？
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
	 *   xv		= 初期値のIR(SlotSizeを確定するために必要)
	 *   escape	= 束縛がエスケープするかどうか
	 * Return:
	 *   割り当てたAccessを返す
	 */
	Access allocLocal(Ty type, bool escape)
	{
		auto acc = new Access(this, type, escape);
		acclist ~= acc;
		return acc;
	}
}

/// 
Level newLevel(Level parent, Label name)
{
	auto frame = newFrame(name, [true]);	// static link用のSlotを追加
	return new Level(parent, frame);
}

/**
 * ネストした関数スコープにおける変数を表すオブジェクト
 */
class Access
{
private:
	Level	level;
	Ty		type;
	bool	escape;
	Slot[]	slotlist;		// 1Slot == 1word前提で考える

	this(Level lv, Ty ty, bool esc)
	{
		level = lv;
		type = ty;
	//	slotlist  = sl;		// スロットの確保は型推論後
		escape = esc;
	}

	Slot[] slots()
	{
		if (slotlist.length == 0)
		{
			// スロットが必要＝Tree作成段階にある＝型推論済み
			auto size = getTypeSize(type);
			
			//std.stdio.writefln("Access.slots : size = %s, escape = %s", size, escape);
			
			//if (size >= 2) escape = true;	// 関数値はsize>1wordなのでSlotは常にescapeさせる
			
			// 複数ワードの値は必ずフレーム上に配置する
			assert(size == 1 || (size >= 2 && escape));
			
			foreach (_; 0 .. size)
				slotlist ~= level.frame.allocLocal(escape);
		}
		return slotlist;
	}
public:
	size_t size()
	{
		return slots.length;
	}
}

/**
 * 
 */
Fragment procEntryExit(Level level, Ex bodyexp)
{
	auto ex = level.frame.procEntryExit1(unNx(bodyexp));
	
	auto lx = linearize(ex);
	return new Fragment(lx, level.frame);
}


private size_t getTypeSize(Ty type)
{
	assert(type.isInferred);
	return type.isFunction ? 2 : 1;
}


/**
 * Translateによる処理の結果として生成されるIR
 */
class Ex
{
	alias T.Stm delegate(Label t, Label f) GenCx;
	
private:
	enum Tag{ EX, NX, CX }
	Tag tag;
	union{
		T.Exp ex;
		T.Stm nx;
		GenCx cx;
	}

	this(T.Exp exp)	{ tag = Tag.EX; ex = exp; }
	this(T.Stm stm)	{ tag = Tag.NX; nx = stm; }
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
	return new Ex(T.FIXN(v));
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
 * 関数値を即値IRに変換する
 * Params:
 *   fn_level	= 関数本体が定義されているLevel
 *   escape		= 関数値がescapeするかどうか
 */
Ex immediate(Level fn_level, bool escape)
{
	return new Ex(
		T.FUNC(fn_level.frame.name, escape));	// 関数本体のラベル+escapeの組＝関数値
}

/**
 * 変数値(整数、浮動小数点、関数値)を取り出すIRに変換する
 */
Ex variable(Level level, Access access)
{
	auto slink = T.TEMP(FP);
//	debugout("* %s", slink);
	while (level !is access.level)
	{
		slink = level.frame.exp(slink, level.frame.formals[0]);	//静的リンクを取り出す
		level = level.parent;
//		debugout("* %s", slink);
	}
	debug(trans) std.stdio.writefln("trans.variable slink = %s, access.slots[0] = %s, access.size = %s", slink, access.slots[0], access.size);
	return new Ex(level.frame.exp(slink, access.slots[0], access.size));
}

/**
 * 関数呼び出しのIRに変換する
 */
Ex callFun(Ty tyfun, Ex fun, Ex[] args)
in { assert(tyfun.isFunction); }
body
{
	auto size = getTypeSize(tyfun.returnType);
	if (size >= 2)
		return new Ex(T.MEM(T.CALL(unEx(fun), array(map!unEx(args))), size));
	else
		return new Ex(T.CALL(unEx(fun), array(map!unEx(args))));
}

/**
 * 二項加算のIRに変換する
 */
Ex binAddInt(Ex lhs, Ex rhs)
{
	return new Ex(T.BIN(T.BinOp.ADD, unEx(lhs), unEx(rhs)));
}

/**
 * 二項減算のIRに変換する
 */
Ex binSubInt(Ex lhs, Ex rhs)
{
	return new Ex(T.BIN(T.BinOp.SUB, unEx(lhs), unEx(rhs)));
}

/**
 * 二項乗算のIRに変換する
 */
Ex binMulInt(Ex lhs, Ex rhs)
{
	return new Ex(T.BIN(T.BinOp.MUL, unEx(lhs), unEx(rhs)));
}

/**
 * 二項除算のIRに変換する
 */
Ex binDivInt(Ex lhs, Ex rhs)
{
	return new Ex(T.BIN(T.BinOp.DIV, unEx(lhs), unEx(rhs)));
}

/**
 * 
 */
Ex sequence(Ex s1, Ex s2)
{
	if (s1)
		return new Ex(T.SEQ([unNx(s1), unNx(s2)]));
	else
		return s2;
}

/**
 * 
 */
Ex ret(Ex value)
{
	auto ex = unEx(value);
	size_t size;
	size = 
		match(	ex,
				T.FUNC[$],		{ return 2u;   },
				T.MEM[_, &size],{ return size; },
				_,				{ return 1u;   }	);
	
	if (size >= 2)
	{
		return new Ex(T.MOVE(ex, T.MEM(T.TEMP(RV), size)));
	}
	else
		return new Ex(T.MOVE(ex, T.TEMP(RV)));
}

/**
 * 代入操作のIRに変換する
 */
Ex assign(Level level, Access access, Ex value)
{
	auto slink = T.TEMP(FP);
	while (level !is access.level)
	{
		slink = level.frame.exp(slink, level.frame.formals[0]);	//静的リンクを取り出す
		level = level.parent;
	}
	return new Ex(T.MOVE(unEx(value), level.frame.exp(slink, access.slots[0], access.size)));
}

T.Exp unEx(Ex exp)
{
	final switch (exp.tag)
	{
	case Ex.Tag.EX:
		return exp.ex;
	case Ex.Tag.NX:
		return T.ESEQ(exp.nx, T.FIXN(0));	//文は式として0を返す
	case Ex.Tag.CX:
		auto r = newTemp();
		auto t = newLabel(), f = newLabel();
		return T.ESEQ(
			T.SEQ([
				T.MOVE(T.FIXN(1), T.TEMP(r)),
				exp.cx(t, f),
				T.LABEL(f),
				T.MOVE(T.FIXN(0), T.TEMP(r)),
				T.LABEL(t)
			]),
			T.TEMP(r)
		);
	}
	return null;
}

T.Stm unNx(Ex exp)
{
	final switch (exp.tag)
	{
	case Ex.Tag.EX:
		return T.MOVE(exp.ex, T.TEMP(NIL));
	case Ex.Tag.NX:
		return exp.nx;
	case Ex.Tag.CX:
		auto l = newLabel();
		return T.SEQ([exp.cx(l, l), T.LABEL(l)]);
	}
}

T.Stm delegate(Label, Label) unCx(Ex exp)
{
	final switch (exp.tag)
	{
	case Ex.Tag.EX:
		auto x = exp.ex;
		return delegate(Label t, Label f){
			assert(0);
			return T.Stm.init;	//todo
		};
	case Ex.Tag.NX:
		return delegate(Label t, Label f){
			assert(0);
			return T.Stm.init;	//todo
		};
	case Ex.Tag.CX:
		return exp.cx;
	}
}

