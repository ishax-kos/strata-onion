module nodes;

import std.sumtype;
import std.traits: getSymbolsByUDA, Largest;
import std.array: array;
import std.algorithm;
import std.format;
import pegged.grammar : ParseTree;

import std.stdio;

class Module {
    Statement[] statements;

    static typeof(this) 
    create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!"File"(node);
        validate_node!"Statement_list"(node.children[0]);
        ret.statements = node.children[0].children
            .map!(a => Statement.create(a))
            .array;
        return ret;
    }
}


// *** Super Types ***

interface Statement {
    enum node_name = "Statement";
    static typeof(this) 
    create(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }
}

@Statement
interface Value_expr : Statement {
    enum node_name = "Value_expr";
    static typeof(this) 
    create(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }
}

interface Type_expr {
    enum node_name = "Type_expr";
    static typeof(this) 
    create(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }
}


interface Function_parameter {
    enum node_name = "Function_parameter";
    static typeof(this) 
    create(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }
}

// *** Subtypes ***

@Statement
class Define_variable : Statement {
    enum node_name = "Define_variable";
    string name;
    Value_expr init;

    static typeof(this) 
    create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!node_name(node);
        assert(node.children.length == 2);
        ret.name = Value_name.create(node.children[0]).name;
        ret.init = Value_expr.create(node.children[1]);
        return ret;
    }
}


@Statement
class Define_function : Statement {
    enum node_name = "Define_function";

    string name;
    Function_parameter[] arguments_in;
    Function_parameter[] arguments_out;
    Statement[] block;


    static typeof(this) 
    create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!"Define_function"(node);
        int i = 0;
        ret.name = Value_name.create(node.children[i]).name;
        i += 1;
        validate_node!"Prototype_argument_list"(node.children[i]);
        ret.arguments_in = node.children[i].children
            .map!(a => Function_parameter.create(a))
            .array;
        i += 1;

        if (node.children.length == 4) {
            validate_node!"Prototype_argument_list"(node.children[i]);
            ret.arguments_out = node.children[i].children
                .map!(a => Function_parameter.create(a))
                .array;
            i += 1;
        } else {
            assert(node.children.length == 3);
        }

        validate_node!"Statement_list"(node.children[i]);
        ret.block = node.children[i].children
            .map!(Statement.create)
            .array;
        return ret;
    }
}
@Function_parameter
class Declare_value : Function_parameter {
    enum node_name = "Declare_value";
    string name;
    Type_expr type;
    
    

    static typeof(this) create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!"Declare_value"(node);
        ret.name = Value_name.create(node.children[0]).name;
        if (node.children.length == 2) {
            ret.type = Type_expr.create(node.children[1]);
        } else {
            ret.type = null;
        }

        return ret;
    }
}

@Type_expr
class Type_Name : Type_expr {
    enum node_name = "type_name";
    string name;

    static typeof(this) 
    create(ParseTree node) {
        auto ret = new typeof(this);
        return ret;
    }
}

@Type_expr
class Struct : Type_expr {
    enum node_name = "Struct";
    // Aggregate_field[] members;
    static typeof(this) 
    create (ParseTree node) {
        auto ret = new typeof(this);
        assert(0);
        // validate_node!node_name(node);
        // assert(node.children.length == 1);
        // members
        // return ret;
    }
}
@Type_expr
class Slice_type : Type_expr {
    enum node_name = "Slice_type";
    Type_expr base;
    static typeof(this)
    create (ParseTree node) {
        auto ret = new typeof(this);
        validate_node!node_name(node);
        ret.base = Type_expr.create(node.children[0]);
        return ret;
    }
}
/+
@"Type_expr" final
struct Union_xor {
    enum node_name = "Union_xor";
    Aggregate_field[] members;
}
@"Type_expr" final
struct Struct_and {
    enum node_name = "Struct_and";
    Aggregate_field[] members;
}
struct Array {}
struct Pointer {}


@"Type_expr" final
struct Aggregate_field {
    // enum node_name = "Aggregate_field";
    // SumTypeRef!(Type_expr, Value_name) value;
    // this(ParseTree node) {
    //     writeln(node_name, " is not implemented");
    // }
}
+/




@Value_expr
class Value_name : Value_expr {
    enum node_name = "value_name";
    string name;
    static typeof(this) 
    create (ParseTree node) {
        auto ret = new typeof(this);
        validate_node!node_name(node);
        ret.name = node.input;
        return ret;
    }
}

