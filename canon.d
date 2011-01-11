module canon;

import sym;
import T = tree;
import typecons.match;
import std.typecons, std.typetuple;
import debugs;

//debug = canon;

T.Stm[] linearize(T.Stm s)
{
	static T.Stm[] linear(T.Stm s, T.Stm[] l)
	{
		T.Stm[] sl;
		if (T.SEQ[&sl] <<= s)
			return linear(sl[0], linear(sl[1], l));
	    else
			return s ~ l;
	}
	return linear(do_stm(s), []);
}



T.Stm seq(T.Stm x, T.Stm y)
{
	if (T.EXP[T.VINT[_]] <<= x) return y;
	if (T.EXP[T.VINT[_]] <<= y) return x;
	return T.SEQ([x,y]);
}

bool commute(T.Stm s, T.Exp e)
{
	if (T.EXP[T.VINT[_]] <<= s) return true;
	if (T.NAME[_] <<= e) return true;
	if (T.VINT[_] <<= e) return true;
	return false;
}

Tuple!(T.Stm, T.Exp[]) reorder(T.Exp[] el)
{
	auto nop = T.EXP(T.VINT(0));

	if (el.length == 0)
		return tuple(nop, (T.Exp[]).init);
	else
	{
		auto a = el[0];
		auto rest = el[1..$];
		
		if (T.CALL[_,_] <<= a)
		{
			auto t = newTemp();
			return reorder(T.ESEQ(T.MOVE(T.TEMP(t), a), T.TEMP(t)) ~ rest);
		}
		else
		{
			T.Stm s1, s2;
			T.Exp e;
			tie[s1, e] <<= do_exp(a);
			tie[s2, el] <<= reorder(rest);
			if (commute(s2, e))
				return tuple(seq(s1, s2), e~el);
			else
			{
				auto t = newTemp();
				return tuple(seq(seq(s1, T.MOVE(T.TEMP(t), e)), s2), T.TEMP(t) ~ el);
			}
		}
	}
}

Tuple!(T.Stm, T.Exp) reorder_exp(EL, BLD)(EL el_, BLD build)
{
	T.Stm   s;
	T.Exp[] el;
	tie[s, el] <<= reorder(cast(T.Exp[])el_);
	return tuple(s, callBuild(el, build));
}

T.Stm reorder_stm(EL, BLD)(EL el_, BLD build)
{
	T.Stm   s;
	T.Exp[] el;
	tie[s, el] <<= reorder(cast(T.Exp[])el_);
	return seq(s, callBuild(el, build));
}

private{
	template isExp(E){ enum isExp = is(E == T.Exp); }
	R callBuild(R, TE...)(T.Exp[] el, R delegate(TE) build)
	{
		static assert(TE.length>=1);
		static if (allSatisfy!(isExp, TE[0..$-1], T.Exp) && is(TE[$-1] == T.Exp[]))
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

Tuple!(T.Stm, T.Exp) do_exp(T.Exp e)
{
	T.Stm	s;
	T.Exp	a, b;
	T.Exp[]	el;
	T.BinOp	op;
	
	return match(e,
		T.BIN[&op,&a,&b],{
			return reorder_exp([a,b], (T.Exp a, T.Exp b){ return T.BIN(op,a,b); });
		},
		T.MEM[&a],{
			return reorder_exp([a], (T.Exp a){ return T.MEM(a); });
		},
		T.ESEQ[&s,&e],{
			auto s0 = do_stm(s);
			tie[s, e] <<= do_exp(e);
			return tuple(seq(s0, s), e);
		},
		T.CALL[&e,&el],{
			return reorder_exp(e~el, (T.Exp e, T.Exp[] el){ return T.CALL(e,el); });
		},
		_,{
			return reorder_exp([], (T.Exp[] _){ return e; });
		}
	);
}

T.Stm do_stm(T.Stm s)
{
	Temp	r;
	Label	t, f;
	Label[]	ll;
	T.Exp	e, a, b;
	T.Exp[]	el;
	T.Stm[]	sl;
	T.Relop	rop;
	
	return match(s,
		T.MOVE[T.TEMP[&r],T.CALL[&e,&el]],{
			return reorder_stm(e~el, (T.Exp e, T.Exp[] el){ return T.MOVE(T.TEMP(r),T.CALL(e,el)); });
		},
		T.MOVE[T.TEMP[&r],&b],{
			return reorder_stm([b], (T.Exp e){ return T.MOVE(T.TEMP(r), e); });
		},
		T.MOVE[T.MEM[&e],&b],{
			return reorder_stm([e,b], (T.Exp e, T.Exp b){ return T.MOVE(T.MEM(e), b); });
		},
		T.MOVE[T.ESEQ[&s,&e],&b],{
			return do_stm(seq(s,T.MOVE(e,b)));
		},
		T.EXP[T.CALL[&e,&el]],{
			return reorder_stm(e~el, (T.Exp e, T.Exp[] el){ return T.EXP(T.CALL(e,el)); });
		},
		T.EXP[&e],{
			return reorder_stm([e], (T.Exp e){ return T.EXP(e); });
		},
		T.JUMP[&e, &ll],{
			return reorder_stm([e], (T.Exp e){ return T.JUMP(e, ll); });
		},
		T.CJUMP[&rop,&a,&b,&t,&f],{
			return reorder_stm([a,b], (T.Exp a, T.Exp b){ return T.CJUMP(rop,a,b,t,f); });
		},
		T.SEQ[&sl],{
			return seq(do_stm(sl[0]), do_stm(sl[1]));
		},
		_,{
			return reorder_stm([], (T.Exp[] _){ return s; });
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
