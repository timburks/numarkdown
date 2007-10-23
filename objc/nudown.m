
#import <Cocoa/Cocoa.h>
#import <Nu/Nu.h>

@interface NuMarkdown : NSObject {}
+ (id) convert:(id) text;
@end

@interface NSObject(Nu)
- (id) evalWithContext:(id) context;
@end

int main(int argc, char *argv)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSString *input = [[NSString alloc]
        initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile]
        encoding:NSUTF8StringEncoding];

    id parser = [Nu parser];
    id script = [parser parse:@"(load \"markdown\")"];
	[script evalWithContext:[parser context]];
    [parser eval:script];

    Class NuMarkdown = NSClassFromString(@"NuMarkdown");
    NSString *output = [NuMarkdown convert:input];

    printf("%s", [output cStringUsingEncoding:NSUTF8StringEncoding]);

    [pool release];
}
