module input;

import std.format;  



unittest {
    import parse;
    import nodes;

    import std.exception: assertThrown, assertNotThrown;
    
    parse_code("
        fun main (args : []String)() {
            ;my-var = do-stuff(
                a, 1, 2 + (2 * 4)[11]
                some-value
                who-needs-separators
            )
        }
        ;foobar = lol
    ");

    parse_code("
        ;foobar = Bool : T >= U
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
