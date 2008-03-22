#import <Cocoa/Cocoa.h>
#import <Nu/Nu.h>

static int load_nu_files(NSString *bundleIdentifier, NSString *mainFile)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSBundle *bundle = [NSBundle bundleWithIdentifier:bundleIdentifier];
    NSString *main_path = [bundle pathForResource:mainFile ofType:@"nu"];
    if (main_path) {
        NSString *main = [NSString stringWithContentsOfFile:main_path];
        if (main) {
            id parser = [Nu parser];
            id script = [parser parse: main];
            id result = [script evalWithContext:[parser context]];
        }
    }
    [pool release];
    return 0;
}

void MarkdownInit()
{
    static initialized = 0;
    if (!initialized) {
        initialized = 1;
        load_nu_files(@"nu.programming.markdown", @"markdown");
    }
}
