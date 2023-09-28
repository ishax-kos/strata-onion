module nodes;

import codegen;
import typechecking;
import symbols;
import dynamic;
import internal_type;

import pegged.grammar : ParseTree;

import std.traits: getSymbolsByUDA, Largest, hasStaticMember;
import std.array: array;
import std.algorithm;
import std.range;
import std.format;
import std.conv;
import std.exception: enforce;

import std.stdio;

class Module {
    Scope scope_;

    static typeof(this) 
    from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        ret.add_initial_symbols();
        validate_node!"File"(node);
        validate_node!"Statement_list"(node.children[0]);
        ret.scope_.statements = node.children[0].children
            .map!(a => Statement.from_pegged(a))
            .array;
        return ret;
    }
}


//$ *** Super Types ***

interface Statement {
    string[] gen_c_forward_declaration();
    string[] gen_c_statement(Scope context);
    static typeof(this) 
    from_pegged(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }
}

// interface Declaration {
// }

interface Expression : Struct_field {
    static typeof(this) 
    from_pegged(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }
    
    Type get_type(Scope context);
    string gen_c_expression(Scope context);
    Type determine_type(Scope context);// {return Type.unresolved;};
    Value evaluate(Scope context);
}

interface Function_parameter {
    static typeof(this) 
    from_pegged(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }
    string gen_c_parameter();
    string arg_name();
    Argument as_argument(Scope context);
    // bool semantics_valid();
}

interface Struct_field {
    static typeof(this) 
    from_pegged(ParseTree node) {
        return create_subtype!(typeof(this))(node);
    }
    // bool semantics_valid();
}

//$ *** Subtypes ***

abstract
class Grouping_expression : Expression {
    static from_pegged(ParseTree node) {
        return Expression.from_pegged(node.children[0]);
    }
    // bool is_type() => false;
}

class Assign : Statement {
    Expression lvalue;
    Expression rvalue;
    
    static typeof(this)
    from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        assert(node.children.length == 2);
        ret.lvalue = Expression.from_pegged(node.children[0]);
        ret.rvalue = Expression.from_pegged(node.children[1]);

        return ret;
    }
    
    string[] gen_c_forward_declaration () => [];
    string[] gen_c_statement(Scope context) => [format!"%s = %s;"(
        lvalue.gen_c_expression(context),
        rvalue.gen_c_expression(context),
    )];

    // bool semantics_valid() {
    //     Type ltype = lvalue.determine_type();
    //     // enforce(lvalue.is_lvalue);
    //     enforce(rvalue.check_type(ltype.check_type()));
    // }
}

class Define_variable : Statement {
    string name;
    Expression init;
    
    static typeof(this)
    from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        assert(node.children.length == 2);
        ret.name = Value_name.from_pegged(node.children[0]).name;
        ret.init = Expression.from_pegged(node.children[1]);
        return ret;
    }
    
    string[] gen_c_forward_declaration () => [format!"%s %s;"(
        Type.unresolved.c_usage,
        this.name.c_name
    )];
    string[] gen_c_statement(Scope context) => [format!"%s %s = %s;"(
        Type.unresolved.c_usage,
        this.name.c_name,
        this.init.gen_c_expression(context)
    )];
}

class Define_function : Statement {
    string name;
    Function_parameter[] arguments_in;
    Function_parameter[] arguments_out;
    Scope block;
    
    static typeof(this) 
    from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        assert (node.children.length == 4);
        // int i = 0;
        ret.name = Value_name.from_pegged(node.children[0]).name;
        // i += 1;
        validate_node!"Prototype_argument_list"(node.children[1]);
        ret.arguments_in = node.children[1].children
            .map!(a => Function_parameter.from_pegged(a))
            .array;
            
        validate_node!"Prototype_argument_list"(node.children[2]);
        ret.arguments_out = node.children[2].children
            .map!(a => Function_parameter.from_pegged(a))
            .array;