@Value_expr
class Type_annotation : Value_expr {
    enum node_name = "Type_annotation";
    Type_expr type;
    Value_expr value;
    static typeof(this) 
    create (ParseTree node) {
        auto ret = new typeof(this);
        validate_node!node_name(node);
        assert(node.children.length == 2);
        ret.type  = Type_expr .create(node.children[0]);
        ret.value = Value_expr.create(node.children[1]);
        return ret;
    }
}
@Value_expr
class Function_call : Value_expr {
    enum node_name = "Function_call";
    string name;
    Value_expr[] arguments;
    static create(ParseTree node) {
        auto ret = new Function_call;
        validate_node!node_name(node);
        ret.name = Value_name.create(node.children[0]).name;
        ret.arguments = node.children[1].children
            .map!(a => Value_expr.create(a))
            .array;
        return ret;
    }
}

/+
struct Value_or_type {
    enum node_name = "Value_or_type";
    alias Node_types = AliasSeq!(Value_expr, Type_expr);
    // SumTypeRef!(Value_expr, Type_expr) value;

    // mixin get_sum;
}
// +/

// *** Helper functions ***
private:

Super create_subtype(Super)(ParseTree node) {
    import std.traits: TemplateArgsOf;
    import std.conv;
    alias Node_types = Get_members!Super;
    pragma(msg, Super);
    pragma(msg, Node_types);

    ParseTree sub_node;

    if (get_name(node) == Super.node_name) {
        assert(node.children.length == 1, node.to!string);
        sub_node = node.children[0];
    } else {
        sub_node = node;
    }

    switch (get_name(sub_node)) {
        static foreach(Node_type; Node_types) {
            case Node_type.node_name:
                return Node_type.create(sub_node);
        }
        default: 
            assert(0, msg_wrong_node(sub_node, "subtype of '"~Super.stringof~"'"));
    }
}


string msg_wrong_node(ParseTree node, string expected) {
    import std.format;
    return format!"Wrong node type '%s'. Expected %s."(get_name(node), expected);
}

// alias get_types = getSymbolsByUDA(typeof(this))
template is_same(A) {
    bool is_same(B)() {return is(A == B);}
}

TypeInfo get_type_info(T)() {
    return typeid(T);
}

// alias SumType(T...)             = std.sumtype.SumType!T;
// alias SumType(string uda)       = SumType!(Get_members!uda);
// alias SumTypeRef(T...) = SumType!(staticMap!(Ref, T));
// template SumTypeRef(T...) {
//     SumTypeRef!T SumTypeRef(A)(A value) if (staticIndexOf!(A, T) != -1) {
//         return SumTypeRef!T(Ref!A(value));
//     }
// } 
// alias SumTypeRef(string uda)    = SumTypeRef!(Get_members!uda);

template Get_members(Uda) {
    alias Get_members = getSymbolsByUDA!(mixin(__MODULE__), Uda);
    static assert(Get_members.length > 0, "name '" ~ Uda.stringof ~ "' has 0 members");
}


// template Get_members(T) {
//     alias Get_members = AliasSeq!();
//     static foreach (name; __traits(allMembers, mixin(__MODULE__))) {
//         static if (__traits(compiles, mixin(name))) {
//             static if (is(mixin(name) : T) && !is(mixin(name) == T) && is(mixin(name) == class)) {
//                 Get_members = AliasSeq!(Get_members, mixin(name));
//             }
//         }
//     }
// }


struct Ref(T) {
    alias Ref_type = T*;
    
    Ref_type value;

    this(T value_) {
        this.value = new T();
        *(this.value) = value_;
    }

    // this(A...)(A args) {
    //     // pragma(msg, A);
    //     this.value = new T(args);
    // }

    ref T get() {
        assert(value != null);
        return *value;
    }

    // string toString() const {
    //     import std.conv;
    //     return (*value).to!string();
    // }

    alias get this;
}


void validate_node(string name)(ParseTree node) {
    assert(get_name(node) == name, msg_wrong_node(node, "'"~name~"'"));
}

string get_name(ParseTree node) {
    import std.array: split;
    import std.conv;
    auto strings = node.name.splitter('.');
    strings.popFront();
    assert(!strings.empty, node.name);
    return strings.front.splitter('!').front;
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


unittest {
    import parse;
    import std.format;
    string code = "
        fun main (args []String)() {
            ;my-var = do-stuff(
                a, 1, 2 + (2 * 4)
                some-value
                who-needs-separators
            )
        }
        ;foobar = lol
    ";

    ParseTree gram = parse.parse(code);
    assert(gram.successful, format!"%s\n\n%s"(code, gram));
    writeln(gram);
    auto mod = Module.create(gram.children[0]);

    code = "
        blah
        (1,2,3)
    ";
    gram = parse.parse(code);
    assert(!gram.successful, format!"%s\n\n%s"(code, gram));
    code = "
        blah
        [1]
    ";
    gram = parse.parse(code);
    assert(!gram.successful, format!"%s\n\n%s"(code, gram));
    
}

string toString(T)(T value) {
    static if (is(T == A[], A)) {
        import std.conv;
        return value.to!string;
    }
    else {
        return T.stringof ~ value.tupleof.toString;

    }
}