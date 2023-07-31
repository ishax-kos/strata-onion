module codegen;

import nodes;
import typechecking;

import std.format;
import std.range;
import std.algorithm;
import std.conv;
import std.regex;
import core.bitop;


string generate(Module node) {
    string output = node.statements
        .map!(n => cast(Declaration) n)
        .filter!(n => n !is null)
        .map!(n => n.gen_c_declare)
        .joiner("\n\n")
        .to!string;
    output ~= "\n\n";
    // output ~= node.statements
    //     .map!(n => n.gen_c_define);
    return output;
}

interface Declaration {
    string gen_c_declare();
    mixin template gen_c() {
        override string
        gen_c_declare() {
            return .gen_c_declare(this);
        }
    }
}


// string[] gen_c_scope(Statement[] block) {
//     return ["{"] ~ block.map!gen_c_statement.array ~ ["}"];
// }


string gen_c_prototype(Define_function func) {
    return format!"%s %s(%s)"(
        standin_type, 
        func.name.c_name, 
        func.arguments_in.map!gen_c_parameter.joiner(", "),
        // func.arguments_out.map!gen_c_parameter 
    );
}


string gen_c_parameter(Function_parameter parameter) {
    if (auto vname = cast(Value_name) parameter) {
        return format!"%s %s"(standin_type, vname.name.c_name);
        /// assert(0, "Cannot yet omit types in function parameters. Try implementing overloads.");
    } else 
    if (auto vparam = cast(Declare_uninit) parameter) {
        return format!"%s %s"(standin_type, vparam.name.c_name);
    } else 
    if (auto vparam = cast(Parameter_init) parameter) {
        assert(0, 
            "Default parameters are a part of overloading "
            ~"which isn't implemented."
        );
        /// return format!"%s %s"(standin_type, vparam.name.c_name);
    } else {
        assert(0);
    }
}


auto c_name(string name) {
    return name.map!(ch => ch == '-' ? '_' : ch);
}

// string gen_c_define(Define_variable var) {
//     return format!"%s %s = %s;"(
//         standin_type, 
//         var.name.c_name,
//         var.init.gen_c_expression()
//     );
// }

string gen_c_declare(Define_variable var) {
    return format!"%s %s;"(standin_type, var.name.c_name );
}

string gen_c_declare(Define_function func) {
    return gen_c_prototype(func) ~ ";";
}


unittest {
    import nodes;
    import parse;
    string c_code = "
        ;foo-bar = Fuck : me
        fun main(bing : bong, flim: flam)() {
            ;fkjskfjsdfks = 11
        }
    ".parse_code().generate();
    debug { import std.stdio : writeln; try { writeln(c_code); } catch (Exception) {} }
}


// auto split_indent(S)(S str, int level) {
//     return str.lineSplitter().map!(line => tab ~ line).joiner("\n");
// }
// enum tab = "    ";
string tab(int level) {
    return "    ".repeat().take(level).joiner.to!string;
}
auto indent(R)(R range, int level) {
    string tab = tab(level);
    foreach (ref line; range) {
        line = tab ~ line;
    }
    return range;
}
auto indent(S)(S str, int level) {
    return chain(tab(level), str);
}