        validate_node!"Statement_block"(node.children[3]);
        if (node.children[3].children.length == 1) {
            ret.block.statements = node.children[3].children[0].children
                .map!(Statement.from_pegged)
                .array;
        }

        return ret;
    }

    string[] gen_c_forward_declaration () => [gen_c_prototype(this) ~ ";"];
    string[] gen_c_statement(Scope context) => 
        [gen_c_prototype(this) ~ " {"] ~ 
        gen_c_scope(this.block)[1..$];
}

class Declare_uninit : Function_parameter, Struct_field {
    string name;
    Expression type;
    
    static typeof(this) from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        assert(node.children.length == 2);
        ret.name = Value_name.from_pegged(node.children[0]).name;
        ret.type = Expression.from_pegged(node.children[1]);

        return ret;
    }
    override:
    string arg_name() => name;

    string gen_c_parameter() => 
        format!"%s %s"(
            Type.unresolved.c_usage, 
            this.name.c_name);

    Argument as_argument(Scope context) {
        Argument ret;
        Type_node t = cast(Type_node) type.evaluate(context);
        assert(t);
        ret.type = Argument_type(t.this_type);
        ret.name = name;
        return ret;
    }
}

class Value_name : Expression, Function_parameter {
    import std.uni: isUpper;
    string name;
    // private Type type = Type.unresolved;
    static typeof(this) 
    from_pegged (ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.name = node.matches[0];
        return ret;
    }
    // bool is_type() => name[0].isUpper;
    string arg_name() => name;

    string gen_c_parameter() => 
        format!"%s %s"(
            Type.unresolved.c_usage, 
            this.name.c_name);

    string gen_c_expression(Scope) => name.c_name;
    
    Type determine_type(Scope context) {
        // The type of an invoked identifier is allowed to be sussed out if it
        // Is not overloaded.
        return context.fetch_type(name);
    }

    private Type type = Type.unresolved;
    Type get_type(Scope context) {
        if (type == Type.unresolved) {
            type = determine_type(context);
        }
        return type;
    }

    Value evaluate(Scope context) {
        if (type == Type.unresolved) {
            throw new Error("Type could not be resolved before use.");
        }
        if (type != Type.type_type) {
            // throw new Error("Cant do that yet.");
        }
        return context.fetch_value(name, type);
    }

    Argument as_argument(Scope context) {
        Argument ret;
        ret.type = Argument_type(this.get_type(context));
        ret.name = name;
        return ret;
    }
}

class Lit_number : Expression {
    string representation;
    static from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.representation = node.matches[0];
        // debug { import std.stdio : writeln; try { writeln(ret.representation); } catch (Exception) {} }
        return ret;
    }

    // bool is_type() => false;
    
    string gen_c_expression(Scope) => representation
        .to!int
        .to!string
    ;
    
    bool check_type(Type, Scope) {return assert(0);};
    Type determine_type(Scope context) => Type.int_word;

    private Type type = Type.unresolved;
    Type get_type(Scope context) {
        if (type == Type.unresolved) {
            type = determine_type(context);
        }
        return type;
    }

    Value evaluate(Scope context) {
        // if (type == Type.unresolved) {
        //     type = determine_type(context);
        // }
        return new Value_int_word(representation);
    }
}

class Function_call : Expression {
    Expression callee;
    Expression[] arguments;

