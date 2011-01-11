module tree;

import sym;
import typecons.tagunion;
import std.conv, std.typecons;
import debugs;


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
		"VINT",	long,
		"VFUN",	Exp, Label,
		"NAME",	Label,
		"TEMP",	Temp,
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
	
	override bool opEquals(Object o)
	{
		if( auto e = cast(Exp)o ){
			if( tag != e.tag ) return false;
			
			final switch( tag ){
			case Tag.VINT:	foreach( i,t; data0.tupleof ) if( data0.tupleof[i] != e.data0.tupleof[i] ) return false;		break;
			case Tag.VFUN:	foreach( i,t; data1.tupleof ) if( data1.tupleof[i] != e.data1.tupleof[i] ) return false;		break;
			case Tag.NAME:	foreach( i,t; data2.tupleof ) if( data2.tupleof[i] != e.data2.tupleof[i] ) return false;		break;
			case Tag.TEMP:	foreach( i,t; data3.tupleof ) if( data3.tupleof[i] != e.data3.tupleof[i] ) return false;		break;
			case Tag.BIN:	foreach( i,t; data4.tupleof ) if( data4.tupleof[i] != e.data4.tupleof[i] ) return false;		break;
			case Tag.MEM:	foreach( i,t; data5.tupleof ) if( data5.tupleof[i] != e.data5.tupleof[i] ) return false;		break;
			case Tag.CALL:	foreach( i,t; data6.tupleof ) if( data6.tupleof[i] != e.data6.tupleof[i] ) return false;		break;
			case Tag.ESEQ:	foreach( i,t; data7.tupleof ) if( data7.tupleof[i] != e.data7.tupleof[i] ) return false;		break;
			}
			return true;
		}
		return false;
	}
}
mixin Exp.tycons;

class Stm
{
	mixin TagUnion!(
		"MOVE",	Exp, Exp,
		"EXP",	Exp,
		"JUMP",	Exp, Label[],
		"CJUMP",Relop, Exp, Exp, Label, Label,
		"SEQ",	Stm[],
		"LABEL",Label,
		"CLOS",	Label
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
		case Tag.CLOS:	return tout(tagname, data6.tupleof[1..$]);
		}
	}
	
	override bool opEquals(Object o)
	{
		if( auto s = cast(Stm)o ){
			if( tag != s.tag ) return false;
			
			final switch( tag ){
			case Tag.MOVE:	foreach( i,t; data0.tupleof ) if( data0.tupleof[i] != s.data0.tupleof[i] ) return false;		break;
			case Tag.EXP:	foreach( i,t; data1.tupleof ) if( data1.tupleof[i] != s.data1.tupleof[i] ) return false;		break;
			case Tag.JUMP:	foreach( i,t; data2.tupleof ) if( data2.tupleof[i] != s.data2.tupleof[i] ) return false;		break;
			case Tag.CJUMP:	foreach( i,t; data3.tupleof ) if( data3.tupleof[i] != s.data3.tupleof[i] ) return false;		break;
			case Tag.SEQ:	foreach( i,t; data4.tupleof ) if( data4.tupleof[i] != s.data4.tupleof[i] ) return false;		break;
			case Tag.LABEL:	foreach( i,t; data5.tupleof ) if( data5.tupleof[i] != s.data5.tupleof[i] ) return false;		break;
			case Tag.CLOS:	foreach( i,t; data6.tupleof ) if( data6.tupleof[i] != s.data6.tupleof[i] ) return false;		break;
			}
			return true;
		}
		return false;
	}
}
mixin Stm.tycons;
