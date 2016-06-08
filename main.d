module qien.main;

import core.stdc.stdio;

import qien.err;
import qien.file;
import qien.lex;

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
    debug printf(">>>%.*s\n<<<\n", f.buffer.length, f.buffer.ptr);

    auto lexer = Lexer(&f);
    while (!lexer.empty)
    {
        auto t = lexer.front;
        debug
        {
            if (t.value == TOK.identifier)
                printf("%d %.*s = %.*s\n", t.value, t.asstr.length, t.asstr.ptr, t.ident.asstr.length, t.ident.asstr.ptr);
            else if (t.value == TOK.integer)
                printf("%d %.*s = %llu\n", t.value, t.asstr.length, t.asstr.ptr, t.uns64value);
            else
                printf("%d %.*s\n", t.value, t.asstr.length, t.asstr.ptr);
        }
        lexer.popFront();
    }

    debug printf("succeed\n");

    return 0;
}

void usage()
{
    fprintf(stdout, "Qien compiler\n");
    fprintf(stdout, "Version 0.01\n");
    fprintf(stdout, "Copyright (C) 2016 Hara Kenji 2016  All rights reserved.\n");
}
