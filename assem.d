module assem;

import sym;
import frame;
import T = tree;
import typecons.match, typecons.tagunion;
import std.conv, std.string, std.stdio;
import std.metastrings;
import debugs;

public import machine;
alias machine.Instruction I;

//debug = munch;

class Instr
{
	mixin TagUnion!(
		"OPE",	machine.Instruction, Temp[], Temp[], Label[],
		"LBL",	machine.Instruction, Label,
		"MOV",	machine.Instruction, Temp, Temp
	);
	string toString()
	{
		final switch (tag)
		{
		case Tag.OPE:	return "OPE";
		case Tag.LBL:	return "LBL";
		case Tag.MOV:	return "MOV";
		}
	}
}

class Munch
{
	Instruction[] munch(T.Stm[] stms)
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
		//debugout("emit : %s", instr);
		code ~= instr;
	}

	Temp result(void delegate(Temp) gen)
	{
		auto t = newTemp();
		gen(t);
		return t;
	}

	Temp munchExp(T.Exp exp)
	{
		Temp	t;
		Label	l;
		T.Exp	e, e1, e2;
		T.Exp[]	el;
		long	n;
		T.BinOp	binop;
		
		debug(munch) debugout("* munchExp : exp =");
		debug(munch) debugout(exp);
		return match(exp,
			T.VINT[&n],{
				debug(munch) debugout("munchExp : VINT[&n]");
				return result((Temp r){ emit(I.LDI(n, r)); });
			},
			T.TEMP[&t],{
				debug(munch) debugout("munchExp : TEMP[&t]");
				return t;
			},
			T.MEM[T.BIN[T.BinOp.ADD, T.TEMP(FP), T.VINT[&n]]],{
				return result((Temp r){ emit(I.LDB(cast(int)n, r)); });
			},
			T.MEM[&e],{
				return result((Temp r){ emit(I.LDA(munchExp(e), r)); });
			},
			T.BIN[&binop, &e1, &e2],{
				debug(munch) debugout("munchExp : BIN[&binop, &e1, &e2]");
				switch (binop)
				{
				case T.BinOp.ADD:	return result((Temp r){ emit(I.ADD(munchExp(e1), munchExp(e2), r)); });
				case T.BinOp.SUB:	return result((Temp r){ emit(I.SUB(munchExp(e1), munchExp(e2), r)); });
				case T.BinOp.MUL:	return result((Temp r){ emit(I.MUL(munchExp(e1), munchExp(e2), r)); });
				case T.BinOp.DIV:	return result((Temp r){ emit(I.DIV(munchExp(e1), munchExp(e2), r)); });
				default:			assert(0);
				}
			},

			T.CALL[T.MEM[T.BIN[T.BinOp.ADD, T.TEMP(FP), T.VINT[&n]]], &el],{
				debug(munch) debugout("munchExp : CALL[MEM[BIN[BinOp.ADD, T.TEMP(FP), VINT[&n]]], &el]");
				
				emit(I.PUSH_CONT());
				
				auto label = result((Temp r){ emit(I.LDB(cast(int)n+0, r)); });
				auto slink = result((Temp r){ emit(I.LDB(cast(int)n+1, r)); });
				auto fsize = result((Temp r){ emit(I.LDI(0xFFFF, r)); });	// TODO FrameSize定数
				emit(I.PUSH(slink));
				emit(I.PUSH(fsize));
				
				foreach (arg; el)
					emit(I.PUSH(munchExp(arg)));
				
				emit(I.CALL(label));
				
				return result((Temp r){ emit(I.MOV(RV, r)); });
			},
			T.CALL[&e, &el],{
				assert(0, "IR error");
				return Temp.init;
			},

		//	T.MEM[T.TEMP[&t]],{
		//		debug(munch) debugout("munchExp : MEM[TEMP[&t]]");
		//		return t;
		//	},
		//	T.MEM[&e],{
		//		debug(munch) debugout("munchExp : MEM[&e]");
		//		return result((Temp r){ ; });
		//	},
		//	T.VFUN[&e, &l],{
		//		debug(munch) debugout("munchExp : VFUN[&e, &l]");
		//		assert(0);
		//		return result((Temp r){ emit(I.LDI(n, r)); });
		//	},
			_,{
				//writef("munchExp : _ = "), debugout(exp);
				assert(0);
				return Temp.init;
			}
		);
	}

	void munchStm(T.Stm stm)
	{
		long	n, disp;
		Temp	t;
		T.Exp	e, e1 ,e2;
		Label	l;
		
		debug(munch) debugout("* munchStm : stm = ");
		debug(munch) debugout(stm);
		match(stm,
			T.MOVE[&e, T.MEM[T.BIN[T.BinOp.ADD, T.TEMP(FP), T.VINT[&disp]]]],{
				if (T.VINT[&n] <<= e)
				{
					debug(munch) debugout("munchStm : MOVE[VINT[&n], MEM[BIN[BinOp.ADD, T.TEMP(FP), VINT[&disp]]]]");
					
					auto e1r = result((Temp r){ emit(I.LDI(n, r)); });
					emit(I.STB(e1r, cast(int)disp));
				}
				else if (T.VFUN[T.TEMP(FP), &l] <<= e)
				{
					// 関数値は常にescapeする==MEM[fp+n]にMOVEされる
					// fp+nはn=0でも加算のIRが作られる(Frame.exp()参照)
					debug(munch) debugout("munchStm : MOVE[VFUN[T.TEMP(FP), &l], MEM[BIN[BinOp.ADD, T.TEMP(FP), VINT[&disp]]]]");
					
					auto RA = result((Temp r){ emit(I.LDI(l.num, r)); });
					emit(I.STB(RA, cast(int)disp + 0));
					emit(I.STB(FP, cast(int)disp + 1));
				}
			},
			T.MOVE[&e1, &e2],{
				debug(munch) debugout("munchStm : MOVE[&e1, &e2]");
				
				if (e2 == T.TEMP(NIL))
					munchExp(e1);
				else
					emit(I.MOV(munchExp(e1), munchExp(e2)));
			},


		//	MOVE[&e1, MEM[T.TEMP(FP)]],{
		//		debug(munch) debugout("munchStm : MOVE[&e1, MEM[T.TEMP(FP)]]");
		//		emit(I.STB(munchExp(e1), 0));
		//	},
		//	MOVE[&e1, MEM[&e2]],{
		//		debug(munch) debugout("munchStm : MOVE[&e1, MEM[&e2]]");
		//		auto t1 = munchExp(e1);
		//		auto t2 = munchExp(e2);
		//		emit(I.LDI(t1, t));
		//	},

		//	MOVE[e, BIN[BinOp.ADD, MEM[T.TEMP(FP)], VINT[&disp]]],{
		//		debug(munch) debugout("munchStm : MOVE[e, BIN[BinOp.ADD, MEM[T.TEMP(FP)], VINT[&disp]]]");
		//		emit(I.STB(munchExp(e), cast(int)disp));
		//	},
		//	MOVE[e, MEM[T.TEMP(FP)]],{
		//		debug(munch) debugout("munchStm : MOVE[e, MEM[T.TEMP(FP)]]");
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
