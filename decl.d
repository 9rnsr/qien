module qien.decl;

import qien.expr;
import qien.id;
import qien.lex;
import qien.stmt;

class Module
{
    Decl[] members;

    this(Decl[] members)
    {
        this.members = members;
    }
}

class Decl
{
    Loc loc;
    Id* ident;

    this(Loc loc, Id* ident)
    {
        this.loc = loc;
        this.ident = ident;
    }
}

class FuncDecl : Decl//, Codegen
{
    Loc endLoc;
    VarDecl[] fparams;
    Stmt sbody;

    this(Loc loc, Loc endLoc, Id* ident, VarDecl[] fparams, Stmt sbody)
    {
        super(loc, ident);
        this.endLoc = endLoc;
        this.fparams = fparams;
        this.sbody = sbody;
    }
}

class VarDecl : Decl//, Codegen
{
    Id* ident;
    Expr einit;

    this(Loc loc, Id* ident, Expr einit)
    {
        super(loc, ident);
        this.einit = einit;
    }
}

class TypeDecl : Decl
{
    Decl[] members;

    this(Loc loc, Id* ident, Decl[] members)
    {
        super(loc, ident);
        this.members = members;
    }
}

interface Codegen
{
    void codegen();
}
