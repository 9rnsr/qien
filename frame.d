module frame;

static import tree;

import sym, typ;
import std.string, std.typecons;
import debugs;

/**
 * あるコンテキストにおけるフレームポインタを示すテンポラリ
 */
tree.Exp frame_ptr;
static this(){ frame_ptr = tree.TEMP(newTemp("FP")); }

/**
 * あるコンテキストにおける返値設定先を示すテンポラリ(TODO)
 */
tree.Exp return_val;
static this(){ return_val = tree.TEMP(newTemp("RV")); }

/**
 * IR内のプレースホルダとするための無効なテンポラリ
 */
tree.Exp nilTemp;
static this(){ nilTemp = tree.TEMP(newTemp("Nil")); }

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
	
	tree.Stm procEntryExit1(tree.Stm stm)
	{
		return stm;	//todo 本来のprologue/epilogueコードを付加していない
	}
	
	/**
	 * 現在のフレームポインタとSlotから、Slotの右辺値を取るtree.Expに変換する
	 */
	tree.Exp exp(tree.Exp fp, Slot slot)
	{
		auto slot_size = slot.size;
		assert(slot_size > 0);
		
		tree.Exp x;
		
		if (slot.tag == Slot.IN_FRAME)
		{
			if (slot.index > 0)
				return
					tree.MEM(
						tree.BIN(
							tree.BinOp.ADD,
							fp,
							tree.VINT(wordSize * slot.index))
					);
			else
				return tree.MEM(fp);
		}
		else
		{
			return
			//	tree.MEM(
					tree.TEMP(slot.temp)
			//	)
				;
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
		Tuple!(tree.Stm[], Frame)	p;
		Tuple!(Label, Constant!string)	s;
	}
	this(tree.Stm[] body_stm, Frame frame)
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
