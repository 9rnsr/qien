module canon;

import temp, tree;
import typecons.tuple_match, typecons.tuple_tie;
import std.traits;

import debugs;


Stm[] linearize(Stm s)
{
	Stm[] linear(Stm s, Stm[] l){
		Stm[] sl;
		if( SEQ(&sl) = s ){
			return linear(sl[0],linear(sl[1],l));
	    }else{
			return s~l;
		}
	}
	return linear(do_stm(s), []);
}



Stm seq(Stm x, Stm y)
{
	if( EXP(VINT(_)) = x ) return y;
	if( EXP(VINT(_)) = y ) return x;
	return SEQ([x,y]);
}

bool commute(Stm s, Exp e)
{
	if( EXP(VINT(_)) = s ) return true;
	if( NAME(_) = e ) return true;
	if( VINT(_) = e ) return true;
	else	return false;
}

Tuple!(Stm, Exp[]) reorder(Exp[] el)
{
	auto nop = EXP(VINT(0L));

	if( el.length == 0 ){
		return tuple(nop, (Exp[]).init);
	}else{
		auto a = el[0];
		auto rest = el[1..$];
		
		if( CALL(_, _) = a ){
			auto t = temp.newTemp();
			return reorder(ESEQ(MOVE(TEMP(t), a), TEMP(t)) ~ rest);
		}else{
			Stm s1, s2;
			Exp e;
			tie(s1, e) = do_exp(a);
			tie(s2, el) = reorder(rest);
			if( commute(s2, e) ){
				return tuple(seq(s1, s2), e~el);
			}else{
				auto t = temp.newTemp();
				return tuple(seq(seq(s1, MOVE(TEMP(t), e)), s2), TEMP(t) ~ el);
			}
		}
	}
}

Tuple!(Stm, Exp) reorder_exp(EL, BLD)(EL el_, BLD build)
{
	Stm   s;
	Exp[] el;
	tie(s, el) = reorder(cast(Exp[])el_);
	return tuple(s, callBuild(el, build));
}

Stm reorder_stm(EL, BLD)(EL el_, BLD build)
{
	Stm   s;
	Exp[] el;
	tie(s, el) = reorder(cast(Exp[])el_);
	return seq(s, callBuild(el, build));
}

private{
	template isExp(E){ enum isExp = is(E == Exp); }
	R callBuild(R, TE...)(Exp[] el, R delegate(TE) build)
	{
		static assert(TE.length>=1);
		static if( allSatisfy!(isExp, TE[0..$-1], Exp) && is(TE[$-1] == Exp[]) ){
			static if( TE.length == 1 )	return build(el[0..$]);
			static if( TE.length == 2 )	return build(el[0], el[1..$]);
			static if( TE.length >= 3 ) static assert(0);
		}
		else static if( allSatisfy!(isExp, TE[0..$]) ){
			static if( TE.length == 1 )	return build(el[0]);
			static if( TE.length == 2 )	return build(el[0], el[1]);
			static if( TE.length >= 3 ) static assert(0);
		}
		else{
			static assert(0);
		}
	}
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
	
	alias Exp E;
	
	return match(s,
		MOVE(TEMP(&r),CALL(&e,&el)),{
			return reorder_stm(e~el, (E e, E[] el){ return MOVE(TEMP(r),CALL(e,el)); });
		},
		MOVE(TEMP(&r), &b),{
			return reorder_stm([b], (E e){ return MOVE(TEMP(r), e); });
		},
		MOVE(MEM(&e), &b),{
			return reorder_stm([e,b], (E e, E b){ return MOVE(MEM(e), b); });
		},
		EXP(CALL(&e,&el)),{
			return reorder_stm(e~el, (E e, E[] el){ return EXP(CALL(e,el)); });
		},
		EXP(&e),{
			return reorder_stm([e], (E e){ return EXP(e); });
		},
		JUMP(&e, &ll),{
			return reorder_stm([e], (E e){ return JUMP(e, ll); });
		},
		CJUMP(&rop,&a,&b,&t,&f),{
			return reorder_stm([a,b], (E a, E b){ return CJUMP(rop,a,b,t,f); });
		},
		SEQ(&sl),{
			return seq(do_stm(sl[0]), do_stm(sl[1]));
		},
		_,{
			return reorder_stm([],(E[] _){ return s; });
		}
	);
	
}

Tuple!(Stm, Exp) do_exp(Exp e)
{
	Stm		s;
	Exp		a, b;
	Exp[]	el;
	BinOp	op;
	
	alias Exp E;
	
	return match(e,
		BIN(&op,&a,&b),{
			return reorder_exp([a,b], (E a, E b){ return BIN(op,a,b); });
		},
		MEM(&a),{
			return reorder_exp([a], (E a){ return MEM(a); });
		},
		ESEQ(&s,&e),{
			auto s0 = do_stm(s);
			tie(s, e) = do_exp(e);
			return tuple(seq(s0, s), e);
		},
		CALL(&e,&el),{
			return reorder_exp(e~el, (E e, E[] el){ return CALL(e,el); });
		},
		_,{
			return reorder_exp([], (E[] _){ return e; });
		}
	);
}
unittest
{
	pp("unittest: canon");
	
	Stm s1_;	Stm s1 = LABEL(temp.newLabel());
	Stm s2_;	Stm s2 = LABEL(temp.newLabel());
	Exp e1_;	Exp e1 = NAME(temp.newLabel());	
	
	// 1
	assert(do_exp(ESEQ(s1, ESEQ(s2, e1)))		== tuple(SEQ([s1, s2]), e1));
	
	
	assert(do_stm(EXP(ESEQ(s1,          e1 )))	== seq(    s1,      EXP(e1)));
	assert(do_stm(EXP(ESEQ(s1, ESEQ(s2, e1))))	== seq(seq(s1, s2), EXP(e1)));
	
	
	assert(linearize(EXP(ESEQ(s1, ESEQ(s2, e1))))	== [s1, s2, EXP(e1)]);
}
