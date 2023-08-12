module symbols;

import typechecking;
import dynamic: Value;

import std.sumtype;


alias Symbol = SumType!(Variable_signature, Overload_set);


struct Overload_symbol {
    string name;
    Variable_symbol[] overloads;
    string[] gen_c_declare();
}

struct Variable_symbol {
    string name;
    Expression value;

    Type type() {
        return value.type;
    }
    string[] gen_c_declare();
}


struct Scope {
    import nodes;
    private Symbol[string] symbols;
    private Statement[] statements;

    void add(R)(R multiple_statements) {
        foreach (Statement key; multiple_statements) {
            statements ~= key;
        }
    }

    void add(Statement statement) {
        if (auto fun = cast(Define_function) statement) {
            symbols.require(fun.name, Symbol(Overload_symbol(fun.name)));
            auto overload = Variable_symbol(fun);
            symbols[fun.name].match!(
                (ref Overload_symbol overloads) {
                    assert(overload !in overloads);
                    overloads[overload] = 0;
                }
                (Variable_symbol _) {assert(0);}
            );
        } else if (auto var = cast(Define_variable) statement) {
            symbols.update(
                var.name, 
                throw new Error(format!"Symbol '%s' is already defined"(name)),
                Variable_symbol(var.name, )
            );
        } else {
            throw new Error(format!"Symbol '%s' could not be handled."(name));
        }
        statements ~= statement;
    }
}

// class Function_literal : Expression {
// }

Function_value get_func(Define_function def) {
    auto ret = new Function_literal();
    ret.arguments_in = def.arguments_in;
    ret.arguments_out = def.arguments_out;
    ret.block = def.block;
}


Value fetch_value(Scope context) {
    Symbol entry = symbols.require(name,
        throw new Error(format!"Symbol '%s' not defined"(name));
    );
    return entry.match!(
        (Variable_symbol var) => var,
        (Overload_symbol set) {
            if (set.overloads.length > 1) {
                throw new Error(
                format!"Symbol '%s' is defined as a function"(name));
            }
            return set.overloads[0];
        }
    );
}


void add_initial_symbols(Module module_context) {
    auto symbols = module_context.scope_.symbols;
    symbols["Int"] ~= Variable_signature("Int", Type.int_word);
    symbols["Void"] ~= Variable_signature("Void", Type.unit);
    symbols["void"] ~= Variable_signature("void", Value_void());
}


