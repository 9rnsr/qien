module trans;

import sym, typ;
import canon;
import frame;
import T = tree;
import std.algorithm, std.range;
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
	Access allocLocal(Ex xv, bool escape)
	{
		auto acc = new Access(this, frame.allocLocal(escape));
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
	Slot	slot;

	this(Level lv, Slot sl)
	{
		level = lv;
		slot  = sl;
	}

public:
	void setSize(Ty ty)
	{
		slot.setSize(getTypeSize(ty));
	}
}

size_t getTypeSize(Ty ty)
{
	assert(ty.isInferred);
	if (ty.isFunction)
		return 2;
	else
		return 1;
}

/**
 * 
 */
Fragment procEntryExit(Level level, Ex bodyexp)
{
	level.frame.formals[0].setSize(1);	// set size of slink
	
	auto ex = level.frame.procEntryExit1(unNx(bodyexp));
	
	auto lx = linearize(ex);
	return new Fragment(lx, level.frame);
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
	return new Ex(T.VINT(v));
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
	auto fn_label = fn_level.frame.name;
	
	if (escape)
		return new Ex(T.ESEQ(
			T.CLOS(fn_label),				// クロージャ命令(escapeするFrameをHeapにコピーし、env_ptr==FPをすり替える)
			T.VFUN(T.TEMP(FP), fn_label)));	// 現在のFPとクロージャ本体のラベルの組＝クロージャ値
	else
		return new Ex(
			T.VFUN(T.TEMP(FP), fn_label));	// 現在のFPと関数本体のラベルの組＝関数値
}

/**
 * 変数値(整数、浮動小数点、関数値)を取り出すIRに変換する
 */
Ex getVar(Level level, Access access)
{
	auto slink = T.TEMP(FP);
//	debugout("* %s", slink);
	while (level !is access.level)
	{
		slink = level.frame.exp(slink, level.frame.formals[0]);	//静的リンクを取り出す
		level = level.parent;
//		debugout("* %s", slink);
	}
	return new Ex(level.frame.exp(slink, access.slot));
}

/**
 * 関数呼び出しのIRに変換する
 */
Ex callFun(Ex fun, Ex[] args)
{
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
 * 二項加算のIRに変換する
 */
Ex sequence(Ex s1, Ex s2)
{
	if (s1)
		return new Ex(T.SEQ([unNx(s1), unNx(s2)]));
	else
		return s2;
}

Ex ret(Ex x)
{
	return new Ex(T.MOVE(unEx(x), T.TEMP(RV)));
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
	return new Ex(T.MOVE(unEx(value), level.frame.exp(slink, access.slot)));
}

T.Exp unEx(Ex exp)
{
	final switch (exp.tag)
	{
	case Ex.Tag.EX:
		return exp.ex;
	case Ex.Tag.NX:
		return T.ESEQ(exp.nx, T.VINT(0));	//文は式として0を返す
	case Ex.Tag.CX:
		auto r = newTemp();
		auto t = newLabel(), f = newLabel();
		return T.ESEQ(
			T.SEQ([
				T.MOVE(T.VINT(1), T.TEMP(r)),
				exp.cx(t, f),
				T.LABEL(f),
				T.MOVE(T.VINT(0), T.TEMP(r)),
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

