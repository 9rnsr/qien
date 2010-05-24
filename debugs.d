module debugs;

public import std.string	: format;
public import std.conv		: to;

import std.stdio : writefln;
import std.conv;
void debugout(T...)(T args) if( (T.length==1 || T.length>=3) && is(T[0] : string) ){
	writefln(args);
}
T[1] debugout(T...)(T args) if( (T.length==2) && is(T[0] : string) ){
	writefln(args);
	return args[1];
}


import std.string;
import std.traits;

TreeOut tree_out(void delegate(string) dg, size_t lv=0){
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
	void delegate(string) raw_put;
	size_t level = 0;
	
	void opCall(T...)(lazy T args){
		//pragma(msg, T.stringof);
		foreach( i,arg; args ){
			auto lv = (i==0 || i==args.length-1) ? level : level+1;
			
			static if( is(typeof(args[i]) == string) ){
				//debugout(">><%s> %s len=%s, i=%s", T.stringof, args[i](), args.length, i);
				raw_put(repeat("  ", lv) ~ args[i]());
			}else static if( is(typeof(args[i]) U == U[]) ){
				auto nest = tree_out(raw_put, lv+1);
				raw_put(repeat("  ", lv) ~ "[");
				foreach( j, e; args[i] ){
					nest(e);
				}
				raw_put(repeat("  ", lv) ~ "]");
			}else static if( __traits(compiles, args[i]().debugOut) ){
				alias ParameterTypeTuple!(typeof(args[i]().debugOut)) Prms;
				static if( Prms.length==1 && is(Prms[0] == TreeOut) ){
					//pragma(msg, "has tree_out : " ~ typeof(args[i]()).stringof);
					args[i]().debugOut(tree_out(raw_put, lv));
				}else{
					static assert(0);
				}
			}else{
				raw_put(repeat("  ", lv) ~ to!string(args[i]()));
			}
		}
	}
}


