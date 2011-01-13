module assem;

import sym;
import frame;
import T = tree;
import typecons.tagunion;
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
	Instr[] munch(T.Stm[] stms)
	{
		instrlist = [];
		
		foreach (s; stms)
			munchStm(s);
		
		return instrlist;
	}

private:
	Instr[] instrlist;

	void emit(Instr instr)
	{
		//debugout("emit : %s", instr);
		instrlist ~= instr;
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
				return result((Temp r){ emit(Instr.OPE(I.LDI(n, r), [], [r], [])); });
			},
			T.TEMP[&t],{
				debug(munch) debugout("munchExp : TEMP[&t]");
				return t;
			},
			T.MEM[T.BIN[T.BinOp.ADD, T.TEMP(FP), T.VINT[&n]]],{
				debug(munch) debugout("munchExp : MEM[BIN[BinOp.ADD, TEMP(FP), VINT[&n]]]");
				return result((Temp r){ emit(Instr.OPE(I.LDB(cast(int)n, r), [FP], [r], [])); });
			},
			T.MEM[&e],{
				debug(munch) debugout("munchExp : MEM[&e]");
				auto t = munchExp(e);
				return result((Temp r){ emit(Instr.OPE(I.LDA(t, r), [t], [r], [])); });
			},
			T.BIN[&binop, &e1, &e2],{
				debug(munch) debugout("munchExp : BIN[&binop, &e1, &e2]");
				auto t1 = munchExp(e1);
				auto t2 = munchExp(e2);
				switch (binop)
				{
				case T.BinOp.ADD:	return result((Temp r){ emit(Instr.OPE(I.ADD(t1, t2, r), [t1,t2], [r], [])); });
				case T.BinOp.SUB:	return result((Temp r){ emit(Instr.OPE(I.SUB(t1, t2, r), [t1,t2], [r], [])); });
				case T.BinOp.MUL:	return result((Temp r){ emit(Instr.OPE(I.MUL(t1, t2, r), [t1,t2], [r], [])); });
				case T.BinOp.DIV:	return result((Temp r){ emit(Instr.OPE(I.DIV(t1, t2, r), [t1,t2], [r], [])); });
				default:			assert(0);
				}
			},

			T.CALL[T.MEM[T.BIN[T.BinOp.ADD, T.TEMP(FP), T.VINT[&n]]], &el],{
				debug(munch) debugout("munchExp : CALL[MEM[BIN[BinOp.ADD, T.TEMP(FP), VINT[&n]]], &el]");
				
				emit(Instr.OPE(I.PUSH_CONT(), [], [CP,SP], []));
				
				auto label = result((Temp r){ emit(Instr.OPE(I.LDB(cast(int)n+0, r), [FP], [r], [])); });
				auto slink = result((Temp r){ emit(Instr.OPE(I.LDB(cast(int)n+1, r), [FP], [r], [])); });
				auto fsize = result((Temp r){ emit(Instr.OPE(I.LDI(0xBEEF,       r), [],   [r], [])); });
				emit(Instr.OPE(I.PUSH(slink), [SP,slink], [], []));
				emit(Instr.OPE(I.PUSH(fsize), [SP,fsize], [], []));
				
				foreach (arg; el)
				{
					auto ta = munchExp(arg);
					emit(Instr.OPE(I.PUSH(ta), [SP, ta], [], []));
				}
				
				emit(Instr.OPE(I.CALL(label), [CP,SP,label], [FP,RV], []));
				
				return result((Temp r){ emit(Instr.OPE(I.MOV(RV, r), [RV], [r], [])); });
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
		//		return result((Temp r){ emit(Instr.OPE(I.LDI(n, r), [], [], [])); });
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
					
					auto r = result((Temp r){ emit(Instr.OPE(I.LDI(n, r), [], [r], [])); });
					emit(Instr.OPE(I.STB(r, cast(int)disp), [FP,r], [], []));
				}
				else if (T.VFUN[T.TEMP(FP), &l] <<= e)
				{
					// 関数値は常にescapeする==MEM[fp+n]にMOVEされる
					// fp+nはn=0でも加算のIRが作られる(Frame.exp()参照)
					debug(munch) debugout("munchStm : MOVE[VFUN[T.TEMP(FP), &l], MEM[BIN[BinOp.ADD, T.TEMP(FP), VINT[&disp]]]]");
					
					auto ta = result((Temp r){ emit(Instr.OPE(I.LDI(l.num, r), [], [r], [])); });
					emit(Instr.OPE(I.STB(ta, cast(int)disp + 0), [FP,ta], [], []));
					emit(Instr.OPE(I.STB(FP, cast(int)disp + 1), [FP],    [], []));
				}
			},
			T.MOVE[&e1, &e2],{
				debug(munch) debugout("munchStm : MOVE[&e1, &e2]");
				
				if (e2 == T.TEMP(NIL))
					munchExp(e1);
				else
				{
					auto t1 = munchExp(e1);
					auto t2 = munchExp(e2);
					emit(Instr.OPE(I.MOV(t1, t2), [t1], [t2], []));
				}
			},


		//	MOVE[&e1, MEM[T.TEMP(FP)]],{
		//		debug(munch) debugout("munchStm : MOVE[&e1, MEM[T.TEMP(FP)]]");
		//		emit(Instr.OPE(I.STB(munchExp(e1), 0), [], [], []));
		//	},
		//	MOVE[&e1, MEM[&e2]],{
		//		debug(munch) debugout("munchStm : MOVE[&e1, MEM[&e2]]");
		//		auto t1 = munchExp(e1);
		//		auto t2 = munchExp(e2);
		//		emit(Instr.OPE(I.LDI(t1, t), [], [], []));
		//	},

		//	MOVE[e, BIN[BinOp.ADD, MEM[T.TEMP(FP)], VINT[&disp]]],{
		//		debug(munch) debugout("munchStm : MOVE[e, BIN[BinOp.ADD, MEM[T.TEMP(FP)], VINT[&disp]]]");
		//		emit(Instr.OPE(I.STB(munchExp(e), cast(int)disp), [], [], []));
		//	},
		//	MOVE[e, MEM[T.TEMP(FP)]],{
		//		debug(munch) debugout("munchStm : MOVE[e, MEM[T.TEMP(FP)]]");
		//		emit(Instr.OPE(I.STB(munchExp(e), cast(int)0), [], [], []));
		//	},
		//	MOVE[VINT[&n], MEM[TEMP[&t]]],{
		//		debug(munch) debugout("munchStm : MOVE[VINT[&n], MEM[TEMP[&t]]]");
		//		emit(Instr.OPE(I.LDI(n, t), [], [], []));
		//	},
		//	MOVE[VINT[&n], &e],{
		//		debug(munch) debugout("munchStm : MOVE[VINT[&n], &e]");
		//		emit(Instr.OPE(I.LDI(n, munchExp(e)), [], [], []));
		//		assert(0);
		//	},
		//	MOVE[&e1, &e2],{
		//		debug(munch) debugout("munchStm : MOVE[&e1, &e2]");
		//		auto t1 = munchExp(e1);
		//		auto t2 = munchExp(e2);
		//		emit(Instr.OPE(I.MOV(t1, t2), [], [], []));
		//	},
		//	MOVE[&t, &e],{
		//		debug(munch) debugout("munchStm : MOVE[&t, &e]");
		//		emit(Instr.OPE(I.MOV(t, munchExp(e)), [], [], []));
		//	},
			_,{
				assert(0);
			}
		);
	}
}
