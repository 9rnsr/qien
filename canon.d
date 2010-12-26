module canon;

import sym;
import tree;
import typecons.match;
import std.typecons;
import std.traits;
import std.typetuple : allSatisfy;
import debugs;

//debug = canon;

Stm[] linearize(Stm s)
{
	static Stm[] linear(Stm s, Stm[] l)
	{
		Stm[] sl;
		if (SEQ[&sl] <<= s)
			return linear(sl[0], linear(sl[1], l));
	    else
			return s ~ l;
	}
	return linear(do_stm(s), []);
}



Stm seq(Stm x, Stm y)
{
	if (EXP[VINT[_]] <<= x) return y;
	if (EXP[VINT[_]] <<= y) return x;
	return SEQ([x,y]);
}

bool commute(Stm s, Exp e)
{
	if (EXP[VINT[_]] <<= s) return true;
	if (NAME[_] <<= e) return true;
	if (VINT[_] <<= e) return true;
	return false;
}

Tuple!(Stm, Exp[]) reorder(Exp[] el)
{
	auto nop = EXP(VINT(0));

	if (el.length == 0)
		return tuple(nop, (Exp[]).init);
	else
	{
		auto a = el[0];
		auto rest = el[1..$];
		
		if (CALL[_,_] <<= a)
		{
			auto t = newTemp();
			return reorder(ESEQ(MOVE(TEMP(t), a), TEMP(t)) ~ rest);
		}
		else
		{
			Stm s1, s2;
			Exp e;
			tie[s1, e] <<= do_exp(a);
			tie[s2, el] <<= reorder(rest);
			if (commute(s2, e))
				return tuple(seq(s1, s2), e~el);
			else
			{
				auto t = newTemp();
				return tuple(seq(seq(s1, MOVE(TEMP(t), e)), s2), TEMP(t) ~ el);
			}
		}
	}
}

Tuple!(Stm, Exp) reorder_exp(EL, BLD)(EL el_, BLD build)
{
	Stm   s;
	Exp[] el;
	tie[s, el] <<= reorder(cast(Exp[])el_);
	return tuple(s, callBuild(el, build));
}

Stm reorder_stm(EL, BLD)(EL el_, BLD build)
{
	Stm   s;
	Exp[] el;
	tie[s, el] <<= reorder(cast(Exp[])el_);
	return seq(s, callBuild(el, build));
}

private{
	template isExp(E){ enum isExp = is(E == Exp); }
	R callBuild(R, TE...)(Exp[] el, R delegate(TE) build)
	{
		static assert(TE.length>=1);
		static if (allSatisfy!(isExp, TE[0..$-1], Exp) && is(TE[$-1] == Exp[]))
		{
			static if (TE.length == 1) return build(el[0..$]);
			static if (TE.length == 2) return build(el[0], el[1..$]);
			static if (TE.length >= 3) static assert(0);
		}
		else static if (allSatisfy!(isExp, TE[0..$]))
		{
			static if (TE.length == 1) return build(el[0]);
			static if (TE.length == 2) return build(el[0], el[1]);
			static if (TE.length >= 3) static assert(0);
		}
		else
			static assert(0);
	}
}

Tuple!(Stm, Exp) do_exp(Exp e)
{
	Stm		s;
	Exp		a, b;
	Exp[]	el;
	BinOp	op;
	
	return match(e,
		BIN[&op,&a,&b],{
			return reorder_exp([a,b], (Exp a, Exp b){ return BIN(op,a,b); });
		},
		MEM[&a],{
			return reorder_exp([a], (Exp a){ return MEM(a); });
		},
		ESEQ[&s,&e],{
			auto s0 = do_stm(s);
			tie[s, e] <<= do_exp(e);
			return tuple(seq(s0, s), e);
		},
		CALL[&e,&el],{
			return reorder_exp(e~el, (Exp e, Exp[] el){ return CALL(e,el); });
		},
		_,{
			return reorder_exp([], (Exp[] _){ return e; });
		}
	);
}

Stm do_stm(Stm s)
{
	Temp	r;
	Label	t, f;
	Label[]	ll;
	Exp		e, a, b;
	Exp[]	el;
	Stm[]	sl;
	Relop	rop;
	
	return match(s,
		MOVE[TEMP[&r],CALL[&e,&el]],{
			return reorder_stm(e~el, (Exp e, Exp[] el){ return MOVE(TEMP(r),CALL(e,el)); });
		},
		MOVE[TEMP[&r],&b],{
			return reorder_stm([b], (Exp e){ return MOVE(TEMP(r), e); });
		},
		MOVE[MEM[&e],&b],{
			return reorder_stm([e,b], (Exp e, Exp b){ return MOVE(MEM(e), b); });
		},
		MOVE[ESEQ[&s,&e],&b],{
			return do_stm(seq(s,MOVE(e,b)));
		},
		EXP[CALL[&e,&el]],{
			return reorder_stm(e~el, (Exp e, Exp[] el){ return EXP(CALL(e,el)); });
		},
		EXP[&e],{
			return reorder_stm([e], (Exp e){ return EXP(e); });
		},
		JUMP[&e, &ll],{
			return reorder_stm([e], (Exp e){ return JUMP(e, ll); });
		},
		CJUMP[&rop,&a,&b,&t,&f],{
			return reorder_stm([a,b], (Exp a, Exp b){ return CJUMP(rop,a,b,t,f); });
		},
		SEQ[&sl],{
			return seq(do_stm(sl[0]), do_stm(sl[1]));
		},
		_,{
			return reorder_stm([], (Exp[] _){ return s; });
		}
	);
	
}

