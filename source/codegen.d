module codegen;

import nodes;
import typechecking;

import std.format;
import std.range;
import std.algorithm;
import std.conv;

// Symbols_c_gen[string] symbol_table_c_gen;

// struct Symbols_c_gen {
//     string c_declaration;
//     Type type;
// }


string generate(Module mod) {
    // alias foo = dispatch!(Declaration, nodes);
    string[] output = mod.statements
        .map!(st => st.gen_c_declare)
        .joiner(lines(1)).array;
    output ~= lines(2);
    output ~= mod.statements
        .map!(n => n.gen_c_statement)
        .joiner(lines(1)).array;
    return output.joiner("\n").to!string;
}

string[] gen_c_scope(Statement[] block) {
    return lines(
        "{",
        block.map!(n => n.gen_c_statement).joiner(),
        "}"
    );
}


string gen_c_prototype(Define_function func) {
    return format!"%s %s(%s)"(
        Type.stand_in, 
        func.name.c_name, 
        func.arguments_in.map!(a => a.gen_c_parameter).joiner(", "),
        // func.arguments_out.map!gen_c_parameter 
    );
}


string c_name(string name) {
    return name
        .map!(ch => ch == '-' ? '_' : ch)
        .to!string
    ;
}


unittest {
    import nodes;
    import parse;
    string c_code = "
        ;foo-bar = Heck : me
        fun main(bing : bong, flim: flam)() {
            ;blah = 11
            blah = 22
        }
    ".parse_code().generate();
    debug { import std.stdio : writeln; try { writeln(c_code); } catch (Exception) {} }
}


// auto split_indent(S)(S str, int level) {
//     return str.lineSplitter().map!(line => tab ~ line).joiner("\n");
// }
// enum tab = "    ";
// string tab(int level) {
//     return "    ".repeat().take(level).joiner.to!string;
// }
// auto indent(R)(R range, int level) {
//     string tab = tab(level);
//     foreach (ref line; range) {
//         line = tab ~ line;
//     }
//     return range;
// }
// auto indent(S)(S str, int level) {
//     return chain(tab(level), str);
// }

auto dispatch(Super, string call, alias module_, T)(T object) {
    import std.traits: TemplateArgsOf;
    import std.conv;
    // import sts
    alias Subtype_list = Subtypes!(Super, module_);
    static foreach(Subtype; Subtype_list) {
        if (auto val = cast(Subtype) object) {
            return mixin(call)(val);
        }
    }
    assert(0, format!"Found %s"(object));
}
// import std.typecons : isTuple;
string[] lines(T...)(T args) {
    enum indent = "    ";
    string[] ret;
    foreach(arg; args) {
        static if (is(typeof(arg.front()) == dchar)) {
            ret ~= arg.to!string;
        } else {
            foreach (sub_arg; arg) {
                static assert(is(typeof(sub_arg.front()) == dchar));
                ret ~= indent ~ sub_arg.to!string;
            }
        }
    }
    return ret;
}


string[] lines(int count) {
    return "".repeat.take(count).array;
}


version(Windows)
int get_integer_size() {
    import std.process: execute;
    import std.csv;
    import std.uni: toLower;
    auto result = execute(["systeminfo", "/FO", "CSV"]);
    if (result.status != 0) {
        throw new Exception("Couldn't get integer size.");
    }

    import std.stdio;
    import std.typecons: Tuple;

    auto table = csvReader!(string[string])(result.output, null);
    
    string system_type = table.front()["System Type"].toLower;

    switch (system_type) {
        case "x64-based pc":
            return 64;
        case "x86-based pc":
            return 16;
        default:
            throw new Exception(system_type);
    }
}
