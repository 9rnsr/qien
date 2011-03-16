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

//debug = munch;

Instr[] munchProg(Fragment[] fragments)
{
	Instr[] instr;

	foreach (f; fragments)
	{
		auto stms = f.p[0], frame = f.p[1];
		instr ~= Instr.LBL(null, frame.name);
		instr ~= frame.procEntryExit3(munch(stms));
	}

	debugCodeMapPrint();

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
		instrlist ~= instr;
	}
	Temp result(void delegate(Temp) gen)
	{
		auto t = newTemp();
		gen(t);
		return t;
	}
	void movemem(Temp psrc, Temp pdst, size_t size)
	{
		assert(size >= 1);
		Temp ofs1;
		if (size >= 2)
		{
			ofs1 = newTemp();
			emit(Instr.OPE(I.instr_imm(1, ofs1.num), [], [ofs1], []));
			// オリジナルのpsrc/pdstレジスタを書き換えないよう新規確保する
			psrc = result((Temp r){ emit(Instr.OPE(I.instr_mov(psrc.num, r.num), [psrc], [r], [])); });
			pdst = result((Temp r){ emit(Instr.OPE(I.instr_mov(pdst.num, r.num), [pdst], [r], [])); });
		}
		
		foreach (ofs; 0 .. size)
		{
			if (ofs >= 1)
			{
				emit(Instr.OPE(I.instr_add(psrc.num, ofs1.num, psrc.num), [psrc,ofs1], [psrc], []));
				emit(Instr.OPE(I.instr_add(pdst.num, ofs1.num, pdst.num), [pdst,ofs1], [pdst], []));
			}
			emit(Instr.OPE(I.instr_get(psrc.num, temp.num), [psrc], [temp], []));
			emit(Instr.OPE(I.instr_set(temp.num, pdst.num), [temp,pdst], []));
		}
	}
	
	Temp munchExp(T.Exp exp)
	{
		Temp	t;
		Label	l;
		T.Exp	e, e1, e2, disp, base;
		T.Exp[]	el;
		size_t	size;
		long	n;
		T.BinOp	binop;
		
		return match(exp,
			T.FIXN[&n],{
				debug(munch) writefln("munchExp : FIXN[&n]");
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
			T.MEM[T.BIN[T.BinOp.ADD, T.TEMP(EP), &disp], /*size=*/1],{
				debug(munch) writefln("munchExp : MEM[BIN[BinOp.ADD, TEMP(EP), &disp]]");
				debug(munch) writefln("         : exp = %s", exp);
				auto d = munchExp(disp);
				return result((Temp r){ 
					emit(Instr.OPE(I.instr_add(EP.num, d.num, temp.num), [EP,d], [temp], []));	// EP + d -> temp
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

			T.CALL[T.MEM[&base, &size], &el],{
				debug(munch) writefln("munchExp : CALL[MEM[BIN[BinOp.ADD, T.TEMP(EP), FIXN[&n]]], &el]");
				debug(munch) writefln("         : exp = %s", exp);
				
				assert(size == 2);
				
				emit(Instr.OPE(I.instr_pushc(), [], [CP,SP], []));
				
				auto tRV = newTemp();
				emit(Instr.OPE(I.instr_mov(RV.num, tRV.num), [RV], [tRV], []));
				
				auto p0 = munchExp(base);
				auto label = result((Temp r){ emit(Instr.OPE(I.instr_get(p0.num, r.num), [p0], [r], [])); });
				
				emit(Instr.OPE(I.instr_imm(1, temp.num), [], [temp], []));
				emit(Instr.OPE(I.instr_add(p0.num, temp.num, p0.num), [p0,temp], [p0], []));
				
				auto slink = result((Temp r){ emit(Instr.OPE(I.instr_get(p0.num, r.num), [p0], [r], [])); });
				
				auto fsize = result((Temp r){ emit(Instr.OPE(I.instr_imm(0xBEEF, r.num), [], [r], [])); });
				emit(Instr.OPE(I.instr_pushs(slink.num), [SP,slink], [], []));
				emit(Instr.OPE(I.instr_pushs(fsize.num), [SP,fsize], [], []));
				
				size_t rvalue_size = 0;
				foreach (arg; el)
				{
					if (T.MEM[&e, &size] <<= arg)
					{
						
						if (T.CALL[$] <<= e)
						{
							rvalue_size += size;
							// allocate memory for temporary argument on stack
							//sp + size -> sp
							emit(Instr.OPE(I.instr_mov(SP.num, RV.num), [SP], [RV], []));
							emit(Instr.OPE(I.instr_imm(size, temp.num), [], [temp], []));
							emit(Instr.OPE(I.instr_add(SP.num, temp.num, SP.num), [SP,temp], [SP], []));
							
							auto t = munchExp(e);
							assert(t is RV);
						//	emit(Instr.OPE(I.instr_pushs(t.num), [SP, t], [], []));
						}
						else
						{
							auto t = munchExp(e);
							if (size == 1)
							{
								emit(Instr.OPE(I.instr_get(t.num, t.num), [t], [t], []));
								emit(Instr.OPE(I.instr_pushs(t.num), [t], [], []));
							}
							else
							{
								auto pdst = result((Temp r){ emit(Instr.OPE(I.instr_mov(SP.num, r.num), [SP], [r], [])); });
								emit(Instr.OPE(I.instr_imm(size, temp.num), [], [temp], []));
								emit(Instr.OPE(I.instr_add(SP.num, temp.num, SP.num), [SP,temp], [SP], []));
								movemem(t, pdst, size);
							}
						}
					}
					else
					{
						auto t = munchExp(arg);
						emit(Instr.OPE(I.instr_pushs(t.num), [SP, t], [], []));
					}
				}
				emit(Instr.OPE(I.instr_mov(tRV.num, RV.num), [RV,temp], [RV], []));
				emit(Instr.OPE(I.instr_call(label.num), [CP,SP,label], [EP,RV], []));
				
				// free memory for temporary arguments on stack
				if (rvalue_size > 0)
				{
					//sp - size -> sp
					emit(Instr.OPE(I.instr_imm(rvalue_size, temp.num), [], [temp], []));
					emit(Instr.OPE(I.instr_sub(SP.num, temp.num, SP.num), [SP,temp], [SP], []));
				}
				
				return RV;
			},
			T.CALL[&e, &el],{
				writef("munchExp : _ = "), debugout(exp);
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
	Instr[] munchStm(T.Stm stm)
	{
		auto instrLen = instrlist.length;
		
		size_t	s1, s2;
		T.Exp	e1 ,e2;
		Label	l;
		
		bool	esc;
		
		auto mem1 = T.MEM[&e1, &s1];
		auto mem2 = T.MEM[&e2, &s2];
		match(stm,
			T.MOVE[mem1, mem2],{
				debug(munch) debugout("munchStm : MOVE[mem1, mem2]");
				debug(munch) debugout("         : stm = "), debugout(stm);
				assert(s1 == s2);
				if (T.CALL[$] <<= e1)
				{
					auto pdst = munchExp(e2);
					emit(Instr.OPE(I.instr_mov(pdst.num, RV.num), [pdst], [RV], []));
					auto psrc = munchExp(e1);
				}
				else
				{
					auto psrc = munchExp(e1);
					auto pdst = munchExp(e2);
					movemem(psrc, pdst, s1);
				}
			},
			T.MOVE[&e1,  mem2],{
				if (T.FUNC[&l, &esc] <<= e1)
				{
					if (esc)
						emit(Instr.OPE(I.instr_pushe(), [EP], [], []));
					
					debug(munch) debugout("munchStm : MOVE[FUNC[&l, &esc], mem2]");
					debug(munch) debugout("         : stm = "), debugout(stm);
					assert(s2 == 2);
					// 1 -> temp
					emit(Instr.OPE(I.instr_imm(1, temp.num), [], [temp], []));
					
					auto dst0 = munchExp(e2);
					auto dst1 = result((Temp r){ emit(Instr.OPE(I.instr_add(dst0.num, temp.num, r.num), [dst0,temp], [r], [])); });
					
					// label -> temp
					emit(Instr.OPE(I.instr_imm(l.num, temp.num), [], [temp], []));
					
					emit(Instr.OPE(I.instr_set(temp.num, dst0.num), [temp,dst0], [], []));	// label -> mem2.ptr+d0
					emit(Instr.OPE(I.instr_set(EP  .num, dst1.num), [EP  ,dst1], [], []));	// slink -> mem2.ptr+d1
				}
				else
				{
					debug(munch) debugout("munchStm : MOVE[&e1, mem2]");
					debug(munch) debugout("         : stm = "), debugout(stm);
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
				emit(Instr.OPE(I.instr_get(psrc.num, dst.num), [psrc], [dst], []));
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
				debugout("munchStm : __error__");
				debugout("         : stm = "), debugout(stm);
				assert(0);
			}
		);
		
		return instrlist[instrLen .. $];
	}
	
	foreach (s; stms)
		debugCodeMap(s, munchStm(s));
	return instrlist;
}