// ex 8.1
debug(canon)
unittest
{
	writefln("unittest @ %s:%s", __FILE__, __LINE__);
	scope(success) writefln("unittest succeeded @ %s:%s", __FILE__, __LINE__);

	auto t1 = newTemp();
	auto t2 = newTemp();
	
	auto s1 = LABEL(newLabel());
	auto s2 = LABEL(newLabel());
	auto e1 = NAME(newLabel());
	auto e2 = NAME(newLabel());
	auto e3 = NAME(newLabel());
	auto e4 = NAME(newLabel());
	auto e1N = BIN(BinOp.ADD, MEM(TEMP(t1)), MEM(TEMP(t2)));
	auto e2N = BIN(BinOp.ADD, MEM(TEMP(t1)), MEM(TEMP(t2)));
	
	// a
	assert(do_stm(MOVE(TEMP(t1), ESEQ(s1, e1)))
		== seq(s1, MOVE(TEMP(t1), e1)));
	
	// b
	assert(do_stm(MOVE(MEM(ESEQ(s1, e1)), e2))
		== seq(s1, MOVE(MEM(e1), e2)));
	
	// c
	assert(commute(s1, e1));
	assert(do_stm(MOVE(MEM(e1), ESEQ(s1, e2)))
		== seq(s1, MOVE(MEM(e1), e2)));
	
//	Temp tnew1, tnew2;
//	assert(!commute(s1, e1N));
//	assert(SEQ([MOVE(TEMP(&tnew1), e1N), SEQ([s1, MOVE(TEMP(&tnew2), e2)])])
//		= do_stm(MOVE(MEM(e1N), ESEQ(s1, e2))));
//	assert(tnew1 is tnew2);
	
	// d
	assert(do_stm(EXP(ESEQ(s1, e1)))
		== seq(s1, EXP(e1)));
	
	// e
	assert(do_stm(EXP(CALL(ESEQ(s1, e1), [e2])))
		== seq(s1, EXP(CALL(e1, [e2]))));
	
	// f
	assert(do_stm(MOVE(TEMP(t1), CALL(ESEQ(s1, e1), [e2])))
			== seq(s1, MOVE(TEMP(t1), CALL(e1, [e2]))));
	
	// g
	assert(commute(s1, e2));
	  assert(commute(s1, e1));
		assert(do_stm(EXP(CALL(e1, [e2, ESEQ(s1, e3), e4])))
			== seq(s1, EXP(CALL(e1, [e2, e3, e4]))));
//	  assert(!commute(s1, e1N));
//		assert(do_stm(EXP(CALL(e1N, [e2, ESEQ(s1, e3), e4])))
//			== seq(MOVE(TEMP(_), e1N), seq(s1, EXP(CALL(TEMP(_), [e2, e3, e4])))));
//	assert(!commute(s1, e2N));
//	  assert(commute(s1, e1));
//		assert(do_stm(EXP(CALL(e1, [e2N, ESEQ(s1, e3), e4])))
//			== seq(MOVE(TEMP(_t2), e2N), seq(s1, EXP(CALL(e1, [TEMP(t2), e3, e4])))));
//	  assert(!commute(s1, e1N));
//		assert(do_stm(EXP(CALL(e1N, [e2N, ESEQ(s1, e3), e4])))
//			== seq(MOVE(TEMP(_t1), e1N), seq(MOVE(TEMP(_t2), e2N), seq(s1, EXP(CALL(TEMP(_t1), [TEMP(_t2), e3, e4]))))));
}

debug(canon)
unittest
{
	writefln("unittest @ %s:%s", __FILE__, __LINE__);
	scope(success) writefln("unittest succeeded @ %s:%s", __FILE__, __LINE__);
	
	Stm s1_;	Stm s1 = LABEL(newLabel());
	Stm s2_;	Stm s2 = LABEL(newLabel());
	Exp e1_;	Exp e1 = NAME(newLabel());
	
	// 1
	assert(do_exp(ESEQ(s1, ESEQ(s2, e1)))		== tuple(SEQ([s1, s2]), e1));
	
	
	assert(do_stm(EXP(ESEQ(s1,          e1 )))	== seq(    s1,      EXP(e1)));
	assert(do_stm(EXP(ESEQ(s1, ESEQ(s2, e1))))	== seq(seq(s1, s2), EXP(e1)));
	
	
	assert(linearize(EXP(ESEQ(s1, ESEQ(s2, e1))))	== [s1, s2, EXP(e1)]);
}
