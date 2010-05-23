module tree;

static import temp;

import tok : IntT;
import std.typecons;
import std.conv;

template to(U : string)
{
	U to(T...)(T args){
		string result;
		foreach( arg; args ){
			result ~= std.conv.to!string(arg)~",";
		}
		return result[0..$-1];
	}
}

enum BinOp
{
	ADD,
	SUB,
	MUL,
	DIV,
	AND,
	OR,
	LSHIFT,
	RSHIFT,
	ARSHIFT,
	XOR,
}

enum Relop
{
	EQ,
	NE,
	LT,
	GT,
	LE,
	GE,
}

class Exp
{
private:
	enum Tag{
		VINT,VFUN,
		NAME,
		TEMP,
		BIN,
		MEM,
		CALL,
		ESEQ,
	}
	Tag tag;
	union{
		Tuple!(IntT)			i;
		Tuple!(Exp, temp.Label)	f;
		Tuple!(temp.Label)		n;
		Tuple!(temp.Temp)		t;
		Tuple!(BinOp, Exp, Exp)	b;
		Tuple!(Exp)				m;
		Tuple!(Exp, Exp[])		c;
		Tuple!(Stm, Exp)		e;
	}
	
	this(Tag t){
		tag = t;
	}
public:
	string toString(){
		auto tagname = to!string(tag);
		final switch( tag ){
		case Tag.VINT:	return tagname ~ "("~to!string(i.field)~")";
		case Tag.VFUN:	return tagname ~ "("~to!string(f.field)~")";
		case Tag.NAME:	return tagname ~ "("~to!string(n.field)~")";
		case Tag.TEMP:	return tagname ~ "("~to!string(t.field)~")";
		case Tag.BIN:	return tagname ~ "("~to!string(b.field)~")";
		case Tag.MEM:	return tagname ~ "("~to!string(m.field)~")";
		case Tag.CALL:	return tagname ~ "("~to!string(c.field)~")";
		case Tag.ESEQ:	return tagname ~ "("~to!string(e.field)~")";
		}
	}
}
Exp VINT(IntT i){
	auto x = new Exp(Exp.Tag.VINT);
	x.i = tuple(i);
	return x;
}
Exp VFUN(Exp fp, temp.Label lbl){
	auto x = new Exp(Exp.Tag.VFUN);
	x.f = tuple(fp, lbl);
	return x;
}
Exp NAME(temp.Label lbl){
	auto x = new Exp(Exp.Tag.NAME);
	x.n = tuple(lbl);
	return x;
}
Exp TEMP(temp.Temp tmp){
	auto x = new Exp(Exp.Tag.TEMP);
	x.t = tuple(tmp);
	return x;
}
Exp BIN(BinOp op, Exp l, Exp r){
	auto x = new Exp(Exp.Tag.BIN);
	x.b = tuple(op, l, r);
	return x;
}
Exp MEM(Exp exp){
	auto x = new Exp(Exp.Tag.MEM);
	x.m = tuple(exp);
	return x;
}
Exp CALL(Exp fun, Exp[] args){
	auto x = new Exp(Exp.Tag.CALL);
	x.c = tuple(fun, args);
	return x;
}
Exp ESEQ(Stm stm, Exp exp){
	auto x = new Exp(Exp.Tag.ESEQ);
	x.e = tuple(stm, exp);
	return x;
}

class Stm
{
private:
	enum Tag{
		MOVE,
		EXP,
		JUMP,
		CJUMP,
		SEQ,
		LABEL,
	}
	Tag tag;
	union{
		Tuple!(Exp, Exp)								m;
		Tuple!(Exp)										e;
		Tuple!(Exp, temp.Label[])						j;
		Tuple!(Relop, Exp, Exp, temp.Label, temp.Label)	c;
		Tuple!(Stm[])									s;
		Tuple!(temp.Label)								l;
	}
	this(Tag t){
		tag = t;
	}
public:
	string toString(){
		auto tagname = to!string(tag);
		final switch( tag ){
		case Tag.MOVE:	return tagname ~ "("~to!string(m.field)~")";
		case Tag.EXP:	return tagname ~ "("~to!string(e.field)~")";
		case Tag.JUMP:	return tagname ~ "("~to!string(j.field)~")";
		case Tag.CJUMP:	return tagname ~ "("~to!string(c.field)~")";
		case Tag.SEQ:	return tagname ~ "("~to!string(s.field)[1..$-1]~")";
		case Tag.LABEL:	return tagname ~ "("~to!string(l.field)~")";
		}
	}
}
Stm MOVE(Exp val, Exp to){
	auto s = new Stm(Stm.Tag.MOVE);
	s.m = tuple(val, to);
	return s;
}
Stm EXP(Exp exp){
	auto s = new Stm(Stm.Tag.EXP);
	s.e = tuple(exp);
	return s;
}
Stm JUMP(Exp exp, temp.Label[] lbl){
	auto s = new Stm(Stm.Tag.JUMP);
	s.j = tuple(exp, lbl);
	return s;
}
Stm CJUMP(Relop op, Exp cnd, Exp cnt, temp.Label t, temp.Label f){
	auto s = new Stm(Stm.Tag.CJUMP);
	s.c = tuple(op, cnd, cnt, t, f);
	return s;
}
Stm SEQ(Stm[] stmts...){
	auto s = new Stm(Stm.Tag.SEQ);
	s.s = tuple(stmts.dup);
	return s;
}
Stm LABEL(temp.Label lbl){
	auto s = new Stm(Stm.Tag.LABEL);
	s.l = tuple(lbl);
	return s;
}
