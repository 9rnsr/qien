module tree;

static import temp;

import tok : IntT;
import std.typecons;
import std.conv;
import debugs;
import sym;		//alias名に対してtag_unionは上手く動作してくれない

import typecons.tag_union;


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
	mixin TagUnion!(
		"VINT",	IntT,
		"VFUN",	Exp, temp.Label,
		"NAME",	temp.Label,
		"TEMP",	temp.Temp,
		"BIN", 	BinOp, Exp, Exp,
		"MEM", 	Exp,
		"CALL",	Exp, Exp[],
		"ESEQ",	Stm, Exp
	);
public:
	void debugOut(TreeOut tout){
		auto tagname = to!string(tag);
		final switch( tag ){
		case Tag.VINT:	return tout(tagname, data0.tupleof[1..$]);
		case Tag.VFUN:	return tout(tagname, data1.tupleof[1..$]);
		case Tag.NAME:	return tout(tagname, data2.tupleof[1..$]);
		case Tag.TEMP:	return tout(tagname, data3.tupleof[1..$]);
		case Tag.BIN:	return tout(tagname, data4.tupleof[1..$]);
		case Tag.MEM:	return tout(tagname, data5.tupleof[1..$]);
		case Tag.CALL:	return tout(tagname, data6.tupleof[1..$]);
		case Tag.ESEQ:	return tout(tagname, data7.tupleof[1..$]);
		}
	}
}
mixin(Exp.Tycons!());

class Stm
{
	mixin TagUnion!(
		"MOVE",	Exp, Exp,
		"EXP",	Exp,
		"JUMP",	Exp, temp.Label[],
		"CJUMP",Relop, Exp, Exp, temp.Label, temp.Label,
		"SEQ",	Stm[],
		"LABEL",temp.Label
	);
public:
	void debugOut(TreeOut tout){
		auto tagname = to!string(tag);
		final switch( tag ){
		case Tag.MOVE:	return tout(tagname, data0.tupleof[1..$]);
		case Tag.EXP:	return tout(tagname, data1.tupleof[1..$]);
		case Tag.JUMP:	return tout(tagname, data2.tupleof[1..$]);
		case Tag.CJUMP:	return tout(tagname, data3.tupleof[1..$]);
		case Tag.SEQ:	return tout(tagname, data4.tupleof[1..$]);
		case Tag.LABEL:	return tout(tagname, data5.tupleof[1..$]);
		}
	}
}
mixin(Stm.Tycons!());
