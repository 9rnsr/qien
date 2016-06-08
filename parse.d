module qien.parse;

import qien.lex;
import qien.file;

struct Parser
{
    Lexer lexer;

    this(File* f)
    {
        this.lexer = Lexer(f);
    }
}
