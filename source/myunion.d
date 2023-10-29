module myunion;

import std.traits: Largest;
import std.meta: staticIndexOf, AliasSeq;

alias Null = typeof(null);

struct Tagged_union(Variant_types...) {
    alias This = typeof(this);
	Narrow_uint!(Variant_types.length) tag;
    void[size_of!(Largest!Variant_types)] data;
    
    static foreach(Type; Variant_types) {
        this(Type new_variant) {
            enum number = var!Type;
            tag = number;
            data[0..size_of!Type] = 
                (cast(void*) &new_variant)[0..size_of!Type];
        }
    }
    template var(Type) {
    	enum var = staticIndexOf!(Type, Variant_types);
    	static assert(var != -1);
    }
    
    Type as(Type)() const @safe pure nothrow 
    if (size_of!Type == 0) {
        enum number = var!Type;
        if (size_of!Type < Type.sizeof) {
            return Type();
        }
        
        return *(cast(Type*) &data);
    }
    ref Type as(Type)() const @safe pure nothrow 
    if (size_of!Type >= Type.sizeof) {
        enum number = var!Type;
        return *(cast(Type*) &data);
    }
    void as(Type)(Type new_val) const @safe pure nothrow 
    if (size_of!Type == 0) {
        enum number = var!Type;
    }

    bool test(Type)() {
        enum number = var!Type;
        return number == tag;
    }


    // string toString() const @safe pure nothrow {
    //     switch (this.tag) {
    //         static foreach (Type; Variant_types) {
    //             case This.var!Type: {
    //                 Type val = this.as!Type;
    //                 return val.to!string;
    //             }
    //         }
    //         default: return This.stringof;
    //     }
    // }
}


template Narrow_uint(ulong max_value) {
	alias Int_types = AliasSeq!(ubyte, ushort, uint, ulong);
    int get_index()() {
        foreach (i, T; Int_types) {
            if (T.max >= max_value) {return i;}
        }
        assert(0);
    }
    alias Narrow_uint = Int_types[get_index()];
}

int size_of(T)() {
    static if (is(T == struct) && T.tupleof.length == 0) {
        return 0;
    }
    else static if (is(T == typeof(null))) {
        return 0;
    }
    else {
        return T.sizeof;
    }
}


alias Expression = Tagged_union!(Sum, int);
struct Sum {
    Expression[] terms;

    string toString()  {
        return "Sums";
    }
}

unittest {
    Expression[] block = [
        Expression(5), 
        Expression(Sum([
            Expression(4),
            Expression(Sum([Expression(1), Expression(2)]))
        ]))
    ];
    // writeln(Expression(Sum([Expression(1), Expression(2)])));
    // foreach (expr; block) {
    //     switch (expr.tag) {
    //         case Expression.var!int: writeln(expr.as!int); break;
    //         case Expression.var!Sum: writefln!"%s"(expr.as!Sum); break;
    //         default: break;
    //     }
    // }
}