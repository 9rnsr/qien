module jt;

public import T = tok;
public import P = parse;
public import S = semant;
import std.stdio;
import debugs;


int main(string[] args)
{
	if( args.length == 1 ){
		usage();
		return 0;
	}
	
	if( args.length == 2 ){
		auto fname = args[1];
		
		auto t = T.toknize(fname);
		
		auto p = P.parse(t);
		debugout("parse = %s", p.toString);
		
		auto ty = S.semant(p);
		debugout("semant = %s", ty);
		
//		auto e = eval(s);
		
	}
	
	return 0;
}


void usage()
{
	writefln("Usage:");
	writefln("  jt { options } [source_filename]");
	writefln("");
//	writefln("  -u,-unittest\trun unittests");
}


