module debugs;

public import std.string	: format;
public import std.conv		: to;

import std.stdio : writefln;
import std.stdio : write;
import std.conv;
import std.string : repeat;
import std.traits : ParameterTypeTuple;

void debugout(T...)(T args) if( (T.length==1 || T.length>=3) && is(T[0] : string) ){
	writefln(args);
}
T[1] debugout(T...)(T args) if( (T.length==2) && is(T[0] : string) ){
	writefln(args);
	return args[1];
}
T debugout(T)(T arg) if( __traits(compiles, arg.debugOut) ){
	alias ParameterTypeTuple!(typeof(arg.debugOut)) Prms;
	static if( Prms.length==1 && is(Prms[0] == TreeOut) ){
		void put(string s){ write(s); };
		
		arg.debugOut(tree_out(&put, 0));
		put("\n");
	}else{
		static assert(0);
	}
	return arg;
}

private TreeOut tree_out(void delegate(string) dg, size_t lv){
	TreeOut dout;
	dout.raw_put = dg;
	dout.level = lv;
	return dout;
}

/**
 * future improvement issues:
 * 	空リスト/配列に対する表示
 * 		[
 * 		]
 * 		----
 * 		[]
 * 	子要素を持たないXを1つだけ持つ要素の表示
 * 		(header
 * 			X
 * 		)
 * 		----
 * 		(header X)
 */
struct TreeOut
{
	enum ParenL = "(";
	enum ParenR = ")";
	enum InlineCloseParen = true;
	enum InlineSimpleNode = InlineCloseParen && true;
	
	enum tab = "  ";
	
	void delegate(string) raw_put;
	size_t level = 0;
	
	void opCall(T...)(lazy T args){
		//pragma(msg, T.stringof);
		
		static if( InlineSimpleNode && args.length==2 && !(__traits(compiles, args[1]().debugOut) || is(typeof(args[1]) U == U[])) ){
			enum InlineSimpleNode2 = true;
		}else{
			enum InlineSimpleNode2 = false;
		}
		
		void put1(U)(void delegate(string) raw_put, size_t lv, size_t i, U arg){
			static if( __traits(compiles, arg.debugOut) ){
				alias ParameterTypeTuple!(typeof(arg.debugOut)) Prms;
				static if( Prms.length==1 && is(Prms[0] == TreeOut) ){
					if( i == 0 ) raw_put("\n");
					arg.debugOut(tree_out(raw_put, lv));
				}else{
					static assert(0);
				}
			}else{
				if( InlineSimpleNode2 && i==1 ){
					raw_put(" ");
				}else if( i != 0 ){
					raw_put(repeat(tab, lv));
				}else{
					//do nothing
				}
				
				static if( is(typeof(arg) == string) ){
					raw_put(arg);
				}else static if( is(typeof(arg) U == U[]) ){
					raw_put("[");
					if( !arg.length ){
						static if( !InlineCloseParen ) raw_put("\n");
					}else{
						foreach( j, e; arg ){
							put1(raw_put, lv+1, j, e);
							if( !InlineCloseParen || j!=arg.length-1 ) raw_put("\n");
						}
					}
					static if( !InlineCloseParen ) raw_put(repeat(tab, lv));
					raw_put("]");
				}else{
					raw_put(to!string(arg));
				}
			}
			
		}
		
		raw_put(repeat(tab, level));
		raw_put(ParenL);
		foreach( i,arg; args ){
			put1(raw_put, level+1, i, args[i]());
			
			static if( InlineCloseParen && i==args.length-1 ){
				//do nothing
			}else static if( InlineSimpleNode2 && i==0 ){
				//do nothing
			}else{
				raw_put("\n");
			}
		}
		static if( !InlineCloseParen ) raw_put(repeat(tab, level));
		raw_put(")");
	}
}



import std.typecons, std.traits, std.typetuple;
import parse, trans, T = tree;
import frame, assem, machine;

struct Ast2Stm
{
	Frame frame;
	AstNode node;
}
Ast2Stm[T.Stm] ast_to_stm;

struct Frame2Instr
{
	Instr[] prologue;
	Tuple!(AstNode, T.Stm, Instr[])[] bodycode;
	Instr[] epilogue;
}
Frame2Instr[Frame] frame_to_instr;

void debugCodeMap(Level lv, AstNode n, Ex x)
{
	// private field にアクセス
//	auto frame = __traits(getMember, lv, "frame");	// 駄目
	auto frame = lv.tupleof[staticIndexOf!(Frame, FieldTypeTuple!Level)];
	ast_to_stm[unNx(x)] = Ast2Stm(frame, n);
}
void debugCodeMap(T.Stm stm, Instr[] instr)
{
	if (auto ps = stm in ast_to_stm)
	{
		if (ps.frame in frame_to_instr)
			frame_to_instr[ps.frame].bodycode ~= tuple(ps.node, stm, instr);
		else
			frame_to_instr[ps.frame] = Frame2Instr(null, [tuple(ps.node, stm, instr)], null);
	}
}
Instr[] debugCodeMapPrologue(Frame frame, Instr[] instr)
{
	frame_to_instr[frame].prologue = instr;
	return instr;
}
Instr[] debugCodeMapEpilogue(Frame frame, Instr[] instr)
{
	frame_to_instr[frame].epilogue = instr;
	return instr;
}
void debugCodeMapPrint()
{
	writefln("/*****************************");
	writefln(" * statement to instructions");
	writefln(" *****************************/");
	foreach (f, f2i; frame_to_instr)
	{
		writefln("Frame.name : %s", f.name);
		writefln("--");
		(new Machine(f2i.prologue)).print();
		foreach (tup; f2i.bodycode)
		{
			auto n = tup[0];
			auto stm = tup[1];
			auto instr = tup[2];
			writefln("%s:%s %s", n.pos.line+1, n.pos.column+1, n.toShortString);
		//	debugout(stm);
			(new Machine(instr)).print();
		}
		writefln("--");
		(new Machine(f2i.epilogue)).print();
		writefln("----");
	}
	writefln("========\n");
}
