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

