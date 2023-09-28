module symbols;

import typechecking;
import nodes: Statement, Define_function, Define_variable, Module;
import dynamic: Value;
import internal_type: Type;

import std.sumtype;
import std.format;


// class Type_Type {}


struct Symbol {
    Overload[Type] overloads;
}

struct Overload {
    Value value;

    // Type type() {
    //     return value.type;
    // }
    string[] gen_c_declare();
}


class Scope {
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
            symbol.overloads[type] = value;
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
                format!"Symbol '%s' is overloaded and needs to"
                ~" be used with explicit typing."(name));
        }
        return symbol.overloads[type];
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
                format!"Symbol '%s' is overloaded and needs to"
                ~" be used with explicit typing."(name));
        }
        symbol.overloads.keys()[0];
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



void add_initial_symbols(Module module_context) {
    auto symbols = module_context.scope_.symbols;
    symbols["Int"] ~= Variable_signature("Int", Type.int_word);
    symbols["Void"] ~= Variable_signature("Void", Type.unit);
    symbols["void"] ~= Variable_signature("void", Value_void());
}


