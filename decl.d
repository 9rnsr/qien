module qien.decl;

import qien.expr;
import qien.id;
import qien.loc;
import qien.stmt;
import qien.visitor;

class Module
{
    Decl[] members;

    this(Decl[] members)
    {
        this.members = members;
    }

    void accept(Visitor v) { v.visit(this); }
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

    void accept(Visitor v) { v.visit(this); }
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

    override void accept(Visitor v) { v.visit(this); }
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

    override void accept(Visitor v) { v.visit(this); }
}

class TypeDecl : Decl
{
    Decl[] members;

    this(Loc loc, Id* ident, Decl[] members)
    {
        super(loc, ident);
        this.members = members;
    }

    override void accept(Visitor v) { v.visit(this); }
}

interface Codegen
{
    void codegen();
}

struct DeclTable
{
    Decl[Id*] aa;

    Decl lookup(Id* ident)
    {
        if (auto pd = ident in aa)
            return *pd;
        else
            return null;
    }

    Decl insert(Decl d)
    {
        if (auto pd = d.ident in aa)
            return null;    // already in there
        aa[d.ident] = d;
        return d;
    }
}
