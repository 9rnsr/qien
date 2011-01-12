module frame;

import sym, typ;
import T = tree;
import std.string, std.typecons;
import debugs;

import assem;

Temp CP;
Temp FP;		/// あるコンテキストにおけるフレームポインタを示すテンポラリ
Temp RV;		/// あるコンテキストにおける返値設定先を示すテンポラリ(TODO)
Temp SP;		/// 
Temp NIL;		/// IR内のプレースホルダとするための無効なテンポラリ
Label ReturnLabel;
static this()
{
	CP  = newTemp("CP");
	FP  = newTemp("FP");
	RV  = newTemp("RV");
	SP  = newTemp("SP");
	NIL = newTemp("NIL");
}

/**
 * このVirtualMachineにおけるワードサイズ
 */
enum size_t wordSize = 4;

/**
 * Frame.formals内、静的Linkがあるインデックス
 */
enum size_t static_link_index = 0;

/**
 * VM向けFrame
 */
class Frame
{
private:
	Label namelabel;
	Slot[] slotlist;
	size_t local_start;
	
	this(Label label/*, bool[] escapes*/)
	{
		namelabel = label;
	//	foreach (esc; escapes)
	//		allocLocal(esc);		//formalsを割り当て
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
	Slot allocLocal(Ty ty, bool escape)
	{
		auto slot = new Slot(this, ty, escape);
		slotlist ~= slot;
		return slot;
	}
	
	void procEntry()
	{
		local_start = slotlist.length;
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
		size_t frameSize = 0;
		size_t localSize = 0;
		foreach (i,slot; slotlist)
		{
			frameSize += slot.size;
			if (i >= local_start && slot.tag == Slot.IN_FRAME)
				localSize += slot.size;
		}
		
		scope m = new Munch();
		return	Instr.OPE(I.ENTER(localSize), null, [SP], null)
				~ m.munch([
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
		auto slot_size = slot.size;
		assert(slot_size > 0);
		
		T.Exp x;
		
		if (slot.tag == Slot.IN_FRAME)
		{
			size_t disp = 0;
			foreach (s; slotlist)
			{
				if (s is slot) break;
				disp += s.size;
			}
			
			return
				T.MEM(
					T.BIN(
						T.BinOp.ADD,
						slink,
						T.VINT(disp)));
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
Frame newFrame(Label label/*, bool[] formals*/)
{
	return new Frame(label/*, formals*/);
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
 * FrameやRegisterに保持された値へのアクセスを表現するクラス
 */
class Slot
{
private:
	Ty type;
	enum{ IN_REG, IN_FRAME } int tag;
	union{
		size_t index;			// IN_FRAME: Slotリスト先頭からのindex
		Temp temp;				// IN_REG: 
	}
	size_t len;

	this(Frame fr, Ty ty, bool esc)
	{
		type = ty;
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
	}

	size_t size() @property
	{
		if (len == 0)
			len = .getTypeSize(type);
		
		if (tag == IN_REG)
			assert(len == 1);
		
		return len;
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