    static from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        if (node.children[0].get_name == "Value_name") {
            ret.callee = Value_name.from_pegged(node.children[0]);
        } else {
            ret.callee = Grouping_expression.from_pegged(node.children[0]);
        }
        ret.arguments = node.children[1].children
            .map!(a => Expression.from_pegged(a))
            .array; 
        return ret;
    }

    // bool is_type() => assert(0, "not implemented");
    
    private Type type = Type.unresolved;
    Type get_type(Scope context) {
        if (type == Type.unresolved) {
            type = determine_type(context);
        }
        return type;
    }

    string gen_c_expression(Scope context) {
        string callee_expr = callee.gen_c_expression(context);
        if (cast(Value_name) callee is null) {
            callee_expr = "(" ~ callee_expr ~ ")";
        }
        
        return format!"%s(%s)"(
            callee_expr,
            arguments
                .map!(n=>n.gen_c_expression(context))
                .joiner(", ")
                .to!string
        );
    }

    bool check_type(Type, Scope) {return assert(0);};
    Type determine_type(Scope context) {
        Value_func callee_func = 
            cast(Value_func) this.callee.evaluate(context);
        assert(callee_func);
        if (callee_func.arguments_out.length == 0) {
            return Type.unit;
        }
        else if (callee_func.arguments_out.length == 1) {
            Type ret_type = callee_func.arguments_out[0].type.type;
            assert(ret_type != Type.any && ret_type != Type.unresolved);
            return ret_type;
        }
        else {assert(0);}
    };

    Value evaluate(Scope context) {
        Value_func callee_func = 
            cast(Value_func) this.callee.evaluate(context);
        assert(callee_func !is null);
        Scope new_scope = context.spawn_nested(callee_func.block);
        foreach (i, callee_arg; callee_func.arguments_in) {
            new_scope.assign(
                callee_arg.name, 
                this.arguments[i].evaluate(context));
        }
        return callee_func.call(context);
    }
}

class Compare : Expression {
    enum Equalities : byte {not, equal, greater, greater_equal, less, less_equal}
    static string[] glyphs = ["!=", "=", ">", ">=", "<", "<="];
    // byte direction = 0; /// 0 =, 1 >, 2 <
    Equalities[] operators;
    Expression[] items;

    static typeof(this) 
    from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        assert(node.children.length % 2 == 1);
        byte direction = 0;
        ret.items = [Expression.from_pegged(node.children[0])];
        int i = 1;
        // string[] glyphs = ["!=", "="];
        while (i < node.children.length) {
            if (direction == 0) {
                if (node.children[i].matches[0][0] == '>')  {
                    direction = 1; 
                    // glyphs = ["!=" , "=", ">", ">="];
                }
                else if (node.children[i].matches[0][0] == '<')  {
                    direction = 2;
                    // glyphs = ["!=" , "=", "<", "<="];
                }
            }
            byte operator = cast(byte) glyphs.countUntil(
                node.children[i].matches[0]
            );
            assert(operator != -1, 
                format!"%s is not in %s"(node.children[i].matches[0],glyphs));
            ret.operators ~= cast(Equalities)operator;
            i += 1;
            ret.items ~= Expression.from_pegged(node.children[i]);
            i += 1;
        }
        return ret;
    }

    // bool is_type() => false;
    // private Type type = Type.unresolved;
    Type get_type(Scope) => Type.boolean;
    
    string gen_c_expression(Scope context) {
        string[] c_glyphs = ["!=", "==", ">", ">=", "<", "<="];
        if (items[0].get_type(context) == Type.type_type) {
            return evaluate(context).gen_c_expression(context);
        } else {
            return 
                zip(
                    items.map!(i=>i.gen_c_expression(context)).slide(2),
                    operators.map!(op => c_glyphs[cast(ulong) op])
                )
                .map!(tup => format!"(%s %s %s)"(tup[0][0], tup[1], tup[0][1]))
                .joiner(" && ")
                .to!string
            ;
        }
    }

    bool check_type(Type type, Scope) => (type == Type.boolean);
    Type determine_type(Scope) => Type.boolean;

    Value evaluate(Scope context) {
        Value initial = items[0].evaluate(context);
        Type key_type = initial.get_type(context);
        if (key_type == Type.int_word) {
            long[] eval_list = [(cast(Value_int_word) 
                items[0].evaluate(context)).value];
            bool and_accum = false;
            foreach (i, op; operators) {
                eval_list ~= (
                    cast(Value_int_word) 
                    items[0].evaluate(context)
                    ).value
                ;

                final switch (op) {
                    case Equalities.not: 
                        and_accum &= eval_list[i] != eval_list[i+1]; break;
                    case Equalities.equal:
                        and_accum &= eval_list[i] == eval_list[i+1]; break;
                    case Equalities.greater:
                        and_accum &= eval_list[i] >  eval_list[i+1]; break;
                    case Equalities.greater_equal:
                        and_accum &= eval_list[i] >= eval_list[i+1]; break;
                    case Equalities.less:
                        and_accum &= eval_list[i] <  eval_list[i+1]; break;
                    case Equalities.less_equal:
                        and_accum &= eval_list[i] <= eval_list[i+1]; break;
                }
            }
            return new Value_bool(and_accum);
        } else
        if (key_type == Type.type_type) {
            //...
        }
        throw new Error("We will get there when we get there.");
    }
}
/+
class Slice_type : Expression {
    Expression base;
    static typeof(this)
    from_pegged (ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.base = Expression.from_pegged(node.children[0]);
        return ret;
    }
    bool is_type() => true;

