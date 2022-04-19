## clang-format执行过程

ClangFormat.cpp::main
ClangFormat.cpp::format
Format.cpp::reformat
Format.cpp::internal::reformat
TokenAnalyzer.cpp::process
Formatter.cpp::analyse
  TokenAnnotator.cpp::calculateFormattingInformation
  UnwrappedLineFormatter.cpp::format

