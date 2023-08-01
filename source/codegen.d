module codegen;

import nodes;
import typechecking;

import std.format;
import std.range;
import std.algorithm;
import std.conv;
import core.bitop;



string generate(Module mod) {
    // alias foo = dispatch!(Declaration, nodes);
    string output = mod.statements
        .map!(st => st.gen_c_declare)
        .joiner("\n\n")
        .to!string;
    output ~= "\n\n\n";
    output ~= mod.statements
        .map!(n => n.gen_c_statement)
        .joiner("\n\n")
        .to!string;
    return output;
}

string gen_c_scope(Statement[] block) {
    return "{\n" 
        ~ block
            .map!(n => n.gen_c_statement)
            .joiner("\n")
            .to!string 
        ~ "\n}";
}


string gen_c_prototype(Define_function func) {
    return format!"%s %s(%s)"(
        stand_in_type, 
        func.name.c_name, 
        func.arguments_in.map!(a => a.gen_c_parameter).joiner(", "),
        //. func.arguments_out.map!gen_c_parameter 
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


// alias dispatch(S, string call) = dispatch!(S, call, nodes);