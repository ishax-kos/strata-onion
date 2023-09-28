module parse;

import nodes: Module;

import pegged.grammar;

import std.stdio;
import std.format;
import std.algorithm;
import std.array;
import std.conv;

// unittest {
//     import nodes;
//     string code = "
//         fun main (args []String)() {
//             ;my-var = Int|Float do-stuff[
//                 a, 1, 2 + (2 * 4)
//                 some-value
//                 who-needs-separators
//             ]
//         }
//         ;foobar = lol
//     ";
//     ParseTree gram = parse(code);
//     assert(gram.successful, format!"%s\n\n%s"(code, gram));
    
//     auto mod = Module(gram.children[0]);
// }


// Module cement_tree();

Module parse_code(string code) {
    import std.exception: enforce;
    ParseTree gram = Gram(code);
    enforce(gram.successful, gram.to!string);
    return Module.from_pegged(gram.children[0]);
}

ParseTree prune_tree(ParseTree node) @safe {
    enum name_prefix = "Gram.";

    node.children = node.children.map!((child) {
        if (child.name.startsWith(name_prefix ~ "_")) {
            // writeln(child.name[name_prefix.length .. $]); 
            child.name = "_";
        }
            return child;}).map!prune_tree.array;
            return node;
        }
        // * Because of how things work, everywhere a non semantic line-break is 
        // * allowed, you need to explicitly declare it with `br`. Just roll with it.

        mixin(grammar(import("gram/onion.gram")));

        // todo Implement what I have as a C transpiler

        // ParseTree child(ParseTree node_) @safe {
        //     ParseTree node = Gram.decimateTree(node_);
        //     switch (node.children.length) {
        //         case 1:
        //             return node.children[0];
        //         default:
        //             writeln(node.name);
        //             return node;
        //     }
        // }
