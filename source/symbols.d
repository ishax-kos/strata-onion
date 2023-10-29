module symbols;


import nodes: Statement, Define_function, Define_variable, Module;
import dynamic: Value;
import internal_type;

import std.sumtype;
import std.format;


// class Type_Type {}


struct Symbol {
    Overload[Type] overloads;
}

struct Overload {
    Type value;
}


class Scope: Statement {
    import nodes;
    Scope parent;
    Statement[] statements;
    private Symbol[string] symbols;
    string[][] forward_c_declarations;

    this(Statement[] block, Scope new_parent) {
        statements = block;
        parent = new_parent;
    }

    Scope spawn_nested(Statement[] block) {
        return new Scope(block, this);
    }

    // typeof(this) instance_function_block(Scope parent, Argument[] arguments) {
    //     Scope ret = new Scope(block, this);
        
    //     // auto copy = new Scope(this);
    //     // copy.statements = this.statements;
    //     // copy.symbols.dup;
    //     // return copy;
    // }
    
    void add(string name, Value value) {
        Type type = value.get_type(this);
        if (name in symbols) {
            if (type in symbols[name].overloads) {
                throw new Error(
                    format!"Symbol '%s' already defined with type %s"(
                        name, type));
            }
            symbols[name].overloads[type] = Overload(value);
        }
        else {
            symbols[name] = Symbol([type: Overload(value)]);
        }
    }
    
    void add(string name, Type type) {
        if (name in symbols) {
            if (type in symbols[name].overloads) {
                throw new Error(
                    format!"Symbol '%s' already defined with type %s"(
                        name, type));
            } 
            symbols[name].overloads[type] = Overload(value);
        }
        else {
            symbols[name] = Symbol([type: Overload(value)]);
        }
    }

    void assign(string name, Value value) {
        Type type = value.get_type(this);
        if (name !in symbols) {
            throw new Error(
                format!"Symbol '%s' not defined!"(
                    name));
        }
        else {
            Symbol symbol = symbols[name];
            if (symbol.overloads.length > 1) {
                throw new Exception(
                    "Updating overloaded symbols is not yet supported");
            }
            symbol.overloads[type].value = value;
        }
    }
    

    Value fetch_value(string name, Type type) {
        if (name !in symbols) {
            if (parent) {
                return parent.fetch_value(name, type);
            }
            else {
                throw new Error(format!"Symbol '%s' not defined"(name));
            }
        }
        Symbol symbol = symbols[name];
        if (symbol.overloads.length > 1) {
            throw new Error(
                format!("Symbol '%s' is overloaded and needs to"
                ~" be used with explicit typing.")(name));
        }
        return symbol.overloads[type].value;
    }

    Type fetch_type(string name) {
        if (name !in symbols) {
            if (parent) {
                return parent.fetch_type(name);
            }
            else {
                throw new Error(format!"Symbol '%s' not defined"(name));
            }
        }
        Symbol symbol = symbols[name];
        if (symbol.overloads.length > 1) {
            throw new Error(
                format!("Symbol '%s' is overloaded and needs to"
                ~" be used with explicit typing.")(name));
        }
        return symbol.overloads.keys()[0];
    }

    string[] gen_c_statement(Scope context) {
        import codegen;
        import std.algorithm: map, joiner;

        assert(context == parent);
        string[] pre_declare = [];
        foreach (name, symbol; symbols) {
            if (symbol.overloads.length == 1) {
                Type t = fetch_type(name);
                pre_declare ~= format!"%s %s;"(t.c_usage, name);
            }
            string type_suffix;
            foreach (overload_type, _o; symbol.overloads) {
                pre_declare ~= format!"%s %s_%s;"(
                    overload_type.c_usage, name, overload_type.c_usage);
            }
        }
        return pre_declare ~
        lines(
            "{",
                statements.map!(n => n.gen_c_statement(this)).joiner(),
            "}"
        );
    }
}

// class Function_literal : Expression {
// }

// Function_literal get_func(Define_function def) {
//     auto ret = new Function_literal();
//     ret.arguments_in = def.arguments_in;
//     ret.arguments_out = def.arguments_out;
//     ret.block = def.block;
// }



void add_initial_symbols(Scope global_context) {
    import dynamic;

    global_context.add("Int", new Type_node(type_int_word));
    global_context.add("Void", new Type_node(type_unit));
    global_context.add("void", new Value_unit());
}


