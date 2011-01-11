module jt;

import lex;
import parse : parse;
import semant;
import trans;
import machine;
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
		run_program(fname);
	}
	
	return 0;
}

void run_program(string fname)
{
	auto tok = toknize(fname);
	auto ast = parse(tok);
	auto typ = semant.semant(ast);
	
	auto m = new Machine();
	m.assemble((void delegate(Frame, Instruction[]) send)
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
			
			auto old_stdout = stdout;
			scope(exit) stdout = old_stdout;
			
			auto outfile = addExt(`test\` ~ fname, "out.txt");
			stdout = File(outfile, "w+");
			
			run_program(`test\` ~ fname);
		}
	}
}
