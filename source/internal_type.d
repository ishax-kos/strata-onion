module internal_type;

import dynamic: Value_func;
import myunion;

import std.typecons: tuple;
import std.traits: getSymbolsByUDA, EnumMembers;
import std.meta;
import std.algorithm: map;
import std.array: array;
import std.conv: to;
import std.sumtype;


// Note about self referencing things: You cant initialize arrays;


//+
private
enum Discriminant {
    unresolved,
    any,
    unit,
    type_type,
    int_word,
    boolean,
    address,
    slice,
    // structure,
    // sumtype,
    // c_union,
    func,
}// +/

alias Variants = AliasSeq!(
    Type_unresolved, Type_any, Type_unit, Type_type, Type_int_word,
    Type_boolean, 
    Type_address, 
    Type_func, 
    Type_slice
);


static foreach(T; Variants) {
    static assert(__traits(compiles, 
        (){ string s = T().c_usage(); }()
    ), T.stringof ~ " does not implement 'c_usage'");
}



struct Type {
    // The internal (hashable) representation of type
    import core.memory;
    bool is_const = true;
    // Discriminant discriminant = Discriminant.unresolved;
    SumType!Variants variant;


    static create(T, A...)(A args) {
        assert(staticIndexOf!(T, Variants) != -1);
        auto ret = Type();
        ret.variant = T(args);
        return ret;
    }
    
    string c_usage() {
        return variant.match!(
            (val) => val.c_usage()
        );
    }

    extern (D) size_t toHash() const nothrow @safe {
        return hashOf(variant);
    }

    bool opEquals(const Type other) const {
        return variant.opEquals(other.variant);
    }
    bool opEquals(ref const Type other) const {
        return variant.opEquals(other.variant);
    }
}



Type type_unresolved() => Type.create!Type_unresolved();
Type type_unit() => Type.create!Type_unit();
Type type_any() => Type.create!Type_any();
Type type_int_word() => Type.create!Type_int_word();
Type type_type() => Type.create!Type_type();
Type type_boolean() => Type.create!Type_boolean();
Type type_address(Type base_type) => Type.create!Type_address(base_type);
Type type_slice(Type base_type) => Type.create!Type_slice(base_type);
Type type_func(Value_func func) => Type.create!Type_func(func);


struct Type_type {
    enum id = Discriminant.type_type;
    string c_usage() => throw new Exception(
        "Type 'Type' cannot exit at C runtime");
    // mixin impl_aakeys;
}

struct Type_any {
    enum id = Discriminant.any;
    Type[] type_held;
    string c_usage() => throw new Exception("Any");
}

struct Type_unit {
    enum id = Discriminant.unit;
    string c_usage() => throw new Exception("Unit");
}

struct Type_unresolved {
    enum id = Discriminant.unresolved;
    string c_usage() => throw new Exception("Type is not resolved!");
    // mixin impl_aakeys;
}

struct Type_int_word {
    enum id = Discriminant.int_word;
    string c_usage() => "int";
    
}

struct Type_boolean {
    enum id = Discriminant.boolean;
    string c_usage() => "bool";
    
}

struct Type_address {
    enum id = Discriminant.address;
    string c_usage() => 
        base_type.c_usage() ~ "*";
        
    this(Type base_type) {
        this.base_type = base_type;
    }

    void base_type(Type value) @property {_base_type = [value];}
    Type base_type() @property => _base_type[0];

    private Type[] _base_type;
}

struct Type_func {
    enum id = Discriminant.func;
    string c_usage() => throw new Error("idk lol");

    string name;
    Argument_type[] arguments_in;
    Argument_type[] arguments_out;

    this(Value_func func) {
        arguments_in  = func.arguments_in.map !(a => a.type).array;
        arguments_out = func.arguments_out.map!(a => a.type).array;
        name = func.name;
    }
}
struct Argument_type {
    Type type;
}


struct Type_slice {
    enum id = Discriminant.slice;
    
    
    this(Type base_type) {
        this.base_type = base_type;
    }

    void base_type(Type value) @property {_base_type = [value];}
    Type base_type() @property => _base_type[0];

    private Type[] _base_type;

    string c_usage() => throw new Error("Holy trigger me Elmo, Batman!");
}

