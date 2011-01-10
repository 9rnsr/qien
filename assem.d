import tree;
import sym;
import frame;
import typecons.match;
import std.conv, std.string, std.stdio;
import std.metastrings;
import debugs;

import machine;

//debug = munch;

/+
class Instruction
{
	mixin TagUnion!(
		"OPE",	string, Temp[], Temp[], Label[],
		"LBL",	string, Label,
		"MOV",	Temp, Temp
	);
	string toString()
	{
		final switch (tag)
		{
		case Tag.OPE:	""
		}
	}
}
alias Instruction I;
+/
alias Instruction I;

class Munch
{
	Instruction[] munch(Stm[] stms)
	{
		code = [];
		
		foreach (s; stms)
			munchStm(s);
		
		return code;
	}

private:
	Instruction[] code;

	void emit(Instruction instr)
	{
		//writefln("emit : %s", instr);
		code ~= instr;
	}

	Temp munchExp(tree.Exp exp)
	{
		Temp		t;
		Label		l;
		tree.Exp	e, e1, e2;
		long		n;
		BinOp		binop;
		
		static Temp result(void delegate(Temp) gen)
		{
			auto t = newTemp();
			gen(t);
			return t;
		}
		
		debug(munch) writefln("* munchExp : exp =");
		debug(munch) debugout(exp);
		return match(exp,
			VINT[&n],{
				debug(munch) debugout("munchExp : VINT[&n]");
				return result((Temp r){ emit(I.LDI(n, r)); });
			},
			TEMP[&t],{
				debug(munch) debugout("munchExp : TEMP[&t]");
				return t;
			},
			BIN[&binop, &e1, &e2],{
				debug(munch) debugout("munchExp : BIN[&binop, &e1, &e2]");
				switch (binop)
				{
				case BinOp.ADD:	return result((Temp r){ emit(I.ADD(munchExp(e1), munchExp(e2), r)); });
				case BinOp.SUB:	return result((Temp r){ emit(I.SUB(munchExp(e1), munchExp(e2), r)); });
				case BinOp.MUL:	return result((Temp r){ emit(I.MUL(munchExp(e1), munchExp(e2), r)); });
				case BinOp.DIV:	return result((Temp r){ emit(I.DIV(munchExp(e1), munchExp(e2), r)); });
				default:		assert(0);
				}
			},

		//	MEM[TEMP[&t]],{
		//		debug(munch) debugout("munchExp : MEM[TEMP[&t]]");
		//		return t;
		//	},
		//	MEM[&e],{
		//		debug(munch) debugout("munchExp : MEM[&e]");
		//		return result((Temp r){ ; });
		//	},
		//	TEMP[&t],{
		//		debug(munch) debugout("munchExp : TEMP[&t]");
		//		return t;
		//	},
		//	VFUN[&e, &l],{
		//		debug(munch) debugout("munchExp : VFUN[&e, &l]");
		//		assert(0);
		//		return result((Temp r){ emit(I.LDI(n, r)); });
		//	},
			_,{
				writef("munchExp : _ = "), debugout(exp);
				assert(0);
				return result((Temp r){ ; });
			}
		);
	}

	void munchStm(tree.Stm stm)
	{
		long		n, disp;
		Temp		t;
		tree.Exp	e, e1 ,e2;
		Label		l;
		
		debug(munch) writefln("* munchStm : stm = ");
		debug(munch) debugout(stm);
		match(stm,
			MOVE[&e, TEMP[&t]],{
				debug(munch) debugout("munchStm : MOVE[&e, TEMP[&t]]");
				if (TEMP[t] <<= nilTemp)
					munchExp(e);
				else
					if (VINT[&n] <<= e)
						emit(I.LDI(n, t));
					else
					{
						auto t1 = munchExp(e);
						emit(I.MOV(t1, t));
					}
			},

		//	MOVE[&e1, MEM[frame_ptr]],{
		//		debug(munch) debugout("munchStm : MOVE[&e1, MEM[frame_ptr]]");
		//		emit(I.STB(munchExp(e1), 0));
		//	},
		//	MOVE[&e1, MEM[&e2]],{
		//		debug(munch) debugout("munchStm : MOVE[&e1, MEM[&e2]]");
		//		auto t1 = munchExp(e1);
		//		auto t2 = munchExp(e2);
		//		emit(I.LDI(t1, t));
		//	},

		//	MOVE[e, BIN[BinOp.ADD, MEM[frame_ptr], VINT[&disp]]],{
		//		debug(munch) debugout("munchStm : MOVE[e, BIN[BinOp.ADD, MEM[frame_ptr], VINT[&disp]]]");
		//		emit(I.STB(munchExp(e), cast(int)disp));
		//	},
		//	MOVE[e, MEM[frame_ptr]],{
		//		debug(munch) debugout("munchStm : MOVE[e, MEM[frame_ptr]]");
		//		emit(I.STB(munchExp(e), cast(int)0));
		//	},
		//	MOVE[VINT[&n], MEM[TEMP[&t]]],{
		//		debug(munch) debugout("munchStm : MOVE[VINT[&n], MEM[TEMP[&t]]]");
		//		emit(I.LDI(n, t));
		//	},
		//	MOVE[VINT[&n], &e],{
		//		debug(munch) debugout("munchStm : MOVE[VINT[&n], &e]");
		//		emit(I.LDI(n, munchExp(e)));
		//		assert(0);
		//	},
		//	MOVE[VFUN[frame_ptr, &l], MEM[frame_ptr]],{
		//		debug(munch) debugout("munchStm : MOVE[VFUN[&TEMP[frame_ptr], &l], MEM[TEMP[&t]]]");
		//		
		//		I.MOV
		//		
		//		emit(I.MOV2I(n, t));
		//	},
		//	MOVE[VFUN[frame_ptr, &l], MEM[BIN[BinOp.ADD, frame_ptr, &n]]],{
		//	},
		//	MOVE[&e1, &e2],{
		//		debug(munch) debugout("munchStm : MOVE[&e1, &e2]");
		//		auto t1 = munchExp(e1);
		//		auto t2 = munchExp(e2);
		//		emit(I.MOV(t1, t2));
		//	},
		//	MOVE[&t, &e],{
		//		debug(munch) debugout("munchStm : MOVE[&t, &e]");
		//		emit(I.MOV(t, munchExp(e)));
		//	},
			_,{
				assert(0);
			}
		);
	}
}

/+
/**
 *
 */
class Fragment
{
	enum Tag{ PROC, STR };
	Tag tag;
	union{
		Tuple!(Instruction[])		p;
		Tuple!(Label, Constant!string)	s;
	}
	this(Instruction[] instr)
	{
		tag = Tag.PROC;
		p = tuple(instr);
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
			foreach (instr; p.field[0])
				writefln("%s", instr);
			break;
		case Tag.STR:
			return debugout(format("String: %s, %s", s.field[0], s.field[1]));
		}
	}
}
+/