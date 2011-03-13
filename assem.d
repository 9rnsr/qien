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
		size_t	size;
		long	n;
		T.BinOp	binop;
		
		return match(exp,
			T.VINT[&n],{
				debug(munch) writefln("munchExp : VINT[&n]");
				debug(munch) writefln("         : exp = %s", exp);
				return result((Temp r){
					emit(Instr.OPE(I.instr_imm(n, r.num), [], [r], []));
				});
			},
			T.TEMP[&t],{
				debug(munch) writefln("munchExp : TEMP[&t]");
				debug(munch) writefln("         : exp = %s", exp);
				return t;
			},
			T.MEM[T.BIN[T.BinOp.ADD, T.TEMP(FP), &disp], /*size=*/1],{
				debug(munch) writefln("munchExp : MEM[BIN[BinOp.ADD, TEMP(FP), &disp]]");
				debug(munch) writefln("         : exp = %s", exp);
				auto d = munchExp(disp);
				return result((Temp r){ 
					emit(Instr.OPE(I.instr_add(FP.num, d.num, temp.num), [FP,d], [temp], []));	// FP + d -> temp
					emit(Instr.OPE(I.instr_get(temp.num, r.num), [temp], [r], []));				// [temp] -> r
				});
			},
			T.MEM[&e, /*size=*/1],{
				debug(munch) writefln("munchExp : MEM[&e]");
				debug(munch) writefln("         : exp = %s", exp);
				auto t = munchExp(e);
				return result((Temp r){ 
					emit(Instr.OPE(I.instr_get(t.num, r.num), [t], [r], []));	// [t] -> r
				});
			},
			T.BIN[&binop, &e1, &e2],{
				debug(munch) writefln("munchExp : BIN[&binop, &e1, &e2]");
				debug(munch) writefln("         : exp = %s", exp);
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

			T.CALL[T.MEM[T.BIN[T.BinOp.ADD, T.TEMP(FP), &disp], &size], &el],{
				debug(munch) writefln("munchExp : CALL[MEM[BIN[BinOp.ADD, T.TEMP(FP), VINT[&n]]], &el]");
				debug(munch) writefln("         : exp = %s", exp);
				
				assert(size == 2);
				
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
				
				emit(Instr.OPE(I.instr_call(label.num), [CP,SP,label], [FP,RV], []));
				
				return result((Temp r){ emit(Instr.OPE(I.instr_mov(RV.num, r.num), [RV], [r], [])); });
			},
			T.CALL[&e, &el],{
				assert(0, "IR error");
				return Temp.init;
			},
			_,{
			//	writef("munchExp : _ = "), debugout(exp);
				writef("munchExp : _ = %s", exp);
				assert(0);
				return Temp.init;
			}
		);
	}
	void munchStm(T.Stm stm)
	{
		void movemem(Temp psrc, Temp pdst, size_t size)
		{
			assert(size >= 1);
			if (size >= 2)
				emit(Instr.OPE(I.instr_imm(1, temp.num), [], [temp], []));
			foreach (ofs; 0 .. size)
			{
				if (ofs >= 1)
				{
					emit(Instr.OPE(I.instr_add(psrc.num, temp.num, psrc.num), [psrc,temp], [psrc], []));
					emit(Instr.OPE(I.instr_add(pdst.num, temp.num, pdst.num), [pdst,temp], [pdst], []));
				}
				emit(Instr.OPE(I.instr_set(psrc.num, pdst.num), [psrc,pdst], [], []));
			}
		}
		
		
		size_t	s1, s2;
		T.Exp	e1 ,e2;
		Label	l;
		
		auto mem1 = T.MEM[&e1, &s1];
		auto mem2 = T.MEM[&e2, &s2];
		match(stm,
			T.MOVE[mem1, mem2],{
				debug(munch) debugout("munchStm : MOVE[mem1, mem2]");
				debug(munch) debugout("         : stm = "), debugout(stm);
				assert(s1 == s2);
				movemem(munchExp(e1), munchExp(e2), s1);
			},
			T.MOVE[&e1,  mem2],{
				if (T.VFUN[T.TEMP(FP), &l] <<= e1)
				{
					debug(munch) debugout("munchStm : MOVE[VFUN[FP, &l], mem2]");
					debug(munch) debugout("         : stm = "), debugout(stm);
					assert(s2 == 2);
					// 1 -> temp
					emit(Instr.OPE(I.instr_imm(1, temp.num), [], [temp], []));
					
					auto dst0 = munchExp(e2);
					auto dst1 = result((Temp r){ emit(Instr.OPE(I.instr_add(dst0.num, temp.num, r.num), [dst0,temp], [r], [])); });
					
					// label -> temp
					emit(Instr.OPE(I.instr_imm(l.num, temp.num), [], [temp], []));
					
					emit(Instr.OPE(I.instr_set(temp.num, dst0.num), [temp,dst0], [], []));	// label -> mem2.ptr+d0
					emit(Instr.OPE(I.instr_set(FP  .num, dst1.num), [FP  ,dst1], [], []));	// slink -> mem2.ptr+d1
				}
				else
				{
					debug(munch) debugout("munchStm : MOVE[&e1, mem2]");
					debug(munch) debugout("         : stm = "), debugout(stm);
					movemem(munchExp(e1), munchExp(e2), s2);
					if (s2 == 1)	// 式の結果としてここでDereferenceが必要なポインタを返すことはない
					{
						auto  src = munchExp(e1);
						auto pdst = munchExp(e2);
						emit(Instr.OPE(I.instr_set(src.num, pdst.num), [src,pdst], [], []));
					}
					else
						movemem(munchExp(e1), munchExp(e2), s2);
				}
			},
			T.MOVE[mem1, &e2],{
				debug(munch) debugout("munchStm : MOVE[mem1, &e2]");
				debug(munch) debugout("         : stm = "), debugout(stm);
				assert(s1 == 1);	// MOVE先がMEMでないならテンポラリへの1ワードの転送しかない
				auto psrc = munchExp(e1);
				auto  dst = munchExp(e2);
				emit(Instr.OPE(I.instr_get(psrc.num, dst.num), [psrc,dst], [], []));
			},
			T.MOVE[&e1, &e2],{
				debug(munch) debugout("munchStm : MOVE[&e1, &e2]");
				debug(munch) debugout("         : stm = "), debugout(stm);
				
				if (e2 == T.TEMP(NIL))
					munchExp(e1);
				else
				{
					auto src = munchExp(e1);
					auto dst = munchExp(e2);
					emit(Instr.OPE(I.instr_mov(src.num, dst.num), [src], [dst], []));
				}
			},
			_,{
				debug(munch) debugout("munchStm : __error__");
				debug(munch) debugout("         : stm = "), debugout(stm);
				assert(0);
			}
		);
	}
	
	foreach (s; stms)
		munchStm(s);
	
	return instrlist;
}
