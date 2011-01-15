module jt;

import lex;
import parse : parse;
import semant, trans;
import assem, frame, machine;
import std.stdio, std.getopt, std.file, std.path;
import debugs;


int main(string[] args)
{
	bool doTestSuite = false;
	bool printHelp = false;
	
	getopt(args,
		config.caseSensitive,
		"testsuite|t", &doTestSuite,
		"help|?", &printHelp);
	
	if (printHelp)
		return usage();
	
	if (doTestSuite)
		return run_test();
	
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

int usage()
{
	enum helpmsg = q"EOS
Usage:
  jt { options } [source_filename]

Options:
  --testsuite,-t    run test suite
  --help,-?         print help
EOS";

	write(helpmsg);

	return 0;
}

int run_test()
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
	return 0;
}
