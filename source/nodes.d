module nodes;

import std.sumtype;
import std.traits: getSymbolsByUDA, Largest, hasStaticMember;
import std.array: array;
import std.algorithm;
import std.format;
import pegged.grammar : ParseTree;
import codegen;
// import typechecking;

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
    static typeof(this) 
    create(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }
}

interface Expression : Struct_field {
    static typeof(this) 
    create(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }

    // string gen_c_expression();
}

interface Function_parameter {
    static typeof(this) 
    create(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }
}

interface Struct_field {
    static typeof(this) 
    create(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }
}

/// *** Subtypes ***

class Define_variable : Statement, Declaration {
    string name;
    Expression init;
    static typeof(this)
    create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        assert(node.children.length == 2);
        ret.name = Value_name.create(node.children[0]).name;
        ret.init = Expression.create(node.children[1]);
        return ret;
    }
    mixin Declaration.gen_c;
}

class Define_function : Statement, Declaration {

    string name;
    Function_parameter[] arguments_in;
    Function_parameter[] arguments_out;
    Statement[] block;


    static typeof(this) 
    create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        assert (node.children.length == 4);
        // int i = 0;
        ret.name = Value_name.create(node.children[0]).name;
        // i += 1;
        validate_node!"Prototype_argument_list"(node.children[1]);
        ret.arguments_in = node.children[1].children
            .map!(a => Function_parameter.create(a))
            .array;
            
        validate_node!"Prototype_argument_list"(node.children[2]);
        ret.arguments_out = node.children[2].children
            .map!(a => Function_parameter.create(a))
            .array;

        validate_node!"Statement_block"(node.children[3]);
        if (node.children[3].children.length == 1) {
            ret.block = node.children[3].children[0].children
                .map!(Statement.create)
                .array;
        }

        return ret;
    }

    mixin Declaration.gen_c;
}

class Declare_uninit : Function_parameter, Struct_field {
    string name;
    Expression type;
    
    static typeof(this) create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        assert(node.children.length == 2);
        ret.name = Value_name.create(node.children[0]).name;
        ret.type = Expression.create(node.children[1]);

        return ret;
    }
}

class Parameter_init : Function_parameter {}

class Compare : Expression {
    // static string[] compare_left  = ["!=" , "=", ">", ">="];
    // static string[] compare_right = ["!=" , "=", "<", "<="];
    byte direction = 0; // 0, 1, 2
    byte[] operators;    
    Expression[] items;

    static typeof(this) 
    create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        assert(node.children.length % 2 == 1);

        ret.items = [Expression.create(node.children[0])];
        int i = 1;
        string[] glyphs = ["!=", "="];
        while (i < node.children.length) {
            if (ret.direction == 0) {
                if (node.children[i].matches[0][0] == '>')  {
                    ret.direction = 1; 
                    glyphs = ["!=" , "=", ">", ">="];
                }
                else if (node.children[i].matches[0][0] == '<')  {
                    ret.direction = 2;
                    glyphs = ["!=" , "=", "<", "<="];
                }
            }
            byte operator = cast(byte) glyphs.countUntil(node.children[i].matches[0]);
            assert(operator != -1, format!"%s is not in %s"(node.children[i].matches[0], glyphs));
            ret.operators ~= operator;
            i += 1;
            ret.items ~= Expression.create(node.children[i]);
            i += 1;
        }

        return ret;
    }
}

class Struct : Expression {
    static typeof(this) 
    create (ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        assert(0);
        // validate_node!node_name(node);
        // assert(node.children.length == 1);
        // members
        // return ret;
    }
}
 
class Slice_type : Expression {
    Expression base;
    static typeof(this)
    create (ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.base = Expression.create(node.children[0]);
        return ret;
    }
}

class Value_name : Expression, Function_parameter {
    string name;
    static typeof(this) 
    create (ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.name = node.matches[0];
        return ret;
    }
}

class Type_annotation : Expression {
    Expression type;
    Expression value;
    static typeof(this) 
    create (ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        assert(node.children.length == 2);
        ret.type  = Expression.create(node.children[0]);
        ret.value = Expression.create(node.children[1]);
        return ret;
    }
}

class Function_call : Expression {
    Expression callee;
    Expression[] arguments;
    static create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        if (node.children[0].get_name == "Value_name") {
            ret.callee = Value_name.create(node.children[0]);
        } else {
            ret.callee = Grouping_expression.create(node.children[0]);
        }
        ret.arguments = node.children[1].children
            .map!(a => Expression.create(a))
            .array;
        return ret;
    }
}

class Indexing : Expression {
    Expression indexee;
    Expression index;
    static create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        if (node.children[0].get_name == "Value_name") {
            ret.indexee = Value_name.create(node.children[0]);
        } else {
            ret.indexee = Grouping_expression.create(node.children[0]);
        }
        ret.index = Expression.create(node.children[1]);
        return ret;
    }
}

class Lit_number : Expression {
    string representation;
    static create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.representation = node.matches[0];
        return ret;
    }
}

class Sum_op : Expression {
    Struct_field lhs;
    Struct_field rhs;
    static create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.lhs = Struct_field.create(node.children[0]);
        ret.rhs = Struct_field.create(node.children[1]);
        return ret;
    }
}

class Product_op : Expression {
    Struct_field lhs;
    Struct_field rhs;
    static create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.lhs = Struct_field.create(node.children[0]);
        ret.rhs = Struct_field.create(node.children[1]);
        return ret;
    }
}

class Op_or : Expression {
    Struct_field lhs;
    Struct_field rhs;
    static create(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.lhs = Struct_field.create(node.children[0]);
        ret.rhs = Struct_field.create(node.children[1]);
        return ret;
    }
}

class Grouping_expression : Expression {
    static create(ParseTree node) {
        return Expression.create(node.children[0]);
    }
}


/// *** Helper functions ***
private:

Super create_subtype(Super)(ParseTree node) {
    import std.traits: TemplateArgsOf;
    import std.conv;
    alias Node_types = Get_nodes!Super;

    ParseTree sub_node;

    if (get_name(node) == Super.stringof) {
        assert(node.children.length == 1, node.to!string);
        sub_node = node.children[0];
    } else {
        sub_node = node;
    }

    switch (get_name(sub_node)) {
        static foreach(Node_type; Node_types) {
            case Node_type.stringof:
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


template is_same(A) {
    bool is_same(B)() {return is(A == B);}
}


TypeInfo get_type_info(T)() {
    return typeid(T);
}


template Get_nodes(T) {
    alias Get_nodes = AliasSeq!();
    static foreach (name; __traits(allMembers, mixin(__MODULE__))) {
        static if (is(mixin(name) : T) 
                   && !is(mixin(name) == T)
                   && is(mixin(name) == class)) {
            static assert (hasStaticMember!(T, "create"), T.stringof);
            Get_nodes = AliasSeq!(Get_nodes, mixin(name));
        }
    }
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
