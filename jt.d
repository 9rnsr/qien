module jt;

public import T = tok;
public import P = parse;
public import S = semant;
public import M = machine;
import trans;
import assem;
import std.stdio;
import debugs;


int main(string[] args)
{
	if (args.length == 1)
	{
		usage();
		return 0;
	}
	
	if (args.length == 2)
	{
		auto fname = args[1];
		
		auto t = T.toknize(fname);
		
		auto p = P.parse(t);
		debugout("parse = %s", p.toString);
		
		auto ty = S.semant(p);
		debugout("semant = %s", ty);
		
		auto fragments = trans.getResult().reverse;
		debugout("semant.frag[] = ");
		foreach (f; fragments){
			f.debugOut();
			debugout("----");
		}
		
		debugout("instr[] = ");
		auto m = new M.Machine();
		m.assemble((void delegate(M.Instruction[]) send)
		{
			foreach (f; fragments)	//表示の見易さのため反転
			{
				scope m = new Munch();
				auto instr = m.munch(f.p.field[0]);
				
				send(instr);
			}
		});
		
		debugout("run = ");
		m.run();
		
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


