module frame;

import sym;
import T = tree;
import std.algorithm, std.string, std.typecons;
import debugs;
private import xtk.format : format;

import assem;

Temp CP;	// Continuation Pointer
Temp FP;	// Frame Pointer
Temp RV;	// Return Value
Temp SP;	// Stack Pointer
Temp NIL;	// Nil Temporary (do not have real memory)
Label ReturnLabel;
void initialize()
{
	sym.initialize();
	
	CP  = newTemp("CP");
	FP  = newTemp("FP");
	SP  = newTemp("SP");
	RV  = newTemp("RV");
	NIL = newTemp("NIL");
}

/**
 * このVirtualMachineにおけるワードサイズ
 */
enum size_t wordSize = 4;


/**
 * VM向けFrame
 */
class Frame
{
private:
	Label namelabel;
	Slot[] slotlist;
	
	this(Label label, bool[] escapes)
	{
		namelabel = label;
		allocLocal(true/*escapes[0]*/);
		allocLocal(true);				// frame  size用のSlotを追加
		formals[1].setSize(1);	// set size of frameSize
		foreach (esc; escapes[1..$])
		{
			allocLocal(true/*esc*/);	// formalsを割り当て	// 引数は常にescape
		}
	}

public:
	/**
	 * このフレームの名前
	 */
	Label name() @property
	{
		return namelabel;
	}
	
	/**
	 * 割り当て済みローカルメモリのリスト
	 */
	Slot[] formals() @property
	{
		return slotlist;
	}
	
	/**
	 * 新しいローカルメモリを確保する
	 * Params:
	 *   escape
	 * Return:
	 *   割り当てたSlotを返す
	 */
	Slot allocLocal(bool escape)
	{
		auto slot = new Slot(this, escape);
		slotlist ~= slot;
		return slot;
	}
	
	/**
	 * フレームレベルでのprologue/epilogueコードを付加する
	 */
	T.Stm procEntryExit1(T.Stm stm)
	{
		return stm;	//todo
	}
	Instr[] procEntryExit2(Instr[] instr)
	{
		assert(0);
	}
	Instr[] procEntryExit3(Instr[] instr)
	{
		T.Stm[] prologue;
		
		size_t frameSize = 0;
		foreach (slot; slotlist)
		{
			prologue ~= T.MOVE(T.VINT(frameSize), T.TEMP(slot.disp));
			frameSize += slot.len;
		}
		
		scope m = new Munch();
		return	m.munch(
					prologue ~
						// FP + frameSize -> SP
					[	T.MOVE(
							T.BIN(T.BinOp.ADD, T.VINT(frameSize), T.TEMP(FP)),
							T.TEMP(SP)),
						// frameSize -> [FP + 1]
						T.MOVE(
							T.VINT(frameSize),
							T.MEM(
								T.BIN(
									T.BinOp.ADD,
									T.TEMP(FP),
									T.VINT(1))))])
				~ instr
				~ Instr.OPE(I.RET(), [], [CP, FP, SP], [ReturnLabel]);
	}
	
	/**
	 * 現在のフレームポインタとSlotから、Slotの右辺値を取るT.Expに変換する
	 */
	T.Exp exp(T.Exp slink, Slot slot)
	{
		T.Exp x;
		
		if (slot.tag == Slot.IN_FRAME)
		{
			auto disp = std.algorithm.countUntil!"a is b"(slotlist, slot);
			assert(disp != -1);
			
			return
				T.MEM(
					T.BIN(
						T.BinOp.ADD,
						slink,
						T.TEMP(slot.disp)));
		}
		else
		{
			return T.TEMP(slot.temp);
		}
	}
}

/**
 * 新しいFrameを生成する
 */
Frame newFrame(Label label, bool[] formals)
{
	return new Frame(label, formals);
}

/**
 * FrameやRegisterに保持された値へのアクセスを表現するクラス
 */
class Slot
{
private:
	enum{ IN_REG, IN_FRAME } int tag;
	union{
		size_t index;			// IN_FRAME: Slotリスト先頭からのindex
		Temp temp;				// IN_REG: 
	}
	Temp disp;	// slotのEP基準でのoffsetを格納、procEntryExit3で値が確定
	size_t len;

	this(Frame fr, bool esc)
	{
		if (esc)
		{
			tag = IN_FRAME;
			index = fr.formals.length;
		}
		else
		{
			tag = IN_REG;
			temp = newTemp();
		}
		disp = newTemp();
	}

public:
	void setSize(size_t n)
	{
		len = n;
	}
}

/**
 *
 */
class Fragment
{
	enum Tag{ PROC, STR };
	Tag tag;
	union{
		Tuple!(T.Stm[], Frame)	p;
		Tuple!(Label, Constant!string)	s;
	}
	this(T.Stm[] body_stm, Frame frame)
	{
		tag = Tag.PROC;
		p = tuple(body_stm, frame);
	}
	this(Label label, Constant!string str)
	{
		tag = Tag.STR;
		s = tuple(label, str);
	}
	
	void debugOut()
	{
		final switch (tag)
		{
		case Tag.PROC:
			foreach (s; p.field[0])
				debugout(s);
			break;
		case Tag.STR:
			return debugout(format("String: %s, %s", s.field[0], s.field[1]));
		}
	}
}