    string gen_c_expression() {
        assert(0, "needs to be rearanged to Type name[]");
        // return base.gen_c_expression ~ "var_name" ~ "[]";

    }
    
    bool check_type(Type) {return assert(0);};
    Type determine_type() {return Type.unresolved;};
}
+/
// class Annotation_of_type : Expression {
//     Expression type_given;
//     Expression value;
//     static typeof(this) 
//     from_pegged (ParseTree node) {
//         auto ret = new typeof(this);
//         validate_node!(typeof(this).stringof)(node);
//         assert(node.children.length == 2);
//         ret.type_given  = Expression.from_pegged(node.children[0]);
//         ret.value = Expression.from_pegged(node.children[1]);
//         return ret;
//     }
    
//     bool is_type() => 0
//         || (
//             cast(Value_name)type !is null 
//             && (cast(Value_name) type).name == "Type"
//         )
//         || value.is_type
//     ;

//     string gen_c_expression() => value.gen_c_expression();
    
//     bool get_type(Type) {
//         type_given.compute().as_type_t == Type.type_type;
//     };
//     Type determine_type() {
//         Type ret = type_given.compute().as_type_t;
//         if (value == )
//         enforce(value.check_type(ret));
//         return ret;
//     };
// }
/+
class Indexing : Expression {
    Expression indexee;
    Expression index;
    static from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        if (node.children[0].get_name == "Value_name") {
            ret.indexee = Value_name.from_pegged(node.children[0]);
        } else {
            ret.indexee = Grouping_expression.from_pegged(node.children[0]);
        }
        ret.index = Expression.from_pegged(node.children[1]);
        return ret;
    }

    bool is_type() => assert(0, "not implemented");

    string gen_c_expression() => 
        format!"index(%s, %s)"(indexee, index);
    
    bool check_type(Type) {return assert(0);};
    Type determine_type() {return Type.unresolved;};
}

class Sum_op : Expression {
    Struct_field[] operands;
    static from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.operands = node.children
            .map!(Struct_field.from_pegged)
            .array;
        return ret;
    }

    bool is_type () {
        if (auto val = cast(Expression) operands[0]) {
            return val.is_type;
        } else if (cast(Declare_uninit) operands[0]) {
            return true;
        } else {
            assert(0);
        }
    }
    
    string gen_c_expression() {
        auto expressions = operands.map!(n=>cast(Expression) n);
        assert(expressions.all!(n=>n !is null));
        return expressions.map!(n=>n.gen_c_expression)
            .joiner(" + ")
            .to!string
        ;
    }
    
    bool check_type(Type) {return assert(0);};
    Type determine_type() {return Type.unresolved;};
}

