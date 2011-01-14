module jt;

import lex;
import parse : parse;
import semant, trans;
import assem, frame, machine;
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
		run_program(fname);
	}
	
	return 0;
}

void run_program(string fname)
{
	trans.initialize();
	
	auto tok = toknize(fname);
	auto ast = parse(tok);
	auto typ = transProg(ast);
	
	auto m = new Machine();
	m.assemble((void delegate(Frame, Instr[]) send)
	{
		foreach (f; trans.getResult())
		{
			auto stms = f.p[0];
			auto frame = f.p[1];
			
			scope m = new Munch();
			auto instr = m.munch(stms);
			
			send(frame, instr);
		}
	});
	
	m.run();
}


void usage()
{
	writefln("Usage:");
	writefln("  jt { options } [source_filename]");
	writefln("");
//	writefln("  -u,-unittest\trun unittests");

	run_test();
}


import std.file, std.path, std.stdio;

void run_test()
{
	foreach (fname; listdir("test"))
	{
		if (fname.getExt == "jt")
		{
			writefln("[] %s", fname);
			
			auto outfile = addExt(`test\` ~ fname, "out.txt");
			
			auto old_stdout = stdout;
			stdout = File(outfile, "w+");
			scope(exit) stdout = old_stdout;
			
			run_program(`test\` ~ fname);
		}
	}
}
