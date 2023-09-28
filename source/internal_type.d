module internal_type;

import dynamic: Value_func;

import std.typecons: tuple;
import std.traits: getSymbolsByUDA, EnumMembers;
import std.meta;
import std.algorithm: map;
import std.array: array;
import std.conv: to;

struct byValuePointer(T) {
    import core.memory: moveToGC;
	T* address;
    alias value this;
    T value() => *address;
    void value(T new_value) => address = moveToGC(new_value);
}

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
    func,
    // slice,
    // structure,
    // sumtype,
    // c_union,
}// +/

alias Variants = AliasSeq!(
    Type_unresolved, Type_any, Type_unit, Type_type, Type_int_word,
    Type_boolean, Type_address, Type_func
);


union Variant_union {
    static foreach (i, Var; Variants ) {
        static assert (EnumMembers!Discriminant[i] == Var.id);
        static assert (Var.sizeof);
        mixin(Var.stringof ~ " variant_" ~ Var.id.to!string ~ ";");
    }
    Var var(Var)() {
        return mixin("variant_" ~ Var.id.to!string);
    }
    void var(Var)(Var value) {
        value = mixin("variant_" ~ Var.id.to!string);
    }
}

// The internal (hashable) representation of type
struct Type {
    import core.memory;
    bool is_const = true;
    Discriminant discriminant = Discriminant.unresolved;
    // Variant_union variant;

    this(Discriminant d) {
        discriminant = d;
    }

    static unresolved() => Type();
    static unit() => Type(Discriminant.unit);
    static any() => Type(Discriminant.any);
    static int_word() => Type(Discriminant.int_word);
    static type_type() => Type(Discriminant.type_type);
    static boolean() => Type(Discriminant.boolean);
    static address(Type base_type) {
        Type t = Type(Discriminant.address);
        // t.variant_address = Type_address(base_type);
        return t;
    }
    static func(Value_func func) {
        Type t = Type(Discriminant.func);
        // t.variant_address = Type_func(base_type);
        return t;
    }
    
    string c_usage() => throw new Error("Hold your horses!");
}



struct Type_type {
    enum id = Discriminant.type_type;
    // override string c_usage() => throw new Exception(
    //     "Type 'Type' cannot exit at runtime");
    // mixin impl_aakeys;
}

struct Type_any {
    enum id = Discriminant.any;
    Type[] type_held;
}

struct Type_unit {
    enum id = Discriminant.unit;
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
    // string c_usage() => 
    //     base_type.c_usage() ~ "*";
        
    this(Type base_type) {
        this.base_type = base_type;
    }

    void base_type(Type value) @property {_base_type = [value];}
    Type base_type() @property => _base_type[0];

    private Type[] _base_type = [];
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