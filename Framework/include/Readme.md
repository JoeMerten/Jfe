Public headerfiles of Jfe
=========================

All headers were placed into directory Jfe so that the sources include them with explicit naming the Jfe directory. This also reflects the C++ namespace `Jfe` in which the Jfe stuff was placed into.

Framework and Application sources should include them like:

   #include <Jfe/Streams.hxx>
   #include <Jfe/UnitTest++/UnitTest++.hxx>