class Product_op : Expression {
    private Type type = Type.unresolved;
    Struct_field[] operands;
    static from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.operands = node.children
            .map!(Struct_field.from_pegged)
            .array;
        return ret;
    }

    // bool is_type () {
    //     if (auto val = cast(Expression) operands[0]) {
    //         return val.is_type;
    //     } else if (cast(Declare_uninit) operands[0]) {
    //         return true;
    //     } else {
    //         assert(0);
    //     }
    // }

    string gen_c_expression() {
        auto expressions = operands.map!(n=>cast(Expression) n);
        assert(expressions.all!(n=>n !is null));
        return expressions.map!(n=>n.gen_c_expression)
            .joiner(" * ")
            .to!string
        ;
    }
    
    bool check_type(Type) {return assert(0);};
    Type determine_type() {
        Type ret = Type.not_checked;
        foreach (item; operands) {
            Type item_type;
            if (auto val = cast(Expression) item) {
                item_type = val.determine_type();
            } else if (cast(Declare_uninit) item) {
                item_type = Type.type_type;
            } else {
                assert(0);
            }

            if (ret == Type.not_checked) {
                enforce(ret == item_type);
            }
        }
    };
}

class Op_or : Expression {
    Struct_field[] operands;
    static from_pegged(ParseTree node) {
        auto ret = new typeof(this);
        validate_node!(typeof(this).stringof)(node);
        ret.operands = node.children
            .map!(Struct_field.from_pegged)
            .array;
        return ret;
    }

    bool is_type () {
        if (auto val = cast(Expression) operands[0]) {
            return val.is_type;
        } else if (cast(Declare_uninit) operands[0]) {
            return true;
        } else {
            assert(0);
        }
    }

    string gen_c_expression() {
        auto expressions = operands.map!(n=>cast(Expression) n);
        assert(expressions.all!(n=>n !is null));
        return expressions.map!(n=>n.gen_c_expression)
            .joiner(" | ")
            .to!string
        ;
    }
    
    bool check_type(Type) {return assert(0);};
    Type determine_type() {return Type.unresolved;};
}
// +/

//$ *** Helper functions ***

Super create_subtype(Super)(ParseTree node) {
    import std.traits: TemplateArgsOf;
    import std.conv;
    alias Node_types = Subtypes!Super;

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
                return Node_type.from_pegged(sub_node);
        }
        default: 
            assert(0, msg_wrong_node(sub_node, "subtype of '"~Super.stringof~"'"));
    }
}


string msg_wrong_node(ParseTree node, string expected) {
    import std.format;
    return format!"Wrong node type '%s'. Expected %s."(get_name(node), expected);
}


// template is_same(A) {
//     bool is_same(B)() {return is(A == B);}
// }


// TypeInfo get_type_info(T)() {
//     return typeid(T);
// }


template Subtypes(T, alias module_ = nodes) {
    import std.meta;
    alias Subtypes = AliasSeq!();
    static foreach (name; __traits(allMembers, module_)) {
        static if (is(mixin(name) : T) 
                   && !is(mixin(name) == T)
                   && is(mixin(name) == class)) {
            // static assert (hasStaticMember!(T, "from_pegged"), T.stringof);
            Subtypes = AliasSeq!(Subtypes, mixin(name));
        }
    }
}
private:

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


// template get_children(T, string module_ = __MODULE__) {
//     alias get_children = AliasSeq!();
//     static foreach (s; __traits(allMembers, mixin(module_))) {
//         static if (__traits(compiles, (){mixin(s, " value");}()) 
//         && is(mixin(s) : T) && !is(mixin(s) == T)) {
//             get_children = AliasSeq!(get_children, mixin(s));
//         }
//     }
// }

unittest {
    import parse;

    import std.exception: assertThrown, assertNotThrown;
    
    parse_code("
        fun main (;args []String)() {
            ;my-var = do-stuff(
                a, 1, 2 + (2 * 4)[11]
                some-value
                who-needs-separators
            )
            my-var = 3
        }
        ;foobar = lol
        
    ");

    parse_code("
        ;foobar = Bool : T >= U
    ");
    parse_code("
        blah
        (1,2,3)
    ");
    assertThrown(parse_code("
        blah
        (1,2,3)
    "));
    
    assertThrown(parse_code("
        blah
        [1]
    "));
    
}

bool instance_of(T)(T value) if (is(T == class)) =>
    cast(T) value !is null;