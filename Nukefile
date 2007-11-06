

(task "bin/nudown" is
      (SH "gcc objc/nudown.m -o bin/nudown -framework Cocoa -framework Nu"))

(task "test" is
      (SH "nutest test/test_markdown.nu"))

(task "clean" is
      (SH "rm test/SimpleTests/*.html")
      (SH "rm test/MarkdownTests/*.html"))

(task "default" => "bin/nudown")