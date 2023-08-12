module typechecking;

import codegen;
import std.nodes: Expression;

import std.format;

// For now, everything shall be int!


int data_size = 64;
int address_size = 64;

static this() {
    data_size = get_integer_size();
}

private
enum Discriminant {
    not_checked,
    unresolved,
    unit,
    type_t,
    int_word,
    boolean,
    func,
    slice,
    structure,
    sumtype,
    c_union,
}


// struct Type {
//     Discriminant discriminant = Discriminant.unresolved;
//     bool is_const = false;
    

//     // union {
//     //     // Type type_t;
//     //     Type_unresolved unresolved_;
//     //     // Type_int_word int_word_;
//     //     // Type_boolean boolean_;
//     //     Type_aggregate structure_;
//     //     Type_aggregate sumtype_;
//     //     Type_aggregate c_union_;
//     // }

//     enum not_checked = Type(Discriminant.not_checked);
//     enum unresolved = Type(Discriminant.unresolved);
//     enum boolean = Type(Discriminant.boolean);
//     enum int_word = Type(Discriminant.int_word);
//     enum func = Type(Discriminant.func);
//     enum stand_in = Type(Discriminant.int_word);
//     enum type_t = Type(Discriminant.type_t);
//     enum unit = Type(Discriminant.unit);
// }

Type constant(Type type) {
    type.is_const = true;
    return type;
}
Type variable(Type type) {
    type.is_const = false;
    return type;
}

string c_usage(Type type) {
    switch (type.discriminant) {
        case Discriminant.boolean:
            return "_Bool";
        case Discriminant.int_word:
            if (data_size <= 8)  return "int8_t";
            if (data_size <= 16) return "int16_t";
            if (data_size <= 32) return "int32_t";
            if (data_size <= 64) return "int64_t";
            else throw new Exception(
                "Integers that large are not currently supported.");
        case Discriminant.type_t:
            throw new Exception(
                "Type 'Type' can only be used at compile time.");
        case Discriminant.unresolved:
            Type* real_type = type.unresolved_.suspect;
            if (real_type.discriminant == Discriminant.unresolved) {
                throw new Exception("Type is not known.");
            }
            return c_usage(*(type.unresolved_.suspect));
        default:
            throw new Exception(
                format!"Case for '%s' not implemented"(
                    type.discriminant));
    }
}

string[] c_declaration(Type type) {
    switch (type.discriminant) {
        case Discriminant.boolean:
            return [];
        case Discriminant.int_word:
            return ["include <stdint.h>"];
        case Discriminant.type_t:
            throw new Exception(
                "Theres no sense in declaring Type in C.");
        case Discriminant.unresolved:
            Type* real_type = type.unresolved_.suspect;
            if (real_type.discriminant == Discriminant.unresolved) {
                throw new Exception("Type is not known.");
            }
            return c_declaration(*(type.unresolved_.suspect));
        default:
            throw new Exception(
                format!"Case for '%s' not implemented"(
                    type.discriminant));
    }
}

Type type_from_type_expression(Expression value) {
    import std.nodes;
    // if  
}

private:

// alias Types = AliasSeq!(
//     Type_Unresolved,
//     Type_int_word,
// );

// struct Type_int_word {
//     string c_usage() => "int";
// }
// struct Type_boolean {
//     string c_usage() => "char";
// }
// struct Type_t {
// }