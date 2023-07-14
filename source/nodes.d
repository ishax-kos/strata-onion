module nodes;

import std.sumtype;
import std.traits: getSymbolsByUDA, Largest;
import std.array: array;
import std.algorithm;
import pegged.grammar : ParseTree;

import std.stdio;

struct Module {
    Statement[] statements;

    this(ParseTree tree) {
        validate_node!"File"(tree);
        validate_node!"Statement_list"(tree.children[0]);
        this.statements = tree.children[0].children
            .map!(a => Statement(a))
            .array;
    }
}

struct Statement {
    alias Types = getSymbolsByUDA!(mixin(__MODULE__), "Statement");
    alias Sum = SumType!(Types);
    
    Sum value;
    
    this(ParseTree tree) {
        validate_node!"Statement"(tree);
        assert(tree.children.length == 1);

        ParseTree node = tree.children[0];
        SW: switch (node_name(node)) {
            static foreach(Type; Types) {
                case Type.node_name:
                    value = Type(node); 
                    break SW;
            }
            default: 
                assert(0, node_name(node));
        }
    }
}


@"Statement"
struct Define_variable {
    enum node_name = "Define_variable";
    string name;
    Ref!Type_expression type;
    Ref!Expression      init;

    this(ParseTree tree) {
        validate_node!node_name(tree);
        assert(tree.children.length == 2);
        writeln(node_name, " is not implemented");
        type = Type_expression(tree.children[0]);
        init = Expression(tree.children[1]);
    }
}


@"Statement"
struct Define_function {
    enum node_name = "Define_function";
    this(ParseTree node) {
        validate_node!"Define_function"(node);
        writeln(node_name, " is not implemented");
    }
}


struct Type_expression {
    enum node_name = "Type_expression";
    alias Types = getSymbolsByUDA!(typeof(this), "Type_expression");
    Multi_ref!"Type_expression" value;

    this(ParseTree tree) {
        validate_node!"node_name"(tree);
        assert(tree.children.length == 1);

        ParseTree node = tree.children[0];
        SW: switch (node_name(node)) {
            static foreach(Type; Types) {
                case Type.node_name:
                    value = Type(node); 
                    break SW;
            }
            default: 
                assert(0, node_name(node));
        }
    }

}

@"Type_expression"
struct Type_Name {
    string name;
}
@"Type_expression"
struct Union_xor {
    Aggregate_parameter[] members;
}
// struct Union_or {
//     Ref!Aggregate_parameter[] members;
// }
// struct Struct_and {
//     Ref!Aggregate_parameter[] members;
// }
// struct Array {}
// struct Pointer {}

@"Type_expression"
struct Aggregate_parameter {
    Multi_ref!(Type_expression, Value_name) value;
}

// struct Parameter {
//     string name;
//     string type;
// }

@"Statement"
struct Expression {
    enum node_name = "Expression";

    alias Types = Get_members!"Statement";
    alias Sum = SumType!Types;

    this(ParseTree tree) {
        writeln(node_name, " is not implemented");
    }

    @"value":
    struct Name {}
}


@"Expression"
struct Value_name {
    enum node_name = "name_value";
    this(ParseTree node) {
        validate_node!"Define_function"(node);
        writeln(node_name, " is not implemented");
    }
}


// alias get_types = getSymbolsByUDA(typeof(this))
template is_same(A) {
    bool is_same(B)() {return is(A == B);}
}

TypeInfo get_type_info(T)() {
    return typeid(T);
}

alias SumType(T...)             = std.sumtype.SumType!T;
alias SumType(string uda)       = SumType!(Get_members!uda);
// alias SumTypeRef(T...)          = SumType!(staticMap!(Ref, T));
// alias SumTypeRef(string uda)    = SumTypeRef!(Get_members!uda);

template Get_members(string uda) {
    alias Get_members = getSymbolsByUDA!(mixin(__MODULE__), uda);
    static assert(Get_members.length > 0, "'" ~ uda ~ "' has 0 members");
}

alias Multi_ref(string uda) = Multi_ref!(Get_members!uda);
struct Multi_ref(Types ...) {
    static TypeInfo[] type_info = [staticMap!(get_type_info, Types)];
    int type;
    void[width] data;

    void set_data(T)(T value) if (staticIndexOf!(T, Types) != -1) {
        type = staticIndexOf!(T, Types);
        *(cast(T*)&(data[0])) = value;
    }

    this(T)(T value) {
        this.set_data(value);
    }

    template match(handlers...) {
        auto match() {
            assert(ptr != null);
            return predicates[type](ptr);
        }
    }
    void opAssign(T)(T value) {
        this.set_data(value);
    }

    string toString() const @safe nothrow {
        return type_info[type].toString;
    }
}


struct Ref(T) {
    alias Ref_type = T*;
    
    Ref_type value;

    this(T value_) {
        this.value = new T();
        *(this.value) = value_;
    }

    ref T get() {
        assert(value != null);
        return *value;
    }

    string toString() const @safe pure {
        import std.conv;
        return (*value).to!string();
    }

    alias get this;
}


void validate_node(string name)(ParseTree tree) {
    assert(node_name(tree) == name);
}
string node_name(ParseTree tree) {
    import std.array: split;
    auto strings = tree.name.split('.');
    assert(strings.length == 2, tree.name);
    return strings[1];
}


import std.meta;
template get_children(T, string module_ = __MODULE__) {
    alias get_children = AliasSeq!();
    static foreach (s; __traits(allMembers, mixin(module_))) {
        static if (__traits(compiles, (){mixin(s, " value");}()) 
        && is(mixin(s) : T) && !is(mixin(s) == T)) {
            get_children = AliasSeq!(get_children, mixin(s));
        }
    }
}
