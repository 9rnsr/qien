module main;

import parse, semant, assem, machine;
import frame;
import std.stdio, std.getopt, std.file, std.path;


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

ulong run_program(string fname)
{
	auto ast = parseProg(fname);
	auto frg = transProg(ast);
	auto prg = munchProg(frg);
	auto m = new Machine(prg);
	return m.run();
}

int usage()
{
	enum helpmsg = q"EOS
Usage:
  qien { options } [source_filename]

Options:
  --testsuite,-t    run test suite
  --help,-?         print help
EOS";

	write(helpmsg);

	return 0;
}

int run_test(string dir = "test")
{
	auto resdir = dir ~ "_results";
	if (!resdir.exists)
		mkdir(resdir);
	
	foreach (fname; listdir(dir))
	{
		if (fname.getExt == "qi")
		{
			auto outfile = resdir ~ sep ~ fname.addExt("log");
			writef("[] %s (%s) -> ", fname, outfile);
			
			auto old_stdout = stdout;
			stdout = File(outfile, "w+");
			scope(exit) stdout = old_stdout;
			
			try{
				auto rv = run_program(`test\` ~ fname);
				old_stdout.writefln("%s", cast(long)rv);
			}catch(Throwable e){
				writefln("%s", e);
				old_stdout.writefln("failed : %s", e);
			}
		}
	}
	return 0;
}
