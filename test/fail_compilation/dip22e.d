/*
REQUIRED_ARGS: -transition=checkimports -de
TEST_OUTPUT:
---
fail_compilation/dip22e.d(15): Deprecation: imports.dip22d.foo is not visible from module dip22e
fail_compilation/dip22e.d(15): Error: function imports.dip22d.foo is not accessible from module dip22e
fail_compilation/dip22e.d(16): Deprecation: local import search method found overloadset dip22e.bar instead of function imports.dip22e.bar
---
*/
import imports.dip22d;
import imports.dip22e;

void test()
{
    foo();
    bar(12);
}
