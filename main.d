module qien.main;

import core.stdc.stdio;

import qien.err;
import qien.file;
import qien.parse;
import qien.semant;

int main(string[] args)
{
    if (args.length <= 1)
    {
        usage();
        return 1;
    }

    auto f = File(args[1]);
    if (f.read())
    {
        error("cannot find file %.*s", f.path.length, f.path.ptr);
        return 1;
    }
    //debug printf(">>>%.*s\n<<<\n", f.buffer.length, f.buffer.ptr);

    auto p = Parser(&f);
    auto m = p.parseModule();

    //debug printf("succeed\n");

    debug
    {
        import qien.printer;
        printer(m);
    }

    runSemant(m);

    return 0;
}

void usage()
{
    fprintf(stdout, "Qien compiler\n");
    fprintf(stdout, "Version 0.01\n");
    fprintf(stdout, "Copyright (C) 2016 Hara Kenji 2016  All rights reserved.\n");
}
