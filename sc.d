module qien.sc;

import qien.decl;
import qien.id;

struct Scope
{
    DeclTable tab;

    Scope* enclosing;

    FuncDecl func;

    this(Scope* enclosing)
    {
        this.enclosing = enclosing;
    }

    Scope* push()
    {
        return new Scope(&this);
    }

    Scope* pop()
    {
        return enclosing;
    }

    Decl search(Id* ident)
    {
        return null;
    }
}
