module assem;

import sym;
import frame;
import T = tree;
import xtk.tagunion;
import std.conv, std.string, std.stdio;
import std.metastrings;
import debugs;

public import machine;
alias machine.Instruction I;

debug = munch;

Instr[] munchProg(Fragment[] fragments)
{
	Instr[] instr;

	foreach (f; fragments)
	{
		auto stms = f.p[0], frame = f.p[1];
		
	//	debug(machine) debugout("label to pc : %s(@%s) -> %08X",
	//		frame.name, frame.name.num, code.length);
		
		instr ~= Instr.LBL(null, frame.name);
		instr ~= frame.procEntryExit3(munch(stms));
	}

	return instr;
}


class Instr
{
	mixin TagUnion!(
		"OPE",	ulong[], Temp[], Temp[], Label[],
		"LBL",	ulong[], Label,
		"MOV",	ulong[], Temp, Temp
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

Instr[] munch(T.Stm[] stms)
{
	Instr[] instrlist = [];
	Temp temp = newTemp();
	
	void emit(Instr instr)
	{
		Instruction mi;
		if ((Instr.OPE[&mi, $] <<= instr) ||
			(Instr.LBL[&mi, $] <<= instr) ||
			(Instr.MOV[&mi, $] <<= instr) )
		{
//			writefln("emit : %s", mi);
		}
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
		T.Exp	e, e1, e2, disp;
		T.Exp[]	el;
		long	n;
		T.BinOp	binop;
		
		debug(munch) debugout("* munchExp : exp =");
		debug(munch) debugout(exp);
		return match(exp,
			T.VINT[&n],{
				debug(munch) debugout("munchExp : VINT[&n]");
				return result((Temp r){
					emit(Instr.OPE(I.instr_imm(n, r.num), [], [r], []));
				});
			},
			T.TEMP[&t],{
				debug(munch) debugout("munchExp : TEMP[&t]");
				return t;
			},
			T.MEM[T.BIN[T.BinOp.ADD, T.TEMP(FP), &disp]],{
				debug(munch) debugout("munchExp : MEM[BIN[BinOp.ADD, TEMP(FP), &disp]]");
				auto d = munchExp(disp);
				return result((Temp r){ 
					emit(Instr.OPE(I.instr_add(FP.num, d.num, temp.num), [FP,d], [temp], []));	// FP + d -> temp
					emit(Instr.OPE(I.instr_get(temp.num, r.num), [temp], [r], []));				// [temp] -> r
				});
			},
			T.MEM[&e],{
				debug(munch) debugout("munchExp : MEM[&e]");
				auto t = munchExp(e);
				return result((Temp r){ 
					emit(Instr.OPE(I.instr_get(t.num, r.num), [t], [r], []));	// [t] -> r
				});
			},
			T.BIN[&binop, &e1, &e2],{
				debug(munch) debugout("munchExp : BIN[&binop, &e1, &e2]");
				auto t1 = munchExp(e1);
				auto t2 = munchExp(e2);
				return result((Temp r){
					ulong[] i;
					switch (binop)
					{
					case T.BinOp.ADD:	i = I.instr_add(t1.num, t2.num, r.num);		break;
					case T.BinOp.SUB:	i = I.instr_sub(t1.num, t2.num, r.num);		break;
					case T.BinOp.MUL:	i = I.instr_mul(t1.num, t2.num, r.num);		break;
					case T.BinOp.DIV:	i = I.instr_div(t1.num, t2.num, r.num);		break;
					default:			assert(0);
					}
					emit(Instr.OPE(i, [t1,t2], [r], []));
				});
			},

			T.CALL[T.MEM[T.BIN[T.BinOp.ADD, T.TEMP(FP), &disp]], &el],{
				debug(munch) debugout("munchExp : CALL[MEM[BIN[BinOp.ADD, T.TEMP(FP), VINT[&n]]], &el]");
				
				emit(Instr.OPE(I.instr_pushc(), [], [CP,SP], []));
				
				auto d0 = munchExp(disp);
				auto d1 = munchExp(T.BIN(T.BinOp.ADD, T.TEMP(d0), T.VINT(1)));
				
				auto label = result((Temp r){
					emit(Instr.OPE(I.instr_add(FP.num, d0.num, temp.num), [FP,d0], [temp], []));
					emit(Instr.OPE(I.instr_get(temp.num, r.num), [temp], [r], []));
				});
				auto slink = result((Temp r){
					emit(Instr.OPE(I.instr_add(FP.num, d1.num, temp.num), [FP,d0], [temp], []));
					emit(Instr.OPE(I.instr_get(temp.num, r.num), [temp], [r], []));
				});
				auto fsize = result((Temp r){
					emit(Instr.OPE(I.instr_imm(0xBEEF, r.num), [], [r], []));
				});
				emit(Instr.OPE(I.instr_pushs(slink.num), [SP,slink], [], []));
				emit(Instr.OPE(I.instr_pushs(fsize.num), [SP,fsize], [], []));
				
				foreach (arg; el)
				{
					auto ta = munchExp(arg);
					emit(Instr.OPE(I.instr_pushs(ta.num), [SP, ta], [], []));
				}
				
			//	emit(Instr.OPE(I.instr_imm(label.num, temp.num), [], [temp], []));
			//	emit(Instr.OPE(I.instr_call(temp.num), [CP,SP,temp], [FP,RV], []));
				emit(Instr.OPE(I.instr_call(label.num), [CP,SP,label], [FP,RV], []));
				
				return result((Temp r){ emit(Instr.OPE(I.instr_mov(RV.num, r.num), [RV], [r], [])); });
			},
			T.CALL[&e, &el],{
				assert(0, "IR error");
				return Temp.init;
			},
			_,{
				writef("munchExp : _ = "), debugout(exp);
				assert(0);
				return Temp.init;
			}
		);
	}
	void munchStm(T.Stm stm)
	{
		long	n;
		Temp	t;
		T.Exp	e, e1 ,e2, disp;
		Label	l;
		
		debug(munch) debugout("* munchStm : stm = ");
		debug(munch) debugout(stm);
		match(stm,
			T.MOVE[&e, T.MEM[T.BIN[T.BinOp.ADD, T.TEMP(FP), &disp]]],{
				if (T.VINT[&n] <<= e)
				{
					debug(munch) debugout("munchStm : MOVE[VINT[&n], MEM[BIN[BinOp.ADD, T.TEMP(FP), &disp]]]");
					
 					auto d = munchExp(disp);
					auto r = result((Temp r){ emit(Instr.OPE(I.instr_imm(n, r.num), [], [r], [])); });
					emit(Instr.OPE(I.instr_add(FP.num, d.num, temp.num), [FP,d], [temp], []));
					emit(Instr.OPE(I.instr_set(r.num, temp.num), [r,temp], [], []));
				}
				else if (T.VFUN[T.TEMP(FP), &l] <<= e)
				{
					// 関数値は常にescapeする==MEM[fp+n]にMOVEされる
					// fp+nはn=0でも加算のIRが作られる(Frame.exp()参照)
					debug(munch) debugout("munchStm : MOVE[VFUN[T.TEMP(FP), &l], MEM[BIN[BinOp.ADD, T.TEMP(FP), VINT[&disp]]]]");
					
					auto d0 = munchExp(disp);
					auto d1 = munchExp(T.BIN(T.BinOp.ADD, T.TEMP(d0), T.VINT(1)));
					
					auto ta = result((Temp r){ emit(Instr.OPE(I.instr_imm(l.num, r.num), [], [r], [])); });	//?
					
					emit(Instr.OPE(I.instr_add(FP.num, d0.num, temp.num), [FP, d0], [temp], []));
					emit(Instr.OPE(I.instr_set(ta.num, temp.num), [ta,temp], [], []));
					
					emit(Instr.OPE(I.instr_add(FP.num, d1.num, temp.num), [FP, d1], [temp], []));
					emit(Instr.OPE(I.instr_set(FP.num, temp.num), [FP,temp], [], []));
				}
				else
				{
					assert(0);
				}
			},
			T.MOVE[T.VINT[&n], T.TEMP[&t]],{
				debug(munch) debugout("munchStm : MOVE[VINT[&n], TEMP[&t]]");
				
				emit(Instr.OPE(I.instr_imm(n, t.num), [], [t], []));
			},
			T.MOVE[&e1, &e2],{
				debug(munch) debugout("munchStm : MOVE[&e1, &e2]");
				
				if (e2 == T.TEMP(NIL))
					munchExp(e1);
				else
				{
					auto t1 = munchExp(e1);
					auto t2 = munchExp(e2);
					emit(Instr.OPE(I.instr_mov(t1.num, t2.num), [t1], [t2], []));
				}
			},
			_,{
				assert(0);
			}
		);
	}
	
	foreach (s; stms)
		munchStm(s);
	
	return instrlist;
}
