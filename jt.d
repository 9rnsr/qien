module jt;

public import T = tok;
public import P = parse;
public import S = semant;
public import M = machine;
import trans;
import assem, frame;
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
		debugout("========");
		debugout("parse = %s", p.toString);
		
		auto ty = S.semant(p);
		debugout("========");
		debugout("semant = %s", ty);
		
		auto fragments = trans.getResult().reverse;
		debugout("semant.frag[] = ");
		foreach (f; fragments){
			writefln("%s : ", f.p[1].name);
			f.debugOut();
			debugout("----");
		}
		
		debugout("========");
		debugout("instr[] = ");
		auto m = new M.Machine();
		m.assemble((void delegate(Frame, M.Instruction[]) send)
		{
			foreach (f; fragments)	//表示の見易さのため反転
			{
				auto stms = f.p[0];
				auto frame = f.p[1];
				
				scope m = new Munch();
				auto instr = m.munch(stms);
				
				send(frame, instr);
			}
		});
		
		debugout("========");
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


