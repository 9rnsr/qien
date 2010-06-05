module canon;

static import temp;
import T = tree;
import tree;
import typecons.tuple_match;
import typecons.tuple_tie;
import std.traits;
import std.typetuple;

import debugs;


Stm[] linearize(Stm s)
{
	Stm[] linear(Stm s, Stm[] l){
		Stm[] sl;
		if( T.SEQ(&sl) = s ){
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
	if( T.EXP(T.VINT(_)) = s ) return true;
	if( T.NAME(_) = e ) return true;
	if( T.VINT(_) = e ) return true;
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
		
		if( T.CALL(_, _) = a ){
			auto t = temp.newTemp();
			return reorder(T.ESEQ(T.MOVE(T.TEMP(t), a), T.TEMP(t)) ~ rest);
		}else{
			Stm s1, s2;
			Exp e;
			tie(s1, e) = do_exp(a);
			tie(s2, el) = reorder(rest);
			if( commute(s2, e) ){
				return tuple(seq(s1, s2), e~el);
			}else{
				auto t = temp.newTemp();
				return tuple(seq(seq(s1, T.MOVE(T.TEMP(t), e)), s2), T.TEMP(t) ~ el);
			}
		}
	}
}

/+private template Expand(alias A, size_t N, E...)
{
	static if( E.length == 0 ){
		alias TypeTuple!() field;
	}else static if( is(E[0] U == U[]) ){
		enum field = Tuple!(A[N..A.length]);
	}else{
		alias Tuple!(A[N], Expand!(A, N+1, E[1..$]).field) field;
	}
}+/

private template isExp(E){ enum isExp = is(E == Exp); }

Tuple!(Stm, Exp) reorder_exp(EL, TE...)(EL el_, Exp delegate(TE) build)
  if( is(EL==void[]) || is(EL==Exp[]) )
in{
	static if( TE.length == 1 && is(TE[0] == Exp[]) ){
	}else{
		static if( is(TE[$-1]==Exp[]) )	static assert(allSatisfy!(isExp, TE[0..$-1]));
		else							static assert(allSatisfy!(isExp, TE[0..$]));
	}
}body{
	Stm   s;
	Exp[] el = cast(Exp[])el_;
	tie(s, el) = reorder(el);
	
	//return tuple(s, build(Expand!(el, 0, TE).field));
	static if( TE.length == 1 ){
		static if( is(TE[$-1]==Exp[]) )	return tuple(s, build(el[0..$]));
		else							return tuple(s, build(el[0]));
	}
	static if( TE.length == 2 ){
		static if( is(TE[$-1]==Exp[]) )	return tuple(s, build(el[0], el[1..$]));
		else							return tuple(s, build(el[0], el[1]));
	}
	static if( TE.length >= 3 ) static assert(0);
}
/+Tuple!(Stm, Exp) reorder_exp(Exp[] xs, Exp delegate(Exp[]) b){
	return tuple(Stm.init, Exp.init);//todo
}+/

Stm reorder_stm(EL, TE...)(EL el_, Stm delegate(TE) build)
  if( is(EL==void[]) || is(EL==Exp[]) )
in{
	static if( TE.length == 1 && is(TE[0] == Exp[]) ){
	}else{
		static if( is(TE[$-1]==Exp[]) )	static assert(allSatisfy!(isExp, TE[0..$-1]));
		else							static assert(allSatisfy!(isExp, TE[0..$]));
	}
}body{
	Stm s;
	Exp[] el = cast(Exp[])el_;
	tie(s, el) = reorder(el);
	
	//return seq(s, build(Expand!(el, 0, TE).field));
	static if( TE.length == 1 ){
		static if( is(TE[$-1]==Exp[]) ){
			return seq(s, build(el[0..$]));
		}else{
//			pp("reorder_stm, s={");
//			debugout(s);
//			pp("}, el[0]={");
//			debugout(el[0]);
//			pp("}");
			return seq(s, build(el[0]));
		}
	}
	static if( TE.length == 2 ){
		static if( is(TE[$-1]==Exp[]) )	return seq(s, build(el[0], el[1..$]));
		else							return seq(s, build(el[0], el[1]));
	}
	static if( TE.length >= 3 ) static assert(0);
}
/+Stm reorder_stm(Exp[] xs, Stm delegate(Exp[]) b){
	Exp e;
	Stm s, s1;
	foreach( x; xs ){
		if( ESEQ(&s, &e) = x ){
		//	tie(s1, e) = reorder_exp([e]);
		}else{
		}
	}
	return null;//todo
}+/

Stm do_stm(Stm s)
{
	temp.Temp		r;
	temp.Label		t, f;
	temp.Label[]	ll;
	Exp		e, a, b;
	Exp[]	el;
	Stm[]	sl;
	Relop rop;
	
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
//			pp("EXP(&e){");
//			debugout(e);
//			pp("}");
			auto ret = reorder_stm([e], (E e){
//				pp("EXP(&e).reorder/build{");
//				debugout(e);
//				pp("}");
				return EXP(e); });
//			pp("EXP(&e), ret={");
//			debugout(ret);
//			pp("}");
			return ret;
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
	Stm	s;
	Exp	a, b;
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
	assert(do_exp(ESEQ(s1, ESEQ(s2, e1)))		== tuple(SEQ([s1, s2]), e1)		);
	
	
	//debugout(do_stm(EXP(ESEQ(s1, ESEQ(s2, e1)))));
	assert(do_stm(EXP(ESEQ(s1, e1)))			== seq(s1, EXP(e1)));
	//debugout(do_stm(EXP(ESEQ(s1, ESEQ(s2, e1)))));
	assert(do_stm(EXP(ESEQ(s1, ESEQ(s2, e1))))	== seq(seq(s1, s2), EXP(e1))	);
	
	
	assert(linearize(EXP(ESEQ(s1, ESEQ(s2, e1))))	== [s1, s2, EXP(e1)]	);
}
